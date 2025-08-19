##############################
# Module Outputs
##############################

# Map of outbound NSG rules created (empty if outbound disabled or no source NSG)
output "outbound_rules" {
  description = "Map of outbound rules created keyed by rule key. Each value includes id, name, priority, access, protocol, direction. Empty map if no outbound rules were created."
  value = {
    for k, r in azapi_resource.outbound :
    k => {
      id        = r.id
      name      = r.name
      priority  = try(r.output.properties.priority, null)
      access    = try(r.output.properties.access, null)
      protocol  = try(r.output.properties.protocol, null)
      direction = "Outbound"
    }
  }
}

# Map of inbound NSG rules created (empty if inbound disabled or no destination NSG)
output "inbound_rules" {
  description = "Map of inbound rules created keyed by rule key. Each value includes id, name, priority, access, protocol, direction. Empty map if no inbound rules were created."
  value = {
    for k, r in azapi_resource.inbound :
    k => {
      id        = r.id
      name      = r.name
      priority  = try(r.output.properties.priority, null)
      access    = try(r.output.properties.access, null)
      protocol  = try(r.output.properties.protocol, null)
      direction = "Inbound"
    }
  }
}