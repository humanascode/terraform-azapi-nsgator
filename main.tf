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
  source_nsg_rules_in_range = local.source_nsg_has_rules ? [
    for rule in local.source_nsg_rules : rule.properties.priority if rule.properties.priority >= var.priority_range.source_start && rule.properties.priority <= var.priority_range.source_end
  ] : []

  source_nsg_highest_priority = (
    local.source_nsg_rules_in_range != []
    ? max(local.source_nsg_rules_in_range...)
    : try((var.priority_range.source_start - 1), null)
  )
  ############################# Finding the highest priority for destination NSG ##############################
  destination_nsg_rules     = try(data.azapi_resource.destination_nsg[0].output.properties.securityRules, [])
  destination_nsg_has_rules = length(local.destination_nsg_rules) > 0
  destination_nsg_rules_in_range = local.destination_nsg_has_rules ? [
    for rule in local.destination_nsg_rules : rule.properties.priority if rule.properties.priority >= var.priority_range.destination_start && rule.properties.priority <= var.priority_range.destination_end
  ] : []

  destination_nsg_highest_priority = (
    local.destination_nsg_rules_in_range != []
    ? max(local.destination_nsg_rules_in_range...)
    : try((var.priority_range.destination_start - 1), null)
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
            length(try(existing.properties.sourceAddressPrefixes, [])) == length(coalescelist(v.source_ips, [])) &&
            length(setsubtract(try(existing.properties.sourceAddressPrefixes, []), coalescelist(v.source_ips, []))) == 0 &&
            length(setsubtract(coalescelist(v.source_ips, []), try(existing.properties.sourceAddressPrefixes, []))) == 0 &&
            length(try(existing.properties.destinationAddressPrefixes, [])) == length(coalescelist(v.destination_ips, [])) &&
            length(setsubtract(try(existing.properties.destinationAddressPrefixes, []), coalescelist(v.destination_ips, []))) == 0 &&
            length(setsubtract(coalescelist(v.destination_ips, []), try(existing.properties.destinationAddressPrefixes, []))) == 0 &&
            length(try(existing.properties.destinationPortRanges, [])) == length(coalescelist(v.ports, [])) &&
            length(setsubtract(try(existing.properties.destinationPortRanges, []), coalescelist(v.ports, []))) == 0 &&
            length(setsubtract(coalescelist(v.ports, []), try(existing.properties.destinationPortRanges, []))) == 0 &&
            lower(try(existing.properties.protocol, "")) == lower(v.protocol) &&
            lower(try(existing.properties.access, "")) == lower(v.access) &&
            lower(try(existing.properties.sourcePortRange, "")) == lower(v.source_port_range) &&
            (lower(v.protocol) == "icmp" ? lower(try(existing.properties.destinationPortRange, "")) == "*" : true) &&
            (v.destination_service_tag != null ? lower(try(existing.properties.destinationAddressPrefix, "")) == lower(v.destination_service_tag) : true)

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
              length(try(existing.properties.sourceAddressPrefixes, [])) == length(coalescelist(v.source_ips, [])) &&
              length(setsubtract(try(existing.properties.sourceAddressPrefixes, []), coalescelist(v.source_ips, []))) == 0 &&
              length(setsubtract(coalescelist(v.source_ips, []), try(existing.properties.sourceAddressPrefixes, []))) == 0 &&
              length(try(existing.properties.destinationAddressPrefixes, [])) == length(coalescelist(v.destination_ips, [])) &&
              length(setsubtract(try(existing.properties.destinationAddressPrefixes, []), coalescelist(v.destination_ips, []))) == 0 &&
              length(setsubtract(coalescelist(v.destination_ips, []), try(existing.properties.destinationAddressPrefixes, []))) == 0 &&
              length(try(existing.properties.destinationPortRanges, [])) == length(coalescelist(v.ports, [])) &&
              length(setsubtract(try(existing.properties.destinationPortRanges, []), coalescelist(v.ports, []))) == 0 &&
              length(setsubtract(coalescelist(v.ports, []), try(existing.properties.destinationPortRanges, []))) == 0 &&
              lower(try(existing.properties.protocol, "")) == lower(v.protocol) &&
              lower(try(existing.properties.access, "")) == lower(v.access) &&
              lower(try(existing.properties.sourcePortRange, "")) == lower(v.source_port_range) &&
              (lower(v.protocol) == "icmp" ? lower(try(existing.properties.destinationPortRange, "")) == "*" : true) &&
              (v.destination_service_tag != null ? lower(try(existing.properties.destinationAddressPrefix, "")) == lower(v.destination_service_tag) : true)
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
            length(try(existing.properties.sourceAddressPrefixes, [])) == length(coalescelist(v.source_ips, [])) &&
            length(setsubtract(try(existing.properties.sourceAddressPrefixes, []), coalescelist(v.source_ips, []))) == 0 &&
            length(setsubtract(coalescelist(v.source_ips, []), try(existing.properties.sourceAddressPrefixes, []))) == 0 &&
            length(try(existing.properties.destinationAddressPrefixes, [])) == length(coalescelist(v.destination_ips, [])) &&
            length(setsubtract(try(existing.properties.destinationAddressPrefixes, []), coalescelist(v.destination_ips, []))) == 0 &&
            length(setsubtract(coalescelist(v.destination_ips, []), try(existing.properties.destinationAddressPrefixes, []))) == 0 &&

            length(try(existing.properties.destinationPortRanges, [])) == length(coalescelist(v.ports, [])) &&
            length(setsubtract(try(existing.properties.destinationPortRanges, []), coalescelist(v.ports, []))) == 0 &&
            length(setsubtract(coalescelist(v.ports, []), try(existing.properties.destinationPortRanges, []))) == 0 &&
            lower(try(existing.properties.protocol, "")) == lower(v.protocol) &&
            lower(try(existing.properties.access, "")) == lower(v.access) &&
            lower(try(existing.properties.sourcePortRange, "")) == lower(v.source_port_range) &&
            (lower(v.protocol) == "icmp" ? lower(try(existing.properties.destinationPortRange, "")) == "*" : true) &&
            (v.source_service_tag != null ? lower(try(existing.properties.sourceAddressPrefix, "")) == lower(v.source_service_tag) : true)
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
              length(try(existing.properties.sourceAddressPrefixes, [])) == length(coalescelist(v.source_ips, [])) &&
              length(setsubtract(try(existing.properties.sourceAddressPrefixes, []), coalescelist(v.source_ips, []))) == 0 &&
              length(setsubtract(coalescelist(v.source_ips, []), try(existing.properties.sourceAddressPrefixes, []))) == 0 &&
              length(try(existing.properties.destinationAddressPrefixes, [])) == length(coalescelist(v.destination_ips, [])) &&
              length(setsubtract(try(existing.properties.destinationAddressPrefixes, []), coalescelist(v.destination_ips, []))) == 0 &&
              length(setsubtract(coalescelist(v.destination_ips, []), try(existing.properties.destinationAddressPrefixes, []))) == 0 &&

              length(try(existing.properties.destinationPortRanges, [])) == length(coalescelist(v.ports, [])) &&
              length(setsubtract(try(existing.properties.destinationPortRanges, []), coalescelist(v.ports, []))) == 0 &&
              length(setsubtract(coalescelist(v.ports, []), try(existing.properties.destinationPortRanges, []))) == 0 &&
              lower(try(existing.properties.protocol, "")) == lower(v.protocol) &&
              lower(try(existing.properties.access, "")) == lower(v.access) &&
              lower(try(existing.properties.sourcePortRange, "")) == lower(v.source_port_range) &&
              (lower(v.protocol) == "icmp" ? lower(try(existing.properties.destinationPortRange, "")) == "*" : true) &&
              (v.source_service_tag != null ? lower(try(existing.properties.sourceAddressPrefix, "")) == lower(v.source_service_tag) : true)


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
      priority                   = each.value.priority
      direction                  = "Outbound"
      access                     = each.value.access
      protocol                   = each.value.protocol
      sourcePortRange            = each.value.source_port_range
      destinationPortRanges      = each.value.protocol == "Icmp" ? [] : each.value.ports
      destinationPortRange       = each.value.protocol == "Icmp" ? "*" : null
      sourceAddressPrefixes      = each.value.source_ips
      destinationAddressPrefixes = each.value.destination_ips
      destinationAddressPrefix   = each.value.destination_service_tag != null ? each.value.destination_service_tag : null
    }
  }

  response_export_values = [
    "id",
    "name",
    "properties.priority",
    "properties.access",
    "properties.protocol"
  ]
  lifecycle {
    ignore_changes = [body.properties.priority]
    precondition {
      condition     = each.value.priority != null
      error_message = "Priority is out of range or not assigned for rule: ${each.value.workload}."
    }
  }

  retry = {
    error_message_regex  = ["AnotherOperationInProgress", "RetryableError", "CanceledAndSupersededDueToAnotherOperation"]
    interval_seconds     = 5
    randomization_factor = 0.5
    max_interval_seconds = 20
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
      priority                   = each.value.priority
      direction                  = "Inbound"
      access                     = each.value.access
      protocol                   = each.value.protocol
      sourcePortRange            = each.value.source_port_range
      destinationPortRanges      = each.value.protocol == "Icmp" ? [] : each.value.ports
      destinationPortRange       = each.value.protocol == "Icmp" ? "*" : null
      sourceAddressPrefixes      = each.value.source_ips
      sourceAddressPrefix        = each.value.source_service_tag != null ? each.value.source_service_tag : null
      destinationAddressPrefixes = each.value.destination_ips
    }
  }

    response_export_values = [
    "id",
    "name",
    "properties.priority",
    "properties.access",
    "properties.protocol"
  ]

  lifecycle {
    ignore_changes = [body.properties.priority]
    precondition {
      condition     = each.value.priority != null
      error_message = "Priority is out of range or not assigned for rule: ${each.value.workload}."
    }
  }
  retry = {
    error_message_regex  = ["AnotherOperationInProgress", "RetryableError", "CanceledAndSupersededDueToAnotherOperation"]
    interval_seconds     = 5
    randomization_factor = 0.5
    max_interval_seconds = 20
  }
}

