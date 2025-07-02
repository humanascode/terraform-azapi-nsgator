locals {
  # Preparing locals for the rules creation
  source_nsg_name                 = try(split("/", var.source_nsg_id)[length(split("/", var.source_nsg_id)) - 1], null)
  source_nsg_rg_name              = try(split("/", var.source_nsg_id)[4], null)
  destination_nsg_name            = try(split("/", var.destination_nsg_id)[length(split("/", var.destination_nsg_id)) - 1], null)
  destination_nsg_rg_name         = try(split("/", var.destination_nsg_id)[4], null)
  source_nsg_subscription_id      = try(split("/", var.source_nsg_id)[2], null)
  destination_nsg_subscription_id = try(split("/", var.destination_nsg_id)[2], null)


  ############################# Finding the highest priority for source NSG ###############################
  source_nsg_rules     = try(data.azapi_resource.source_nsg[0].output.properties.securityRules, [])
  source_nsg_has_rules = length(local.source_nsg_rules) > 0
  source_nsg_highest_priority = (
    local.source_nsg_has_rules
    ? max([for rule in local.source_nsg_rules : rule.properties.priority if rule.properties.priority >= var.priority_range.source_start && rule.properties.priority <= var.priority_range.source_end ]...)
    : try((var.priority_range.source_start - 1) , null)
  )
  ############################# Finding the highest priority for destination NSG ##############################
  destination_nsg_rules     = try(data.azapi_resource.destination_nsg[0].output.properties.securityRules, [])
  destination_nsg_has_rules = length(local.destination_nsg_rules) > 0

  destination_nsg_highest_priority = (
    local.destination_nsg_has_rules
    ? max([for rule in local.destination_nsg_rules : rule.properties.priority if rule.properties.priority >= var.priority_range.destination_start && rule.properties.priority <= var.priority_range.destination_end ]...)
    : try((var.priority_range.destination_start - 1) , null)
  )
}

#### Fetching existing NSG rules for both source and destination NSGs using azapi_resource data source ######

data "azapi_resource" "source_nsg" {
  type                   = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count                  = var.create_outbound_rules ? 1 : 0
  parent_id              = "/subscriptions/${local.source_nsg_subscription_id}/resourceGroups/${local.source_nsg_rg_name}"
  name                   = local.source_nsg_name
  response_export_values = ["properties.securityRules"]
}

data "azapi_resource" "destination_nsg" {
  type                   = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count                  = var.create_inbound_rules ? 1 : 0
  parent_id              = "/subscriptions/${local.destination_nsg_subscription_id}/resourceGroups/${local.destination_nsg_rg_name}"
  name                   = local.destination_nsg_name
  response_export_values = ["properties.securityRules"]
}

