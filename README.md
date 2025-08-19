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
| terraform | >= 1.12 |
| azapi | >= 2.0 |

## Quick Start

See the [basic example](examples/basic-example/main.tf) for a full working configuration.

Steps:
1. Create (or reference) your NSGs using the AzAPI or Azurerm provider.
2. Configure provider aliases if you target different subscriptions (see `terraform.tf`).
3. Add the module block with `source`, priority ranges, and rules.
4. Run `terraform init` then `terraform apply`.

Minimal module usage:
```hcl
module "nsgator" {
  source = "../" # or registry source

  source_nsg_id      = azurerm_network_security_group.source.id
  destination_nsg_id = azurerm_network_security_group.destination.id

  priority_range = {
    source_start      = 1000
    source_end        = 1100
    destination_start = 2000
    destination_end   = 2100
  }

  rules = {
    web = {
      source_ips      = ["10.1.1.0/24"]
      destination_ips = ["10.2.1.0/24"]
      ports           = ["80"]
      protocol        = "Tcp"
      workload        = "web"
    }
  }
}
```


## Rule Naming Convention

The module automatically prefixes rule names based on direction:
- **Outbound rules** (source NSG): `outbound-${workload}-${protocol}` (e.g., `outbound-web-Tcp`)
- **Inbound rules** (destination NSG): `inbound-${workload}-${protocol}` (e.g., `inbound-web-Tcp`)
- The `workload` property must be unique across all rules to avoid conflicts

This naming convention helps identify rule direction and purpose at a glance.

## Priority Assignment Logic

1. **Existing Rules**: If a rule with identical properties exists, the module preserves its current priority
2. **New Rules**: Assigned sequential priorities starting from the highest existing priority + 1
3. **Range Validation**: New rules are only created if they fall within the specified priority range
4. **Error Handling**: Rules that would exceed the priority range are skipped with an error message

## Validation and Error Handling

The module enforces extensive input validation to surface errors early:

- At least one of `source_nsg_id` or `destination_nsg_id` must be provided.
- Priority range fields required (and validated 100–4096, start < end) only for the side whose NSG ID is provided.
- Protocol must be one of: `Tcp`, `Udp`, `Icmp`, `Esp`, `Ah`, `*`.
- Workload names must be unique (used in rule naming).
- ICMP rules must NOT declare ports; non‑ICMP rules must declare at least one port.
- Exactly one of `source_ips` or `source_service_tag` must be supplied (not both, not neither) per rule.
- Exactly one of `destination_ips` or `destination_service_tag` must be supplied (not both, not neither) per rule.
- A service tag cannot be combined with the corresponding NSG ID for that direction (e.g. `source_service_tag` with `source_nsg_id`).
- When service tag is provided the matching IP set must be omitted (and vice versa).

Rules that fail validation will stop planning with a clear multi‑line error message. Rules whose computed priority would fall outside the configured range are skipped via resource precondition failure.


## Configuration Reference
### Input Variables

