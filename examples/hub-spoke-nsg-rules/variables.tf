variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-nsgator-example"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "admin_ip" {
  description = "Admin IP address for management access"
  type        = string
  default     = "203.0.113.1" # Replace with your actual admin IP
}
