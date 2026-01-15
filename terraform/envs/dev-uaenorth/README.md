# Development Environment - UAE North

This directory contains the Terraform configuration for the development environment in the UAE North region.

## Current Status

✅ **Fully Deployed and Operational**

- **AKS Cluster**: `platform-core-dev-aks` (Kubernetes 1.34.1)
- **Provisioning State**: Succeeded
- **Power State**: Running
- **Node Pools**: 
  - System pool: 2 nodes
  - User pool: 1 node

## Infrastructure Components

### Deployed Resources

1. **AKS Cluster** (`platform-core-dev-aks`)
   - Kubernetes version: 1.34.1
   - Customer-managed key encryption enabled
   - System and user node pools configured
   - Workload Identity enabled
   - OIDC issuer enabled

2. **Azure Container Registry** (`platformcoredevacr`)
   - Private endpoint configured
   - AKS has AcrPull role assignment

3. **Azure Key Vault** (`platform-core-dev-kv`)
   - RBAC authorization enabled
   - Disk encryption enabled
   - Private endpoint configured
   - Network ACLs include AKS subnet for disk encryption

4. **Disk Encryption Set** (`platform-core-dev-aks-des`)
   - Customer-managed key encryption
   - RBAC role assignment to Key Vault

5. **Network Infrastructure**
   - Virtual network with subnets for AKS, ACR, and Key Vault
   - Network security groups configured
   - Private endpoints for all services

6. **Log Analytics Workspace** (`platform-core-dev-law`)
   - Container insights enabled
   - Diagnostic settings configured

## Deployment Steps

```bash
# 1. Navigate to environment directory
cd terraform/envs/dev-uaenorth

# 2. Initialize Terraform
terraform init -backend-config=backend.hcl

# 3. Create/select workspace
terraform workspace new dev  # First time only
terraform workspace select dev

# 4. Plan deployment
terraform plan -out=tfplan

# 5. Apply deployment
terraform apply tfplan
```

## Configuration Files

- `main.tf` - Main infrastructure configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Environment-specific variable values
- `backend.tf` - Terraform backend configuration
- `backend.hcl` - Backend configuration values

## Recent Fixes Applied

1. **Kubernetes Version**: Updated to 1.34.1 (from 1.30.4) to avoid LTS requirement
2. **Key Vault RBAC**: Disk encryption set now uses RBAC role assignments instead of access policies
3. **Network ACLs**: AKS subnet added to Key Vault network ACLs for disk encryption operations
4. **Disk Encryption**: Key Vault `enabled_for_disk_encryption` set to true

## Troubleshooting

### State Lock Issues
```bash
# If you encounter state lock errors
terraform force-unlock <lock-id>
```

### Importing Existing Resources
If resources exist in Azure but not in Terraform state:
```bash
# AKS Cluster
terraform import module.aks.azurerm_kubernetes_cluster.aks /subscriptions/<sub-id>/resourceGroups/rg-aks-dev-uaenorth-001/providers/Microsoft.ContainerService/managedClusters/platform-core-dev-aks

# User Node Pool
terraform import 'module.aks.azurerm_kubernetes_cluster_node_pool.user[0]' /subscriptions/<sub-id>/resourceGroups/rg-aks-dev-uaenorth-001/providers/Microsoft.ContainerService/managedClusters/platform-core-dev-aks/agentPools/user
```

### Key Vault Access Issues
- Verify disk encryption set has "Key Vault Crypto Service Encryption User" role
- Ensure AKS subnet is in Key Vault network ACLs
- Check that `enabled_for_disk_encryption = true` is set on Key Vault

## Outputs

```bash
terraform output
```

Current outputs:
- `aks_cluster_name`: platform-core-dev-aks
- `aks_cluster_resource_group_name`: rg-aks-dev-uaenorth-001

## Next Steps

1. Configure kubectl access:
   ```bash
   az aks get-credentials --name platform-core-dev-aks --resource-group rg-aks-dev-uaenorth-001
   ```

2. Verify cluster access:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. Proceed to Phase 2: GitOps & Platform Bootstrap (see `docs/phase2-howto.md`)

## References

- [Phase 1 Implementation Guide](../../../docs/phase1-howto.md)
- [Terraform Module Documentation](../../modules/)
- [Main README](../../../README.md)