| Name                  | Description                                                        | Type                                                                 | Default | Required |
|-----------------------|--------------------------------------------------------------------|----------------------------------------------------------------------|---------|:--------:|
| source_nsg_id         | The ID of the source NSG                                          | `string`                                                             | `null`  |  no\*    |
| destination_nsg_id    | The ID of the destination NSG                                     | `string`                                                             | `null`  |  no\*    |
| create_outbound_rules | Flag to create outbound rules                                      | `bool`                                                               | `true`  |   no     |
| create_inbound_rules  | Flag to create inbound rules                                       | `bool`                                                               | `true`  |   no     |
| rules                 | Map of rules to create (see rules object details)                  | <pre>map(object({<br>  access                  = optional(string, "Allow")<br>  source_ips              = optional(set(string))        # required if source_service_tag unset<br>  destination_ips         = optional(set(string))        # required if destination_service_tag unset<br>  ports                   = optional(set(string))        # required unless protocol == Icmp<br>  destination_service_tag = optional(string, null)<br>  protocol                = string<br>  workload                = string                       # unique<br>  source_port_range       = optional(string, "*")<br>  source_service_tag      = optional(string, null)<br>}))</pre> | n/a     |   yes    |
| priority_range        | Priority ranges for source and destination NSGs                   | <pre>object({<br>  source_start      = optional(number, 0)<br>  source_end        = optional(number, 0)<br>  destination_start = optional(number, 0)<br>  destination_end   = optional(number, 0)<br>})</pre> | n/a     |   yes    |

\*At least one of `source_nsg_id` or `destination_nsg_id` must be provided.

### priority_range Object

```hcl
priority_range = {
  source_start      = optional(number, 0)  # Start of priority range for source NSG (required if source_nsg_id is provided, must be 100-4096)
  source_end        = optional(number, 0)  # End of priority range for source NSG (required if source_nsg_id is provided, must be 100-4096)
  destination_start = optional(number, 0)  # Start of priority range for destination NSG (required if destination_nsg_id is provided, must be 100-4096)
  destination_end   = optional(number, 0)  # End of priority range for destination NSG (required if destination_nsg_id is provided, must be 100-4096)
}
```

### rules Object

The module supports traditional IP / CIDR based rules as well as Azure Service Tags for the *source* or *destination* side of a flow (but not both sides in the same direction). A rule replaces address *sets* with a single service tag when a `*_service_tag` attribute is provided.

```hcl
rules = {
  # Standard TCP rule
  web = {
    source_ips        = ["10.1.1.0/24"]
    destination_ips   = ["10.2.1.0/24"]
    ports             = ["80", "443"]
    protocol          = "Tcp"
    workload          = "web"
  }

  # Outbound using destination service tag
  reach_aad = {
    source_ips              = ["10.1.1.0/24"]
    destination_service_tag = "AzureActiveDirectory"
    ports                   = ["443"]
    protocol                = "Tcp"
    workload                = "aad"
    access                  = "Allow"
  }

  # Inbound using source service tag
  from_storage = {
    source_service_tag = "Storage"
    destination_ips    = ["10.2.1.10/32"]
    ports              = ["443"]
    protocol           = "Tcp"
    workload           = "storage-ingress"
  }

  # ICMP (no ports)
  ping = {
    source_ips      = ["10.1.1.0/24"]
    destination_ips = ["10.2.1.0/24"]
    protocol        = "Icmp"
    workload        = "ping"
  }
}
```

**Important Notes / Validation Rules:**
1. `workload` must be unique across all rules.
2. ICMP rules must NOT set `ports`. All other protocols must set at least one port.
3. If `source_service_tag` is provided:
   - `source_ips` must NOT be set.
   - `source_ips` must be set when `source_service_tag` is NOT provided.
   - You must NOT provide `source_service_tag` together with a `source_nsg_id` (the service tag represents an external source, not another managed NSG).
4. If `destination_service_tag` is provided:
   - `destination_ips` must NOT be set.
   - `destination_ips` must be set when `destination_service_tag` is NOT provided.
   - You must NOT provide `destination_service_tag` together with a `destination_nsg_id`.
5. Service tags are mutually exclusive with address lists on the same side of a rule.
6. Protocol must be one of: `Tcp`, `Udp`, `Icmp`, `Esp`, `Ah`, `*` (case sensitive as shown).
7. Priorities are auto-assigned only when they fall inside the configured range; out-of-range rules are skipped with a precondition error.

## Outputs

This module does not expose outputs. Rule creation status can be monitored through Terraform plan/apply output.

## Automatic Tagging

NSGator automatically adds tags to managed NSGs for tracking and governance:
- `managed_by_terraform_outbound_priority_range`: Priority range for outbound rules (e.g., "1000-1100")
- `managed_by_terraform_inbound_priority_range`: Priority range for inbound rules (e.g., "2000-2100")

These tags help identify which priority ranges are managed by Terraform and prevent conflicts with manually created rules.

## Service Tags Support

You can use Azure Service Tags instead of explicit IP/CIDR sets for EITHER the source side (inbound rules) or destination side (outbound rules) of a flow:

- Use `source_service_tag` to represent the origin (e.g. `Storage`, `AzureMonitor`) when creating inbound rules to your destination NSG.
- Use `destination_service_tag` to represent the target (e.g. `AzureActiveDirectory`, `KeyVault`) when creating outbound rules from your source NSG.

Design constraints enforced by validation:
- A service tag replaces the corresponding `*_ips` collection.
- Do not supply `source_service_tag` together with `source_ips` or a `source_nsg_id`.
- Do not supply `destination_service_tag` together with `destination_ips` or a `destination_nsg_id`.

This pattern lets you model flows where one side is an Azure platform service and the other side is a controlled address space.

## Limitations

- **Priority Ranges**: Rules are skipped if they would exceed the configured priority range (100-4096).
- **Unique Workloads**: Each rule must have a unique workload identifier.
- **Protocol-Specific Ports**: ICMP rules don't require ports; all other protocols do.
- **Service Tag Exclusivity**: Service tags cannot be combined with IP sets or NSG IDs on the same side of the rule.
- **Cross-Subscription**: Requires proper provider configuration for cross-subscription deployments.

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