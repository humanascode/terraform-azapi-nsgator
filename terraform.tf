
terraform {
  required_providers {
    azapi = {
      source                = "azure/azapi"
      version               = "~> 2.0"
      configuration_aliases = [azapi.source, azapi.destination]
    }
  }
}