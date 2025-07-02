# NSGator Module - Intranet Communication (Spoke1 <-> Spoke2)
module "intranet_rules" {
  source = "../../" # Path to the NSGator module

  providers = {
    azapi.source = azapi
    azapi.destination = azapi
  }

  source_nsg_id      = azurerm_network_security_group.spoke1.id
  destination_nsg_id = azurerm_network_security_group.spoke2.id

  priority_range = {
    source_start      = 1000
    source_end        = 1100
    destination_start = 2000
    destination_end   = 2100
  }

  rules = {
    "web-to-db" = {
      source_ips      = ["10.1.1.0/24"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["1433", "3306"]
      protocol        = "Tcp"
      workload        = "database"
      access          = "Allow"
    }
    "web-to-cache" = {
      source_ips      = ["10.1.1.0/24"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["6379"]
      protocol        = "Tcp"
      workload        = "redis"
      access          = "Allow"
    }
  }
}

# NSGator Module - Internet Access (Internet -> Spoke1)
module "internet_rules" {
  source = "../../" # Path to the NSGator module

    providers = {
    azapi.source = azapi
    azapi.destination = azapi
  }

  destination_nsg_id = azurerm_network_security_group.spoke1.id
  create_outbound_rules = false

  priority_range = {
    destination_start = 3000
    destination_end   = 3100
  }

  rules = {
    "internet-web-http" = {
      source_ips      = ["0.0.0.0/0"]
      destination_ips = ["10.1.1.0/24"]
      ports           = ["80"]
      protocol        = "Tcp"
      workload        = "web-http"
      access          = "Allow"
    }
    "internet-web-https" = {
      source_ips      = ["0.0.0.0/0"]
      destination_ips = ["10.1.1.0/24"]
      ports           = ["443"]
      protocol        = "Tcp"
      workload        = "web-https"
      access          = "Allow"
    }
    "admin-ssh" = {
      source_ips      = [var.admin_ip]
      destination_ips = ["10.1.1.0/24"]
      ports           = ["22"]
      protocol        = "Tcp"
      workload        = "admin-ssh"
      access          = "Allow"
    }
  }
}
