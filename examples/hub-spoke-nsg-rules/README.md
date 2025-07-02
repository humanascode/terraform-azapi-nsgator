# Simple NSGator Example

This example demonstrates how to use the NSGator module to manage NSG rules in a simple two-spoke network topology.

## Scenario

This example creates:
- Two spoke virtual networks with associated NSGs
- Intranet communication rules between spokes (web tier -> database tier)
- Internet-facing rules for web traffic
- Default deny-all rules at priority 4000 for security

## Architecture

```
Internet
   |
   v
Spoke1 VNet (10.1.0.0/16)        Spoke2 VNet (10.2.0.0/16)
├── Web Subnet (10.1.1.0/24)     ├── DB Subnet (10.2.1.0/24)
└── NSG: nsg-spoke1-web          └── NSG: nsg-spoke2-db
    (Default Deny All @ 4000)        (Default Deny All @ 4000)
```

## Rules Created

### Intranet Rules (priorities 1000-3100)
1. **Database Access**: Spoke1 → Spoke2 (SQL Server, MySQL)
2. **Cache Access**: Spoke1 → Spoke2 (Redis)

### Internet Rules (priorities 3000-3100)
1. **Web Traffic**: Internet → Spoke1 (HTTP/HTTPS)
2. **Admin Access**: Admin IP → Spoke1 (SSH)

### Security
- **Default Deny All**: Both NSGs have deny-all rules at priority 4000

## Usage

1. Update the `terraform.tfvars` file with your admin IP
2. Run the following commands:

```bash
terraform init
terraform plan
terraform apply
```

## Clean Up

```bash
terraform destroy
```