locals {
  flow_tag_source      = coalesce(local.source_nsg_name, "NoSourceNSG")
  flow_tag_destination = coalesce(local.destination_nsg_name, "NoDestinationNSG")
  flow_tag             = "${local.flow_tag_source}-${local.flow_tag_destination}"
}


resource "azapi_update_resource" "source_nsg_tag" {
  type        = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count       = var.create_outbound_rules && var.create_tags ? 1 : 0
  resource_id = var.source_nsg_id
  provider    = azapi.source

  # Tags will be merged with existing
  body = {
    tags = {
      "managed_by_terraform_outbound_priority_range_${local.flow_tag}" = "${var.priority_range.source_start}-${var.priority_range.source_end}"
    }
  }
  depends_on = [azapi_resource.outbound]
}


resource "azapi_update_resource" "destination_nsg_tag" {
  type        = "Microsoft.Network/networkSecurityGroups@2024-05-01"
  count       = var.create_inbound_rules && var.create_tags ? 1 : 0
  resource_id = var.destination_nsg_id
  provider    = azapi.destination

  body = {
    tags = {
      "managed_by_terraform_inbound_priority_range_${local.flow_tag}" = "${var.priority_range.destination_start}-${var.priority_range.destination_end}"
    }
  }
  depends_on = [azapi_resource.inbound]
}