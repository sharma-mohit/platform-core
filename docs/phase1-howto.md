# Phase 1 Implementation Guide

This guide provides step-by-step instructions for implementing Phase 1 of the platform infrastructure using Terraform, including customer-managed key encryption and sovereign cloud compliance.

## Prerequisites

1. Azure CLI installed and configured
2. Terraform v1.0.0 or later installed
3. Azure subscription with appropriate permissions
4. Azure Storage Account for Terraform state (created using `../scripts/setup-terraform-backend.sh`)
5. Understanding of UAE sovereign cloud compliance requirements

## Directory Structure

```
terraform/
├── backend.tf                 # Backend configuration
├── common.tfvars             # Common variables
├── dev.tfvars               # Dev environment variables
├── stg.tfvars               # Staging environment variables
├── prd.tfvars               # Production environment variables
├── main.tf                  # Main Terraform configuration
├── modules/                 # Terraform modules
│   ├── network/            # Network module
│   ├── aks/               # AKS module
│   ├── acr/              # ACR module
│   ├── keyvault/        # Key Vault module
│   ├── disk-encryption/ # Customer-managed key encryption
│   └── firewall/        # Azure Firewall module
└── scripts/             # Helper scripts
    ├── setup-terraform-backend.sh
    └── setup-ops-terraform-backend.sh
```

## Implementation Steps

### 1. Backend Setup

1. Run the backend setup script:
   ```bash
   cd scripts
   ./setup-terraform-backend.sh
   ```
   This script will:
   - Create a resource group
   - Create a Key Vault for customer-managed keys
   - Create a customer-managed encryption key
   - Create a user-assigned managed identity for key access
   - Create a storage account with customer-managed key encryption
   - Create a container for Terraform state
   - Generate backend configuration

2. Verify the backend configuration in `backend.tf`

### 2. Environment Configuration

1. Review and update common variables in `terraform/shared/common.tfvars`:
   - Project and organization settings
   - Network configuration
   - AKS node pool settings
   - ACR and Key Vault configurations
   - Security settings
   - Log Analytics settings
   - Customer-managed key configurations
   - Sovereign cloud compliance tags

2. Review and update environment-specific variables:
   - `terraform/envs/dev-uaenorth/dev.tfvars` for development
   - `terraform/envs/stg-uaenorth/stg.tfvars` for staging
   - `terraform/envs/prd-uaenorth/prd.tfvars` for production

   Each environment's tfvars file should override or extend the common variables as needed.

   **Important**: Ensure all required sovereign cloud tags are included:
   ```hcl
   tags = {
     createdBy   = "Terraform"
     environment = "dev"
     project     = "platform-core"
     region      = "uaenorth"
     costCenter  = "platform-team"
     owner       = "platform-team"
   }
   ```

### 3. Module Implementation

#### Network Module

1. Review the network module documentation in `../terraform/modules/network/README.md`
2. The module creates:
   - Virtual Network
   - Subnets for AKS, ACR, and Key Vault
   - Network Security Groups
   - Service Endpoints
   - Private Endpoints (where applicable)

#### AKS Module

1. Review the AKS module documentation in `../terraform/modules/aks/README.md`
2. The module deploys:
   - AKS cluster with system and user node pools
   - GPU node pool (optional)
   - Log Analytics integration
   - RBAC configuration
   - Network policies
   - Workload Identity support
   - Customer-managed key disk encryption

#### ACR Module

1. Review the ACR module documentation in `../terraform/modules/acr/README.md`
2. The module sets up:
   - Premium SKU Azure Container Registry
   - Private endpoint
   - Geo-replication
   - Network rules
   - AKS integration
   - Customer-managed key encryption

#### Key Vault Module

1. Review the Key Vault module documentation in `../terraform/modules/keyvault/README.md`
2. The module configures:
   - Premium SKU Key Vault
   - Private endpoint
   - Access policies
   - Network rules
   - Diagnostic settings
   - Customer-managed key encryption

#### Disk Encryption Module

1. Review the disk encryption module documentation in `../terraform/modules/disk-encryption/README.md`
2. The module configures:
   - Customer-managed key creation in Key Vault
   - Disk Encryption Set for AKS managed disks
   - Managed identity for key access
   - Key rotation policies

### 4. Deployment

1. **Set Working Directory**:
   ```bash
   # Navigate to the environment-specific directory
   cd terraform/envs/dev-uaenorth  # or stg-uaenorth, or prd-uaenorth
   ```

2. **Initialize Terraform**:
   ```bash
   # Initialize with backend configuration
   terraform init \
     -backend-config="backend.hcl" \
     -var-file="../../shared/common.tfvars"
   ```

   This will:
   - Configure the Azure backend for state storage
   - Initialize providers
   - Create the .terraform.lock.hcl file
   - Set up the working directory

   Note: Make sure to commit the .terraform.lock.hcl file to version control.

3. **Create and Select Workspace**:
   ```bash
   # List existing workspaces
   terraform workspace list

   # Create a new workspace if it doesn't exist
   terraform workspace new dev  # or stg, or prd

   # Select the workspace
   terraform workspace select dev  # or stg, or prd
   ```

