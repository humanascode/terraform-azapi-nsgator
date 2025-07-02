# Azure Network Security Group Rules Management Module (NSGator)

A Terraform module for managing Network Security Group (NSG) rules in Azure with intelligent priority assignment and duplicate detection.

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)

## What is NSGator?

NSGator (Network Security Group Gator) is a Terraform module that automates Azure NSG rule management by handling priority assignment, detecting duplicates, and ensuring consistent rule deployment across network security groups.

## Who is it for?

This module simplifies managing multiple rules across Azure Network Security Groups (NSGs). It's especially useful for organizations using deny-by-default security policies that need to explicitly allow traffic for specific workloads while maintaining clear and consistent rule management.

## Overview

NSGator simplifies Azure NSG rule management by providing:
- **Intelligent Priority Assignment**: Automatically assigns priorities to new rules within specified ranges
- **Smart Duplicate Detection**: Identifies and preserves existing rules to prevent conflicts
- **Bidirectional Rule Support**: Creates both inbound and outbound rules as needed
- **Automated Tagging**: Tracks Terraform-managed priority ranges with NSG tags
- **Zero-Downtime Updates**: Preserves existing rule priorities during updates

## Key Features

- **Smart Priority Management**: Automatically assigns priorities to new rules while respecting existing ones
- **Duplicate Detection**: Identifies existing rules based on rule properties to prevent conflicts
- **Flexible Configuration**: Supports source-only, destination-only, or both NSG configurations
- **Range Validation**: Ensures new rules are created within specified priority ranges
- **Tag Management**: Adds tags to NSGs indicating Terraform-managed priority ranges
- **Idempotent Operations**: Safe to run multiple times without side effects

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 3.0 |
| azapi | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.0 |
| azapi | >= 1.0 |

## Quick Start

```hcl
module "nsg_rules" {
  source = "./network_module"
  
  source_nsg_id      = azurerm_network_security_group.source.id
  destination_nsg_id = azurerm_network_security_group.destination.id
  
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
    }
  }
}
```

## Detailed Examples

### Complete Example with Multiple Rules

```hcl
module "nsg_rules" {
  source = "./network_module"
  
  source_nsg_id      = "/subscriptions/xxx/resourceGroups/rg-network/providers/Microsoft.Network/networkSecurityGroups/nsg-source"
  destination_nsg_id = "/subscriptions/xxx/resourceGroups/rg-network/providers/Microsoft.Network/networkSecurityGroups/nsg-destination"
  
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
    }
    "ssh-access" = {
      source_ips      = ["10.1.1.10"]
      destination_ips = ["10.2.1.20"]
      ports           = ["22"]
      protocol        = "Tcp"
      workload        = "ssh"
    }
    "database-access" = {
      source_ips      = ["10.1.2.0/24"]
      destination_ips = ["10.2.3.0/24"]
      ports           = ["1433"]
      protocol        = "Tcp"
      workload        = "sql"
    }
  }
}
```

### Outbound Rules Only (Source NSG)

```hcl
module "outbound_rules" {
  source = "./network_module"
  
  source_nsg_id = "/subscriptions/xxx/resourceGroups/rg-network/providers/Microsoft.Network/networkSecurityGroups/nsg-source"
  
  priority_range = {
    source_start      = 1000
    source_end        = 1100
    destination_start = 2000  # Required but not used
    destination_end   = 2100  # Required but not used
  }
  
  rules = {
    "outbound-web" = {
      source_ips      = ["10.1.1.0/24"]
      destination_ips = ["0.0.0.0/0"]
      ports           = ["443"]
      protocol        = "Tcp"
      workload        = "web-outbound"
    }
  }
}
```

### Inbound Rules Only (Destination NSG)

```hcl
module "inbound_rules" {
  source = "./network_module"
  
  destination_nsg_id = "/subscriptions/xxx/resourceGroups/rg-network/providers/Microsoft.Network/networkSecurityGroups/nsg-destination"
  
  priority_range = {
    source_start      = 1000  # Required but not used
    source_end        = 1100  # Required but not used
    destination_start = 2000
    destination_end   = 2100
  }
  
  rules = {
    "web-inbound" = {
      source_ips      = ["0.0.0.0/0"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["80"]
      protocol        = "Tcp"
      workload        = "web-public"
    }
    "api-inbound" = {
      source_ips      = ["10.1.0.0/16"]
      destination_ips = ["10.2.2.0/24"]
      ports           = ["8080"]
      protocol        = "Tcp"
      workload        = "api"
    }
  }
}
```

## Rule Naming Convention

The module automatically prefixes rule names based on direction:
- **Outbound rules** (source NSG): `o-{workload}` (e.g., `o-web`, `o-ssh`)
- **Inbound rules** (destination NSG): `i-{workload}` (e.g., `i-web`, `i-api`)

