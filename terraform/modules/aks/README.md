# AKS Module

This module deploys an Azure Kubernetes Service (AKS) cluster with support for standard CPU-based user workloads, integrated with Azure services like Key Vault and Log Analytics.

## Features

- AKS cluster with system and user node pools
- Azure CNI networking
- Azure Policy integration
- Microsoft Defender for Containers
- Key Vault integration
- Log Analytics integration
- Auto-scaling for node pools (configurable)
- RBAC enabled

## Usage

```hcl
module "aks" {
  source = "../../modules/aks"

  environment = "dev"
  location    = "uaenorth"
  project     = "platform-core"
  tags        = {
    Environment = "dev"
    Project     = "platform-core"
  }

  subnet_id = module.network.aks_subnet_id
  keyvault_id = module.keyvault.key_vault_id

  system_node_pool = {
    name            = "system"
    node_count      = 2
    vm_size         = "Standard_D4s_v3"
    os_disk_size_gb = 100
    min_count       = 2
    max_count       = 4
  }

  user_node_pool = {
    name                  = "user"
    node_count            = 1
    vm_size               = "Standard_D4s_v3" # Standard CPU VM
    os_disk_size_gb       = 100
    enable_auto_scaling = false
    min_count             = 1 
    max_count             = 3 
    gpu_enabled           = false
    node_labels           = {}
  }
}
```

## Node Pools

### System Node Pool
- Used for system workloads
- Auto-scaling enabled by default (can be configured)
- Azure CNI networking
- Default VM size: Standard_D4s_v3

### User Node Pool
- Used for application workloads
- Auto-scaling configurable (disabled by default in the example)
- Default VM size: Standard_D4s_v3 (CPU)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | The environment (dev, stg, prd) | `string` | n/a | yes |
| location | The Azure region where resources will be created | `string` | n/a | yes |
| project | The project name | `string` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | n/a | yes |
| kubernetes_version | Kubernetes version | `string` | "1.30.4" | no |
| subnet_id | The subnet ID for the AKS cluster | `string` | n/a | yes |
| keyvault_id | The ID of the Key Vault for secrets integration | `string` | n/a | yes |
| system_node_pool | System node pool configuration | `object` | n/a | yes |
| user_node_pool | User node pool configuration | `object` | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The Kubernetes Managed Cluster ID |
| cluster_name | The Kubernetes Managed Cluster name |
| cluster_identity_id | The ID of the User Assigned Identity used for the AKS cluster |
| kube_config | The Kubernetes configuration (sensitive) |
| kube_config_host | The Kubernetes cluster server host |
| log_analytics_workspace_id | The ID of the Log Analytics Workspace |
| resource_group_name | The name of the resource group |
| resource_group_id | The ID of the resource group |

## Security Features

- Microsoft Defender for Containers enabled
- Key Vault integration for secrets
- RBAC enabled
- Network policies enabled
- Private cluster (optional)
- System-assigned managed identity

## Monitoring

- Log Analytics integration
- Container insights enabled
- Metrics collection
- Log collection

## Dependencies

- Azure Provider
- Network Module (for subnet)
- Key Vault Module (for secrets integration)
- Resource Group (created by the module)

## Notes

- Auto-scaling is configurable for node pools.
- System node pool cannot be deleted.
- The user node pool is configured for general-purpose CPU workloads by default.