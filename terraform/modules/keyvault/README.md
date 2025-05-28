# Key Vault Module

This module deploys an Azure Key Vault with private endpoint, access policies, and diagnostic settings, integrated with AKS and Log Analytics.

## Features

- Premium SKU Azure Key Vault
- Private endpoint for secure access
- Access policies for AKS integration
- Network rules for access control
- Diagnostic settings with Log Analytics
- Soft delete and purge protection
- Private DNS Zone integration
- Resource Group management

## Usage

```hcl
module "keyvault" {
  source = "../../modules/keyvault"

  environment = "dev"
  location    = "uaenorth"
  project     = "platform-core"
  tags        = {
    Environment = "dev"
    Project     = "platform-core"
  }

  tenant_id                  = "your-tenant-id"
  vnet_id                    = module.network.vnet_id
  subnet_id                  = module.network.keyvault_subnet_id
  aks_identity_id            = module.aks.cluster_identity_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id
  allowed_ip_ranges          = ["10.0.0.0/24"]  # Optional
}
```

## Network Configuration

- Private endpoint in dedicated subnet
- Network rules to deny public access
- Service endpoint for Key Vault
- Private DNS Zone for private endpoint
- Optional IP range allowlist

## Access Policies

The module configures access policies for:
- AKS cluster identity (Get, List permissions)
- Secrets and certificates access
- RBAC integration

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | The environment (dev, stg, prd) | `string` | n/a | yes |
| location | The Azure region where resources will be created | `string` | n/a | yes |
| project | The project name | `string` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | n/a | yes |
| tenant_id | The Azure tenant ID | `string` | n/a | yes |
| vnet_id | The ID of the Virtual Network | `string` | n/a | yes |
| subnet_id | The subnet ID for the Key Vault private endpoint | `string` | n/a | yes |
| aks_identity_id | The ID of the AKS cluster's managed identity | `string` | n/a | yes |
| log_analytics_workspace_id | The ID of the Log Analytics Workspace | `string` | n/a | yes |
| allowed_ip_ranges | List of IP ranges allowed to access the Key Vault | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| key_vault_id | The ID of the Key Vault |
| key_vault_name | The name of the Key Vault |
| key_vault_uri | The URI of the Key Vault |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group |
| private_endpoint_ip | The private IP address of the Key Vault private endpoint |

## Security Features

- Private endpoint for secure access
- Network rules to deny public access
- Soft delete enabled (7 days retention)
- Purge protection enabled
- Access policies for AKS integration
- Diagnostic logging to Log Analytics
- Premium SKU for advanced features

## Monitoring

- Diagnostic settings configured
- Audit logs enabled
- Metrics collection
- 30-day log retention
- Log Analytics integration

## Dependencies

- Azure Provider
- Network Module (for VNet and subnet)
- AKS Module (for identity and Log Analytics)
- Resource Group (created by the module)

## Notes

- Key Vault name must be globally unique
- Premium SKU required for private endpoint
- Soft delete cannot be disabled
- Purge protection prevents accidental deletion
- Network rules are set to deny public access by default
- Access policies are configured for AKS integration