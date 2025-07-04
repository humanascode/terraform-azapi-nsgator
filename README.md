# Azure Network Security Group Rules Management Module (NSGator)

A Terraform module for managing Network Security Group (NSG) rules in Azure with intelligent priority assignment and duplicate detection.

<img src="images/nsgator.png" alt="NSGator Logo" width="200"/>

## What is NSGator?

NSGator is a Terraform module that automates Azure NSG rule management by handling priority assignment, detecting duplicates, and ensuring consistent rule deployment across network security groups.

Its input is a map of objcets, each object reprsents a connectivity path including source and destination IPs, ports, protocols, and a workload identifier. The module takes care of creating inbound and outbound rules as needed and manages priorities intelligently to avoid conflicts and ensure zero-downtime updates.

## Who is it for?

This module simplifies managing multiple rules across Azure Network Security Groups (NSGs). It's especially useful for organizations using deny-by-default security policies that need to explicitly allow traffic for specific workloads while maintaining clear and consistent rule management.

## Overview

NSGator simplifies Azure NSG rule management by providing:
- **Intelligent Priority Assignment**: Automatically assigns priorities to new rules within specified ranges
- **Smart Duplicate Detection**: Identifies and preserves existing rules to prevent conflicts
- **Bidirectional Rule Support**: Creates both inbound and outbound rules as needed
- **Automated Tagging**: Tracks Terraform-managed priority ranges with NSG tags

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azapi | >= 2.0 |

## Quick Start

For a complete working example, see the [basic example](examples/basic-example/main.tf) in the examples directory.

Just:
- Copy the main.tf file
- Update your subscription ID under the `azurerm` provider block
- Run `terraform init` to initialize the module
- Run `terraform apply` to create the NSG rules


## Rule Naming Convention

The module automatically prefixes rule names based on direction:
- **Outbound rules** (source NSG): `outbound-${workload}-${protocol}` (e.g., `outbound-web-Tcp`)
- **Inbound rules** (destination NSG): `inbound-${workload}-${protocol}` (e.g., `inbound-web-Tcp`)

This naming convention helps identify rule direction and purpose at a glance.

## Priority Assignment Logic

1. **Existing Rules**: If a rule with identical properties exists, the module preserves its current priority
2. **New Rules**: Assigned sequential priorities starting from the highest existing priority + 1
3. **Range Validation**: New rules are only created if they fall within the specified priority range
4. **Error Handling**: Rules that would exceed the priority range are skipped with an error message


## Configuration Reference
### Input Variables

| Name                  | Description                                                        | Type                                                                 | Default | Required |
|-----------------------|--------------------------------------------------------------------|----------------------------------------------------------------------|---------|:--------:|
| source_nsg_id         | The ID of the source NSG                                          | `string`                                                             | `null`  |  no\*    |
| destination_nsg_id    | The ID of the destination NSG                                     | `string`                                                             | `null`  |  no\*    |
| create_outbound_rules | Flag to create outbound rules                                      | `bool`                                                               | `true`  |   no     |
| create_inbound_rules  | Flag to create inbound rules                                       | `bool`                                                               | `true`  |   no     |
| rules                 | Map of rules to create                                             | <pre>map(object({<br>  access            = optional(string, "Allow")<br>  source_ips        = set(string)<br>  destination_ips   = set(string)<br>  ports             = set(string)<br>  protocol          = string<br>  workload          = string<br>  source_port_range = optional(string, "*")<br>}))</pre> | n/a     |   yes    |
| priority_range        | Priority ranges for source and destination NSGs                   | <pre>object({<br>  source_start      = optional(number, 0)<br>  source_end        = optional(number, 0)<br>  destination_start = optional(number, 0)<br>  destination_end   = optional(number, 0)<br>})</pre> | n/a     |   yes    |

\*At least one of `source_nsg_id` or `destination_nsg_id` must be provided.

### priority_range Object

```hcl
priority_range = {
  source_start      = optional(number, 0)  # Start of priority range for source NSG (required if source_nsg_id is provided)
  source_end        = optional(number, 0)  # End of priority range for source NSG (required if source_nsg_id is provided)
  destination_start = optional(number, 0)  # Start of priority range for destination NSG (required if destination_nsg_id is provided)
  destination_end   = optional(number, 0)  # End of priority range for destination NSG (required if destination_nsg_id is provided)
}
```

### rules Object

```hcl
rules = {
  "rule-name" = {
    access            = "Allow"                       # Allow or Deny (optional, defaults to Allow)
    source_ips        = ["10.1.1.0/24", "10.1.2.10"] # Set of source IP addresses/CIDR ranges
    destination_ips   = ["10.2.1.0/24", "10.2.2.20"] # Set of destination IP addresses/CIDR ranges
    ports             = ["80", "443"]                 # Set of destination ports
    protocol          = "Tcp"                         # Protocol: Tcp, Udp, Icmp, Esp, Ah, or *
    workload          = "web"                         # Workload identifier for rule naming
    source_port_range = "*"                           # Source port range (optional, defaults to "*")
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

## Cross-Subscription deployment
- NSGs can be deployed across different subscriptions, when calling the module, provide 2 providers in the module block:
  - `source_nsg_id` for the source NSG
  - `destination_nsg_id` for the destination NSG
example:
```hcl
providers {
  source = azapi.source
  destination = azapi.destination
}
```


## Examples

For complete examples, see the `examples/` directory:
- `examples/basic-example/` - Simple single configuration example
- `examples/hub-spoke-nsg-rules/` - Multi-tier architecture example

## Contributing

1. Feel free to open issues for bugs or feature requests
2. Pull requests are welcome! Please ensure your changes include tests and documentation updates

## License

This module is provided as-is. It is not intended for production use without thorough testing and validation in your specific environment.