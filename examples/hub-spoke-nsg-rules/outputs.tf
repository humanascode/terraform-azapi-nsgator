output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "spoke1_nsg_id" {
  description = "Resource ID of the Spoke1 NSG"
  value       = azurerm_network_security_group.spoke1.id
}

output "spoke2_nsg_id" {
  description = "Resource ID of the Spoke2 NSG"
  value       = azurerm_network_security_group.spoke2.id
}

output "spoke1_subnet_id" {
  description = "Resource ID of the Spoke1 subnet"
  value       = azurerm_subnet.spoke1_subnet.id
}

output "spoke2_subnet_id" {
  description = "Resource ID of the Spoke2 subnet"
  value       = azurerm_subnet.spoke2_subnet.id
}

output "network_summary" {
  description = "Summary of the created network infrastructure"
  value = {
    spoke1_vnet_address_space = azurerm_virtual_network.spoke1.address_space
    spoke1_subnet_prefix      = azurerm_subnet.spoke1_subnet.address_prefixes
    spoke2_vnet_address_space = azurerm_virtual_network.spoke2.address_space
    spoke2_subnet_prefix      = azurerm_subnet.spoke2_subnet.address_prefixes
  }
}
