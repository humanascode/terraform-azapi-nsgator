terraform {
  required_version = ">= 1.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }
}


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