locals {
  ##### Look for existing rules in the source NSG and assign their current priority so there wont be any duplicates #####
  rules_with_existing_priority_source = {
    for k, v in var.rules :
    k => merge(
      v,
      {
        priority = try(
          [
            for existing in local.source_nsg_rules :
            existing.properties.priority
            if existing.name == "outbound-${v.workload}-${v.protocol}" &&
            length(existing.properties.sourceAddressPrefixes) == length(v.source_ips) &&
            length(setsubtract(existing.properties.sourceAddressPrefixes, v.source_ips)) == 0 &&
            length(setsubtract(v.source_ips, existing.properties.sourceAddressPrefixes)) == 0 &&
            length(existing.properties.destinationAddressPrefixes) == length(v.destination_ips) &&
            length(setsubtract(existing.properties.destinationAddressPrefixes, v.destination_ips)) == 0 &&
            length(setsubtract(v.destination_ips, existing.properties.destinationAddressPrefixes)) == 0 &&
            length(existing.properties.destinationPortRanges) == length(v.ports) &&
            length(setsubtract(existing.properties.destinationPortRanges, v.ports)) == 0 &&
            length(setsubtract(v.ports, existing.properties.destinationPortRanges)) == 0 &&
            lower(existing.properties.protocol) == lower(v.protocol) &&
            lower(existing.properties.access) == lower(v.access) &&
            lower(existing.properties.sourcePortRange) == lower(v.source_port_range)
          ][0],
          null
        )
      }
    )
  }


  # detecting new rules that do not have a priority assigned yet
  new_rules_source = {
    for k, v in local.rules_with_existing_priority_source : k => v if v.priority == null
  }

  # Creating an index for new rules to be able to calculate their priority

  new_rules_source_with_index = {
    for idx, k in zipmap(range(length(keys(local.new_rules_source))), keys(local.new_rules_source)) :
    k => merge(
      local.new_rules_source[k],
      {
        index = idx
      }
    )
  }

  ### Finally, this is the map of rules with assigned priorities for the source NSG to be created or updated ###
  # This will assign a priority to each rule based on the index of the new rules and
  # If the priority is out of range, it will assign null
  rules_with_priority_source = {
    for k, v in var.rules :
    k => merge(
      v,
      {
        priority = (
          try(
            [
              for existing in local.source_nsg_rules :
              existing.properties.priority
              if existing.name == "outbound-${v.workload}-${v.protocol}" &&
              length(existing.properties.sourceAddressPrefixes) == length(v.source_ips) &&
              length(setsubtract(existing.properties.sourceAddressPrefixes, v.source_ips)) == 0 &&
              length(setsubtract(v.source_ips, existing.properties.sourceAddressPrefixes)) == 0 &&
              length(existing.properties.destinationAddressPrefixes) == length(v.destination_ips) &&
              length(setsubtract(existing.properties.destinationAddressPrefixes, v.destination_ips)) == 0 &&
              length(setsubtract(v.destination_ips, existing.properties.destinationAddressPrefixes)) == 0 &&
              length(existing.properties.destinationPortRanges) == length(v.ports) &&
              length(setsubtract(existing.properties.destinationPortRanges, v.ports)) == 0 &&
              length(setsubtract(v.ports, existing.properties.destinationPortRanges)) == 0 &&
              lower(existing.properties.protocol) == lower(v.protocol) &&
              lower(existing.properties.access) == lower(v.access) &&
              lower(existing.properties.sourcePortRange) == lower(v.source_port_range)
            ][0],
            # If not found, assign a new priority if in range; else, null
            (local.new_rules_source_with_index[k].index + local.source_nsg_highest_priority + 1) <= var.priority_range.source_end &&
            (local.new_rules_source_with_index[k].index + local.source_nsg_highest_priority + 1) >= var.priority_range.source_start
            ? (local.new_rules_source_with_index[k].index + local.source_nsg_highest_priority + 1)
            : null, null
          )
        )
      }
    )
  }


  ###### Look for existing rules in the destination NSG and assign their current priority so there wont be any duplicates #####

  rules_with_existing_priority_destination = {
    for k, v in var.rules :
    k => merge(
      v,
      {
        priority = try(
          [
            for existing in local.destination_nsg_rules :
            existing.properties.priority
            if existing.name == "inbound-${v.workload}-${v.protocol}" &&
            length(existing.properties.sourceAddressPrefixes) == length(v.source_ips) &&
            length(setsubtract(existing.properties.sourceAddressPrefixes, v.source_ips)) == 0 &&
            length(setsubtract(v.source_ips, existing.properties.sourceAddressPrefixes)) == 0 &&
            length(existing.properties.destinationAddressPrefixes) == length(v.destination_ips) &&
            length(setsubtract(existing.properties.destinationAddressPrefixes, v.destination_ips)) == 0 &&
            length(setsubtract(v.destination_ips, existing.properties.destinationAddressPrefixes)) == 0 &&

            length(existing.properties.destinationPortRanges) == length(v.ports) &&
            length(setsubtract(existing.properties.destinationPortRanges, v.ports)) == 0 &&
            length(setsubtract(v.ports, existing.properties.destinationPortRanges)) == 0 &&
            lower(existing.properties.protocol) == lower(v.protocol) &&
            lower(existing.properties.access) == lower(v.access) &&
            lower(existing.properties.sourcePortRange) == lower(v.source_port_range)
          ][0],
          null
        )
      }
    )
  }

  new_rules_destination = {
  for k, v in local.rules_with_existing_priority_destination : k => v if v.priority == null
}

  # Creating an index for new rules to be able to calculate their priority
new_rules_destination_with_index = {
  for idx, k in zipmap(range(length(keys(local.new_rules_destination))), keys(local.new_rules_destination)) :
  k => merge(
    local.new_rules_destination[k],
    { index = idx }
  )
}

  ### Finally, this is the map of rules with assigned priorities for the destination NSG to be created or updated ###
  # This will assign a priority to each rule based on the index of the new rules and
  # If the priority is out of range, it will assign null

  rules_with_priority_destination = {
    for k, v in var.rules :
    k => merge(
      v,
      {
        priority = (
          try(
            [
              for existing in local.destination_nsg_rules :
              existing.properties.priority
              if existing.name == "inbound-${v.workload}-${v.protocol}" &&
              length(existing.properties.sourceAddressPrefixes) == length(v.source_ips) &&
              length(setsubtract(existing.properties.sourceAddressPrefixes, v.source_ips)) == 0 &&
              length(setsubtract(v.source_ips, existing.properties.sourceAddressPrefixes)) == 0 &&
              length(existing.properties.destinationAddressPrefixes) == length(v.destination_ips) &&
              length(setsubtract(existing.properties.destinationAddressPrefixes, v.destination_ips)) == 0 &&
              length(setsubtract(v.destination_ips, existing.properties.destinationAddressPrefixes)) == 0 &&

              length(existing.properties.destinationPortRanges) == length(v.ports) &&
              length(setsubtract(existing.properties.destinationPortRanges, v.ports)) == 0 &&
              length(setsubtract(v.ports, existing.properties.destinationPortRanges)) == 0 &&
              lower(existing.properties.protocol) == lower(v.protocol) &&
              lower(existing.properties.access) == lower(v.access) &&
              lower(existing.properties.sourcePortRange) == lower(v.source_port_range)
            ][0],
          # If not found, assign a new priority if it's in range, else null
          (local.new_rules_destination_with_index[k].index + local.destination_nsg_highest_priority + 1) <= var.priority_range.destination_end &&
          (local.new_rules_destination_with_index[k].index + local.destination_nsg_highest_priority + 1) >= var.priority_range.destination_start
            ? (local.new_rules_destination_with_index[k].index + local.destination_nsg_highest_priority + 1)
            : null, null
          )
        )
      }
    )
  }
}


