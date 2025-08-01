# Explicitly define aliases for source and destination providers.

provider "azapi" {
  alias = "source"
  # Use the follwing line if you want to specify a subscription ID for the source provider
  #subscription_id = "xxxxxxxxxxxxxxxxxx" # Replace with your Azure subscription ID
}

provider "azapi" {
  alias = "destination"
  # Use the follwing line if you want to specify a subscription ID for the destination provider
  #subscription_id = "xxxxxxxxxxxxxxxxxx" # Replace with your Azure subscription ID
}

provider "azurerm" {
  features {}
  subscription_id = "xxxxxxxxxxxxxxxxxx" # Replace with your Azure subscription ID
  
  
}

terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.12"
}

resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2021-04-01"
  name     = "rg-nsgator-basic"
  location = "West Europe"
  body = {
  }
}

resource "azapi_resource" "vnet" {
  type      = "Microsoft.Network/virtualNetworks@2024-07-01"
  name      = "vnet-nsgator-basic"
  parent_id = azapi_resource.rg.id
  location  = azapi_resource.rg.location
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.1.0.0/16", "10.2.0.0/16"]
      }
      subnets = [
        {
          name = "subnet1"
          properties = {
            addressPrefix = "10.1.1.0/24"
            networkSecurityGroup = {
              id = azurerm_network_security_group.nsg1.id
            }
          }
        },
        {
          name = "subnet2"
          properties = {
            addressPrefix = "10.2.1.0/24"
            networkSecurityGroup = {
              id = azurerm_network_security_group.nsg2.id
            }
          }
        }
      ]
    }
  }
}

resource "azurerm_network_security_group" "nsg1" {
    name                = "source-nsg"
    location            = azapi_resource.rg.location
    resource_group_name = azapi_resource.rg.name
    lifecycle {
      ignore_changes = [ tags ]
    }
}

resource "azurerm_network_security_group" "nsg2" {
    name                = "destination-nsg"
    location            = azapi_resource.rg.location
    resource_group_name = azapi_resource.rg.name
    lifecycle {
      ignore_changes = [ tags ]
    }
}

module "nsg_rules" {
  source = "humanascode/nsgator/azapi"

  providers = {
    azapi.source      = azapi.source
    azapi.destination = azapi.destination
  }

  source_nsg_id      = azurerm_network_security_group.nsg1.id
  destination_nsg_id = azurerm_network_security_group.nsg2.id

  priority_range = {
    source_start      = 1000
    source_end        = 1100
    destination_start = 2000
    destination_end   = 2100
  }

  rules = {
    "web-traffic" = {
      source_ips      = ["10.1.1.0/24"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["80"]
      protocol        = "Tcp"
      workload        = "web"
    },
    "rdp-access" = {
      source_ips      = ["10.1.1.5"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["3389"]
      protocol        = "Tcp"
      workload        = "rdp"
    },
        "ssh-access" = {
          source_ips      = ["10.1.1.10"]
          destination_ips = ["10.2.1.0/24"]
          ports           = ["22"]
          protocol        = "Tcp"
          workload        = "ssh"
        },
        "sql-access" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.20"]
          ports           = ["1433"]
          protocol        = "Tcp"
          workload        = "sql"
        },
        "dns-udp" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.53"]
          ports           = ["53"]
          protocol        = "Udp"
          workload        = "dns"
        },
        "http-alt" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.0/24"]
          ports           = ["8080"]
          protocol        = "Tcp"
          workload        = "http-alt"
        },
        "smtp" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.25"]
          ports           = ["25"]
          protocol        = "Tcp"
          workload        = "smtp"
        },
        "https" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.0/24"]
          ports           = ["443"]
          protocol        = "Tcp"
          workload        = "https"
        },
        "file-share" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.0/24"]
          ports           = ["445"]
          protocol        = "Tcp"
          workload        = "file-share"
        },
        "ntp" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.123"]
          ports           = ["123"]
          protocol        = "Udp"
          workload        = "ntp"
        },
        "custom-app" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.100"]
          ports           = ["9000"]
          protocol        = "Tcp"
          workload        = "custom-app"
        },
        "monitoring" = {
          source_ips      = ["10.1.1.0/24"]
          destination_ips = ["10.2.1.200"]
          ports           = ["5666"]
          protocol        = "Tcp"
          workload        = "monitoring"
        }
  }
}
