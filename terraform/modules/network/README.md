# Network Module

This module creates the core networking infrastructure for the Platform Core environment, including Virtual Network, Subnets, Network Security Groups, and Private DNS Zones.

## Features

- Virtual Network with multiple subnets
- Network Security Groups with basic rules
- Private DNS Zones for private endpoints
- Service Endpoints for Azure services
- Resource Group management

## Usage

```hcl
module "network" {
  source = "../../modules/network"

  environment = "dev"
  location    = "uaenorth"
  project     = "platform-core"
  tags        = {
    Environment = "dev"
    Project     = "platform-core"
  }
}
```

## Subnets

The module creates the following subnets:

1. **AKS Subnet** (`10.0.0.0/20`)
   - Service endpoints: Key Vault, Container Registry, Storage
   - Used for AKS cluster nodes

2. **ACR Subnet** (`10.0.16.0/24`)
   - Service endpoint: Container Registry
   - Used for ACR private endpoint

3. **Key Vault Subnet** (`10.0.17.0/24`)
   - Service endpoint: Key Vault
   - Used for Key Vault private endpoint

## Network Security Rules

Default security rules:
- Allow HTTPS (443) inbound
- Allow HTTP (80) inbound

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | The environment (dev, stg, prd) | `string` | n/a | yes |
| location | The Azure region where resources will be created | `string` | n/a | yes |
| project | The project name | `string` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | The ID of the Virtual Network |
| vnet_name | The name of the Virtual Network |
| aks_subnet_id | The ID of the AKS subnet |
| acr_subnet_id | The ID of the ACR subnet |
| keyvault_subnet_id | The ID of the Key Vault subnet |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group |

## Security Considerations

- All subnets have private endpoint network policies enabled
- Network Security Groups are applied to all subnets
- Service endpoints are enabled for required Azure services
- Private DNS Zones are created for private endpoints

## Dependencies

- Azure Provider
- Resource Group (created by the module)