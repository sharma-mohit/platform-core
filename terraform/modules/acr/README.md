# ACR Module

This module deploys an Azure Container Registry (ACR) with private endpoint, geo-replication, and integration with AKS.

## Features

- Premium SKU Azure Container Registry
- Private endpoint for secure access
- Geo-replication for high availability
- Network rules for access control
- RBAC integration with AKS
- Private DNS Zone integration
- Resource Group management

## Usage

```hcl
module "acr" {
  source = "../../modules/acr"

  environment = "dev"
  location    = "uaenorth"
  project     = "platform-core"
  tags        = {
    Environment = "dev"
    Project     = "platform-core"
  }

  vnet_id         = module.network.vnet_id
  subnet_id       = module.network.acr_subnet_id
  aks_identity_id = module.aks.cluster_identity_id
}
```

## Network Configuration

- Private endpoint in dedicated subnet
- Network rules to deny public access
- Service endpoint for Container Registry
- Private DNS Zone for private endpoint

## Geo-replication

The module configures geo-replication to a secondary region (uaecentral) with:
- Zone redundancy enabled
- Automatic replication
- Same tags as primary region

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | The environment (dev, stg, prd) | `string` | n/a | yes |
| location | The Azure region where resources will be created | `string` | n/a | yes |
| project | The project name | `string` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | n/a | yes |
| vnet_id | The ID of the Virtual Network | `string` | n/a | yes |
| subnet_id | The subnet ID for the ACR private endpoint | `string` | n/a | yes |
| aks_identity_id | The ID of the AKS cluster's managed identity | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| acr_id | The ID of the Container Registry |
| acr_name | The name of the Container Registry |
| acr_login_server | The login server of the Container Registry |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group |
| private_endpoint_ip | The private IP address of the ACR private endpoint |

## Security Features

- Private endpoint for secure access
- Network rules to deny public access
- RBAC integration with AKS
- Admin user disabled by default
- Premium SKU for advanced features

## Dependencies

- Azure Provider
- Network Module (for VNet and subnet)
- AKS Module (for identity)
- Resource Group (created by the module)

## Notes

- ACR name must be globally unique
- Premium SKU required for geo-replication
- Private endpoint requires Premium SKU
- AKS integration requires AcrPull role assignment
- Network rules are set to deny public access by default