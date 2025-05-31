# Phase 1: Terraform Azure Infrastructure - Execution Guide

This document provides step-by-step instructions for provisioning the Azure infrastructure using the Terraform configurations defined for the AI Platform.

**Prerequisite**: Ensure you have reviewed the [Phase 1 Terraform Architecture Guide](./phase1-terraform-architecture.md) to understand the design and components.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Install Azure CLI and Terraform](#2-install-azure-cli-and-terraform)
  - [3. Azure Login and Subscription](#3-azure-login-and-subscription)
- [Terraform Backend Setup](#terraform-backend-setup)
  - [1. Understand Backend Configuration](#1-understand-backend-configuration)
  - [2. Create Storage Account for Terraform State (One-Time)](#2-create-storage-account-for-terraform-state-one-time)
  - [3. Update `backend.hcl` for your Environment](#3-update-backendhcl-for-your-environment)
- [Provisioning an Environment (e.g., `dev-uaenorth`)](#provisioning-an-environment-eg-dev-uaenorth)
  - [1. Navigate to Environment Directory](#1-navigate-to-environment-directory)
  - [2. Review and Customize `terraform.tfvars`](#2-review-and-customize-terraformtfvars)
  - [3. Initialize Terraform](#3-initialize-terraform)
  - [4. Validate Configuration](#4-validate-configuration)
  - [5. Plan Deployment](#5-plan-deployment)
  - [6. Apply Deployment](#6-apply-deployment)
- [Verifying Deployment](#verifying-deployment)
- [Making Changes](#making-changes)
- [Destroying an Environment](#destroying-an-environment)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Prerequisites

- Azure Subscription with necessary permissions to create resources (Contributor role is typically sufficient at the subscription or a management group level).
- Git installed.
- Azure CLI installed and configured.
- Terraform CLI (latest stable version recommended) installed.

## Initial Setup

### 1. Clone the Repository
If you haven't already, clone the `platform-core` repository to your local machine:
```bash
git clone <repository_url>
cd platform-core
```

### 2. Install Azure CLI and Terraform
- **Azure CLI**: Follow instructions at [Microsoft Docs](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Terraform**: Follow instructions at [HashiCorp Learn](https://learn.hashicorp.com/tutorials/terraform/install-cli)

### 3. Azure Login and Subscription
Log in to Azure and set the correct subscription:
```bash
az login
az account list --output table
az account set --subscription "<Your-Subscription-ID-or-Name>"
```

## Terraform Backend Setup

The Terraform state is stored in an Azure Storage Account. This setup needs to be done once for the storage account, and then configured per environment.

### 1. Understand Backend Configuration
- The backend configuration template is in `terraform/shared/backend.tf`.
- Each environment (e.g., `terraform/envs/dev-uaenorth/`) has a `backend.hcl` file that provides specific values for that environment's state file.

### 2. Create Storage Account for Terraform State (One-Time)
This step is typically performed manually or with a separate, minimal Terraform script once per project.

**Example using Azure CLI:**
```bash
# Variables (adjust as needed)
RESOURCE_GROUP_NAME="rg-tfstate-platformcore-shared-uaen-001" # Central RG for TF state
STORAGE_ACCOUNT_NAME="sttfstateplatformcore$(openssl rand -hex 4)" # Needs to be globally unique
LOCATION="uaenorth"
CONTAINER_NAME_PREFIX="tfstate"

# Create Resource Group
az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"

# Create Storage Account
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --allow-blob-public-access false

# Optional: Enable versioning and soft delete for recovery
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 7

# Output storage account name for use in backend.hcl
echo "Terraform State Storage Account: ${STORAGE_ACCOUNT_NAME}"
```

**Note**: You will also need to create containers within this storage account for each environment. This can be done manually or the `terraform init` command might offer to create it if it doesn't exist (depending on permissions).
Example: `tfstate-dev-uaenorth`, `tfstate-stg-uaecentral`.

### 3. Update `backend.hcl` for your Environment
For each environment you intend to deploy, update its `backend.hcl` file.
Example for `terraform/envs/dev-uaenorth/backend.hcl`:

```hcl
storage_account_name = "<your_terraform_state_storage_account_name>" # e.g., sttfstateplatformcorexxxx
container_name       = "tfstate-dev-uaenorth"                          # Unique container per environment
key                  = "dev-uaenorth.terraform.tfstate"                # State file name for this env
resource_group_name  = "<resource_group_of_storage_account>"       # e.g., rg-tfstate-platformcore-shared-uaen-001
```

## Provisioning an Environment (e.g., `dev-uaenorth`)

### 1. Navigate to Environment Directory
```bash
cd terraform/envs/dev-uaenorth
```

### 2. Review and Customize `terraform.tfvars`
Open `terraform.tfvars` in this directory. This file contains the specific values for the variables defined in `terraform/shared/variables.tf` and `terraform/envs/dev-uaenorth/variables.tf`.

Key variables to review/customize:
- `project_name`
- `environment`
- `location`
- `tags`
- AKS node pool configurations (`system_node_pool`, `user_node_pool`)
- VNet address spaces
- Specific SKUs for services if defaults are not suitable.

Refer to `terraform/shared/common.tfvars` for common defaults that might be overridden here.

### 3. Initialize Terraform
This command downloads necessary providers and configures the backend.
```bash
terraform init -backend-config=./backend.hcl
```
If you encounter issues with provider registration (especially in restricted environments), ensure `skip_provider_registration = true` is set in the `azurerm` provider block in `terraform/shared/backend.tf` (or relevant provider configuration files).

### 4. Validate Configuration
Check for syntax errors and internal consistency.
```bash
terraform validate
```

### 5. Plan Deployment
Generates an execution plan. Review the planned changes carefully.
```bash
terraform plan -out=tfplan
```
This shows what Terraform will create, modify, or delete.

### 6. Apply Deployment
Applies the changes to your Azure subscription.
```bash
terraform apply tfplan
```
Terraform will ask for confirmation before proceeding unless you used `terraform apply -auto-approve tfplan` (not recommended for initial deployments).

This process can take a significant amount of time, especially for the initial AKS cluster provisioning.

## Verifying Deployment

Once `terraform apply` completes:
- **Check Terraform Outputs**: Note any outputs from the `apply` command (e.g., AKS cluster name, Key Vault URI).
- **Azure Portal**: Log in to the Azure portal and verify that the resources have been created as expected in the correct resource groups and locations.
- **AKS Cluster**: Get credentials for your new AKS cluster:
  ```bash
  # Get the AKS cluster name and resource group from Terraform outputs or Azure portal
  AKS_RG_NAME=$(terraform output -raw aks_cluster_resource_group_name)
  AKS_CLUSTER_NAME=$(terraform output -raw aks_cluster_name)

  az aks get-credentials --resource-group "${AKS_RG_NAME}" --name "${AKS_CLUSTER_NAME}" --overwrite-existing
  kubectl get nodes
  ```
- **Other Services**: Check ACR, Key Vault, etc., for their status and configuration.

## Making Changes

1.  Modify your `.tf` or `.tfvars` files in the environment directory (`terraform/envs/<environment_name>/`) or in the shared/module directories if making a global change.
2.  Navigate to the environment directory: `cd terraform/envs/<environment_name>/`.
3.  Run `terraform plan -out=tfplan` to see the impact of your changes.
4.  Run `terraform apply tfplan` to apply the changes.

## Destroying an Environment

To remove all resources managed by Terraform for a specific environment:

**Warning**: This action is irreversible and will delete all resources defined in the Terraform configuration for that environment.

1.  Navigate to the environment directory: `cd terraform/envs/<environment_name>/`.
2.  Ensure your `backend.hcl` and `terraform.tfvars` are correctly configured for the environment you wish to destroy.
3.  Initialize Terraform if you haven't already in this session for this directory: `terraform init -backend-config=./backend.hcl`
4.  Run the destroy command:
    ```bash
    terraform plan -destroy -out=tfdestroyplan
    terraform apply tfdestroyplan
    ```
    Or, directly (will prompt for confirmation):
    ```bash
    terraform destroy
    ```

## Troubleshooting Common Issues

- **Authentication Errors**: Ensure `az login` was successful and the correct subscription is selected. Check if your user/service principal has sufficient permissions.
- **Provider Registration Errors**: If you see errors about resource providers not being registered, you might need to register them manually in your subscription (`az provider register --namespace Microsoft.ContainerService`). The `skip_provider_registration = true` setting in the provider block can help bypass CLI attempts to register if the user lacks permission but the provider is already registered.
- **State Lock Errors**: If a previous Terraform command failed or was interrupted, the state might be locked. Terraform usually provides instructions to force-unlock if necessary, but this should be done with caution.
- **Resource Naming Conflicts**: Ensure resource names, which are often constructed, do not conflict with existing resources if you are not managing them with Terraform or if state is misaligned.
- **Quota Limits**: You might hit Azure service quotas (e.g., vCPU limits per region). Check your subscription quotas in the Azure portal.
- **Changes Outside Terraform**: If resources are changed manually in the Azure portal, Terraform might not be aware. Run `terraform plan` to see discrepancies. `terraform import` can be used to bring existing resources under Terraform management if needed, but this is an advanced operation. 