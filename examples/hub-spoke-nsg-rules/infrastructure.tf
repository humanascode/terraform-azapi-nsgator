# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Spoke1 Virtual Network (Web Tier)
resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-web-${var.environment}"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "spoke1_subnet" {
  name                 = "subnet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "spoke1" {
  name                = "nsg-spoke1-web-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "spoke1" {
  subnet_id                 = azurerm_subnet.spoke1_subnet.id
  network_security_group_id = azurerm_network_security_group.spoke1.id
}

# Spoke2 Virtual Network (Database Tier)
resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-db-${var.environment}"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "spoke2_subnet" {
  name                 = "subnet-database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_network_security_group" "spoke2" {
  name                = "nsg-spoke2-db-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "spoke2" {
  subnet_id                 = azurerm_subnet.spoke2_subnet.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}