This naming convention helps identify rule direction and purpose at a glance.

## Priority Assignment Logic

1. **Existing Rules**: If a rule with identical properties exists, the module preserves its current priority
2. **New Rules**: Assigned sequential priorities starting from the highest existing priority + 1
3. **Range Validation**: New rules are only created if they fall within the specified priority range
4. **Error Handling**: Rules that would exceed the priority range are skipped with an error message

## How It Works

### Duplicate Detection

The module identifies duplicate rules by comparing:
- Rule name pattern (`o-{workload}` or `i-{workload}`)
- Source IP addresses
- Destination IP addresses
- Destination port
- Protocol

### Priority Calculation

1. Scans existing NSG rules to find the highest priority
2. Assigns new priorities sequentially starting from `highest_priority + 1`
3. Validates that new priorities fall within the configured range
4. Skips rule creation if priority would exceed the range

## Configuration Reference

### Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| source_nsg_id | The resource ID of the source NSG for outbound rules | `string` | `null` | no* |
| destination_nsg_id | The resource ID of the destination NSG for inbound rules | `string` | `null` | no* |
| priority_range | Priority ranges for source and destination NSGs | `object` | n/a | yes |
| rules | Map of security rules to create | `map(object)` | n/a | yes |

*At least one of `source_nsg_id` or `destination_nsg_id` must be provided.

### priority_range Object

```hcl
priority_range = {
  source_start      = number  # Start of priority range for source NSG
  source_end        = number  # End of priority range for source NSG
  destination_start = number  # Start of priority range for destination NSG
  destination_end   = number  # End of priority range for destination NSG
}
```

### rules Object

```hcl
rules = {
  "rule-name" = {
    source_ips      = ["10.1.1.0/24", "10.1.2.10"]  # List of source IP addresses/CIDR ranges
    destination_ips = ["10.2.1.0/24", "10.2.2.20"]  # List of destination IP addresses/CIDR ranges
    ports           = ["80", "443"]                   # List of destination ports
    protocol        = "Tcp"                           # Protocol: Tcp, Udp, Icmp, Esp, Ah, or *
    workload        = "web"                           # Workload identifier for rule naming
    access          = "Allow"                         # Allow or Deny (optional, defaults to Allow)
  }
}
```

## Outputs

This module does not expose outputs. Rule creation status can be monitored through Terraform plan/apply output.

## Automatic Tagging

NSGator automatically adds tags to managed NSGs for tracking and governance:
- `managed_by_terraform_outbound_priority_range`: Priority range for outbound rules (e.g., "1000-1100")
- `managed_by_terraform_inbound_priority_range`: Priority range for inbound rules (e.g., "2000-2100")

These tags help identify which priority ranges are managed by Terraform and prevent conflicts with manually created rules.

## Limitations

- **Multiple Ports**: Supports multiple destination ports per rule
- **Priority Ranges**: Rules are skipped if they would exceed the configured priority range
- **Source Port**: Always set to `*` (any source port)
- **Access Control**: Supports both Allow and Deny rules
- **Cross-Resource Group**: NSGs must be accessible from the same subscription context

## Error Handling

NSGator includes robust validation and error handling:
- **Input Validation**: Ensures at least one NSG ID is provided
- **Priority Validation**: Prevents rule creation outside specified ranges
- **Lifecycle Management**: Ignores priority changes to prevent configuration drift
- **Pre-condition Checks**: Validates rule configuration before creation

## Best Practices

1. **Priority Ranges**: Use non-overlapping ranges with sufficient space
   - Outbound: 1000-1999
   - Inbound: 2000-2999
   - Leave gaps for manual rules if needed

2. **Workload Names**: Use descriptive, unique identifiers
   - Good: `web`, `api`, `database`, `ssh-admin`
   - Avoid: `rule1`, `temp`, `test`

3. **IP Ranges**: Use CIDR notation for network ranges
   - Preferred: `10.1.0.0/24`
   - Works: `10.1.0.1`

4. **Testing Strategy**:
   - Validate in development first
   - Use `terraform plan` to review changes
   - Monitor rule creation in Azure portal

5. **Updates**: Let NSGator manage priorities
   - Don't manually modify rule priorities
   - Update through Terraform configuration

## Examples

For complete examples, see the `examples/` directory:
- `examples/simple/` - Basic single NSG example
- `examples/hub-spoke-nsg-rules/` - Multi-tier architecture example

## Contributing

1. Follow Terraform best practices and conventions
2. Update documentation for any new features or changes
3. Test with various NSG configurations and scenarios
4. Ensure backward compatibility with existing deployments
5. Report issues with detailed reproduction steps

## License

This module is provided as-is for educational and development purposes.

---

**NSGator** - Making Azure NSG rule management as easy as it should be!