4. **Plan the Deployment**:
   ```bash
   # Plan using both common and environment-specific variables
   terraform plan \
     -var-file="../../shared/common.tfvars" \
     -var-file="terraform.tfvars"
   ```

   Pay special attention to:
   - Customer-managed key encryption configurations
   - Required sovereign cloud tags
   - Network security configurations
   - Private endpoint configurations

5. **Apply the Configuration**:
   ```bash
   # Apply using both common and environment-specific variables
   terraform apply \
     -var-file="../../shared/common.tfvars" \
     -var-file="terraform.tfvars"
   ```

Note: The workspace name should match your environment (dev, stg, or prd). If you get an error about the workspace not existing, use `terraform workspace new <env>` to create it first.

### 5. Post-Deployment

1. Verify the deployment:
   - Check resource group creation
   - Verify network configuration
   - Test AKS cluster access
   - Validate ACR connectivity
   - Test Key Vault access
   - Verify customer-managed key encryption

2. Configure kubectl:
   ```bash
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   ```

3. Verify AKS integration:
   ```bash
   kubectl get nodes
   ```

4. Verify customer-managed key encryption:
   ```bash
   # Check storage account encryption
   az storage account show --name <storage_account_name> --resource-group <resource_group> --query encryption
   
   # Check Key Vault encryption
   az keyvault show --name <key_vault_name> --resource-group <resource_group> --query properties.enableSoftDelete
   
   # Check AKS disk encryption
   az aks show --resource-group <resource_group> --name <cluster_name> --query agentPoolProfiles[0].enableEncryptionAtHost
   ```

5. Verify sovereign compliance:
   - Check that all resources have the required tags
   - Verify private endpoints are configured where required
   - Ensure network security groups have appropriate rules

## Security Considerations

1. Network Security:
   - All services use private endpoints
   - Network rules deny public access
   - Service endpoints enabled
   - Network policies enabled in AKS
   - Default deny rules with explicit allow rules

2. Access Control:
   - RBAC enabled in AKS
   - Key Vault access policies configured
   - ACR network rules set
   - Managed identities used
   - Workload Identity enabled

3. Encryption:
   - Customer-managed keys for all encryption
   - Key rotation policies implemented
   - Audit logging enabled
   - Key backup procedures in place

4. Monitoring:
   - Log Analytics integration
   - Diagnostic settings enabled
   - Audit logs configured
   - Metrics collection active

5. Sovereign Compliance:
   - Required tags applied to all resources
   - Customer-managed key encryption enabled
   - Private endpoints configured
   - Network security rules implemented

## Troubleshooting

### Common Initialization Issues

1. **Backend Configuration Warnings**:
   - Ensure you're running `terraform init` from the environment directory
   - Verify that backend.tf exists in the environment directory
   - Check that backend.hcl contains the correct values
   - Make sure the storage account and container exist
   - Verify customer-managed key encryption is properly configured

2. **Provider Configuration Warnings**:
   - These warnings about empty provider blocks can be ignored
   - They're related to the module structure and don't affect functionality
   - The providers are properly configured in the environment's backend.tf

3. **Lock File**:
   - Always commit .terraform.lock.hcl to version control
   - This ensures consistent provider versions across team members

4. **Customer-Managed Key Errors**:
   - Verify the Key Vault exists and is accessible
   - Check that the managed identity has the correct permissions on the Key Vault
   - Ensure the encryption key exists and is accessible
   - Verify the key URI format is correct
   - **Key Vault RBAC**: If Key Vault uses RBAC (`enable_rbac_authorization = true`), ensure disk encryption set has "Key Vault Crypto Service Encryption User" role assignment (not access policy)
   - **Network ACLs**: Ensure AKS subnet is included in Key Vault network ACLs (`allowed_subnet_ids`) for disk encryption operations
   - **Disk Encryption Enabled**: Verify Key Vault has `enabled_for_disk_encryption = true` set

5. **Sovereign Compliance Issues**:
   - Ensure all required tags are included in the `tags` variable
   - Verify customer-managed key encryption is properly configured
   - Check that private endpoints are configured where required

1. Common Issues:
   - Private endpoint DNS resolution
   - Network connectivity
   - RBAC permissions
   - Resource naming conflicts
   - Customer-managed key access

2. Resolution Steps:
   - Check DNS configuration
   - Verify network rules
   - Review access policies
   - Check resource naming
   - Verify key access permissions

## Maintenance

1. Regular Tasks:
   - Review and update tags
   - Monitor resource usage
   - Check security settings
   - Update module versions
   - Rotate customer-managed keys
   - Audit compliance status

2. Backup and Recovery:
   - Key Vault backup
   - ACR image replication
   - State file backup
   - Recovery procedures
   - Key backup and recovery

## Additional Resources

- [Azure Documentation](https://docs.microsoft.com/azure)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [ACR Documentation](https://docs.microsoft.com/azure/container-registry)
- [Key Vault Documentation](https://docs.microsoft.com/azure/key-vault)
- [Customer-Managed Keys](https://docs.microsoft.com/azure/storage/common/customer-managed-keys-overview)
- [UAE Sovereign Cloud](https://docs.microsoft.com/azure/azure-government/) 