resource "azapi_resource" "outbound" {
  for_each = {
    for k, v in local.rules_with_priority_source :
    k => v if var.create_outbound_rules
  }
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-07-01"
  name      = "outbound-${each.value.workload}-${each.value.protocol}"
  parent_id = var.source_nsg_id

  body = {
    
    properties = {
      
      priority                    = each.value.priority
      direction                   = "Outbound"
      access                      = each.value.access
      protocol                    = each.value.protocol
      sourcePortRange             = each.value.source_port_range
      destinationPortRanges       = each.value.ports
      sourceAddressPrefixes       = each.value.source_ips
      destinationAddressPrefixes  = each.value.destination_ips
    }
  }

  lifecycle {
    ignore_changes = [body.properties.priority]
    precondition {
      condition     = each.value.priority != null
      error_message = "Priority is out of range or not assigned for rule: ${each.value.workload}."
    }
  }

  retry = {
    error_message_regex = ["NotFound"]
    interval_seconds = 5
    randomization_factor = 0.5
    multiplier = 2
  }
  
}

resource "azapi_resource" "inbound" {
  for_each = {
    for k, v in local.rules_with_priority_destination :
    k => v if var.create_inbound_rules
  }
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-07-01"
  name      = "inbound-${each.value.workload}-${each.value.protocol}"
  parent_id = var.destination_nsg_id

  body = {
    properties = {
      priority                    = each.value.priority
      direction                   = "Inbound"
      access                      = each.value.access
      protocol                    = each.value.protocol
      sourcePortRange             = each.value.source_port_range
      destinationPortRanges       = each.value.ports
      sourceAddressPrefixes       = each.value.source_ips
      destinationAddressPrefixes  = each.value.destination_ips
    }
  }

  lifecycle {
    ignore_changes = [body.properties.priority]
    precondition {
      condition     = each.value.priority != null
      error_message = "Priority is out of range or not assigned for rule: ${each.value.workload}."
    }
  }
    retry = {
    error_message_regex = ["NotFound"]
    interval_seconds = 5
    randomization_factor = 0.5
    multiplier = 2
  }
}


resource "azapi_update_resource" "source_nsg_tag" {
  type        = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count       = var.create_outbound_rules ? 1 : 0
  resource_id = var.source_nsg_id
  provider    = azapi.source

  # Tags will be merged with existing
  body = {
    tags = {
      managed_by_terraform_outbound_priority_range = "${var.priority_range.source_start}-${var.priority_range.source_end}"
    }
  }
}


resource "azapi_update_resource" "destination_nsg_tag" {
  type        = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count       = var.create_inbound_rules ? 1 : 0
  resource_id = var.destination_nsg_id
  provider    = azapi.destination

  body = {
    tags = {
      managed_by_terraform_inbound_priority_range = "${var.priority_range.destination_start}-${var.priority_range.destination_end}"
    }
  }
}

# TODO - fix the retryable error when creating multiple rules in the same NSG


# output "locals_debug" {
#   value = {
#     source_nsg_name                      = local.source_nsg_name
#     source_nsg_rg_name                   = local.source_nsg_rg_name
#     destination_nsg_name                 = local.destination_nsg_name
#     destination_nsg_rg_name              = local.destination_nsg_rg_name
#     source_nsg_subscription_id           = local.source_nsg_subscription_id
#     destination_nsg_subscription_id      = local.destination_nsg_subscription_id
#     source_nsg_rules                     = local.source_nsg_rules
#     source_nsg_has_rules                 = local.source_nsg_has_rules
#     source_nsg_highest_priority          = local.source_nsg_highest_priority
#     destination_nsg_rules                = local.destination_nsg_rules
#     destination_nsg_has_rules            = local.destination_nsg_has_rules
#     destination_nsg_highest_priority     = local.destination_nsg_highest_priority
#     rules_with_existing_priority_source  = local.rules_with_existing_priority_source
#     new_rules_source                     = local.new_rules_source
#     new_rules_source_with_index          = local.new_rules_source_with_index
#     rules_with_priority_source           = local.rules_with_priority_source
#     rules_with_existing_priority_destination = local.rules_with_existing_priority_destination
#     new_rules_destination_with_index     = local.new_rules_destination_with_index
#     rules_with_priority_destination      = local.rules_with_priority_destination
#     data_source_nsg = data.azapi_resource.source_nsg[0]
#   }
# }