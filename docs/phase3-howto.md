# Phase 3: Observability Stack Foundation - How-To Guide

This guide provides the step-by-step instructions to deploy the foundational infrastructure for the centralized observability stack as outlined in the `WEEK3-OBSERVABILITY-PLAN.md`. This phase involves provisioning Azure resources via Terraform for the central operations cluster (`ops`) and configuring the development workload cluster (`dev`) to communicate with it.

**For the overall observability architecture, refer to [./WEEK3-OBSERVABILITY-PLAN.md](./WEEK3-OBSERVABILITY-PLAN.md).**

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Overview](#deployment-overview)
- [Step 1: Setup Terraform State for Ops Cluster](#step-1-setup-terraform-state-for-ops-cluster)
- [Step 2: Provision the Central Operations (`ops`) Cluster Infrastructure](#step-2-provision-the-central-operations-ops-cluster-infrastructure)
- [Step 3: Provision the Workload (`dev`) Cluster Agent Infrastructure](#step-3-provision-the-workload-dev-cluster-agent-infrastructure)
- [Step 4: Bootstrap the `ops` Cluster with FluxCD](#step-4-bootstrap-the-ops-cluster-with-fluxcd)
- [Step 5: Verify FluxCD Synchronization](#step-5-verify-fluxcd-synchronization)
- [Step 6: Deploy Observability Components via FluxCD](#step-6-deploy-observability-components-via-fluxcd)
- [Troubleshooting](#troubleshooting)

## Prerequisites

1.  **Phase 1 & 2 Completed**: The core Azure infrastructure (from Phase 1) and the GitOps bootstrap for the `dev` cluster (from Phase 2) must be complete.
2.  **Azure CLI & `kubectl` Access**: Configured for your Azure subscription and existing AKS clusters.
3.  **FluxCD CLI Installed**: ([Install Guide](https://fluxcd.io/flux/installation/))
4.  **GitHub Monorepo**: Your `flux-config` and `terraform` code must be pushed to your GitHub repository.
5.  **SSH Key for Flux**: The SSH private key used for FluxCD bootstrap must be available.

## Deployment Overview

This phase is deployed in three parts:

1.  **Terraform State Setup**: Create the storage account and container for the `ops` cluster's Terraform state.
2.  **`ops-uaenorth` Environment**: Apply Terraform configurations to create a new AKS cluster dedicated to central observability tools (Mimir, Loki, Tempo, etc.). This also creates the necessary storage accounts.
3.  **`dev-uaenorth` Environment**: Apply Terraform changes to the existing `dev` cluster to grant it permissions to access the central Key Vault.

**IMPORTANT**: 
- You must complete each step in order, as the `dev` deployment depends on the `ops` deployment's output.
- This guide uses **Terraform workspaces** to isolate state between environments. Each environment (`ops`, `dev`) will use its own workspace within the same backend storage account.

**Terraform Workspace Benefits**:
- **State Isolation**: Each environment maintains separate state files
- **Resource Separation**: Prevents accidental cross-environment modifications
- **Simplified Management**: Use the same backend configuration across environments
- **Environment Safety**: Reduces risk of applying changes to wrong environment

## Step 1: Setup Terraform State for Ops Cluster

Before deploying the ops cluster, we need to create the Terraform state storage infrastructure. This follows the same pattern as Phase 1.

### 1.1 Create Storage Account for Ops Terraform State

**Option A: Using the automated script (Recommended)**

```bash
# Run the ops cluster backend setup script
./scripts/setup-ops-terraform-backend.sh
```

This script will:
- Create the resource group `rg-tfstate-ops-001`
- Create the storage account `platformcoretfstateops`
- Enable versioning and soft delete for recovery
- Create the `tfstate` container
- Display the backend configuration details

**Option B: Manual setup (if you prefer)**

```bash
# Variables for ops cluster state storage
RESOURCE_GROUP_NAME="rg-tfstate-ops-001"
STORAGE_ACCOUNT_NAME="platformcoretfstateops"  # Must be globally unique
LOCATION="uaenorth"
CONTAINER_NAME="tfstate"
KEY_VAULT_NAME="kv-tfstate-ops-001"

# Create Resource Group
az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"

# Create Key Vault for customer-managed keys (required by UAE Cloud Sovereign Policies)
az keyvault create \
  --name "${KEY_VAULT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku standard \
  --enable-purge-protection true \
  --enable-rbac-authorization true

# Grant current user Key Vault Administrator role
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --assignee "${CURRENT_USER_OBJECT_ID}" \
  --role "Key Vault Administrator" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}"

# Create storage account encryption key in Key Vault
az keyvault key create \
  --vault-name "${KEY_VAULT_NAME}" \
  --name "storage-encryption-key" \
  --kty RSA \
  --size 2048

# Get the key URI
KEY_URI=$(az keyvault key show --vault-name "${KEY_VAULT_NAME}" --name "storage-encryption-key" --query key.kid -o tsv)

# Verify key was retrieved successfully
if [ -z "${KEY_URI}" ]; then
    echo "ERROR: Failed to retrieve key URI. Please check if the key was created successfully."
    exit 1
fi

echo "Key URI: ${KEY_URI}"

# Create user-assigned managed identity for storage account
USER_ASSIGNED_IDENTITY_NAME="id-storage-ops-001"
az identity create \
  --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}"

# Get the user-assigned identity principal ID
USER_ASSIGNED_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --query principalId -o tsv)

# Grant Key Vault permissions to the user-assigned managed identity
az role assignment create \
  --assignee "${USER_ASSIGNED_IDENTITY_PRINCIPAL_ID}" \
  --role "Key Vault Crypto User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}"

# Get the user-assigned identity resource ID
USER_ASSIGNED_IDENTITY_ID=$(az identity show \
  --name "${USER_ASSIGNED_IDENTITY_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --query id -o tsv)

# Create Storage Account with user-assigned managed identity for CMK encryption
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --allow-blob-public-access false \
  --identity-type "UserAssigned" \
  --user-identity-id "${USER_ASSIGNED_IDENTITY_ID}" \
  --encryption-key-source Microsoft.Keyvault \
  --encryption-key-vault "${KEY_URI}" \
  --encryption-key-name "storage-encryption-key" \
  --key-vault-user-identity-id "${USER_ASSIGNED_IDENTITY_ID}"

# Enable versioning and soft delete for recovery
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 7

# Create container for terraform state
az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}"

echo "Terraform State Storage Account: ${STORAGE_ACCOUNT_NAME}"
echo "Resource Group: ${RESOURCE_GROUP_NAME}"
echo "Container: ${CONTAINER_NAME}"
echo "Key Vault: ${KEY_VAULT_NAME}"
```

### 1.2 Verify Backend Configuration

The backend configuration is already set up in `terraform/envs/ops-uaenorth/backend.hcl`:

```hcl
storage_account_name = "platformcoretfstateops"
container_name       = "tfstate"
key                  = "platform-core-ops.tfstate"
resource_group_name  = "rg-tfstate-ops-001"
```

## Step 2: Provision the Central Operations (`ops`) Cluster Infrastructure

This step creates the `ops-uaenorth` AKS cluster and all its dependencies, including the storage accounts for the LGTM stack.

### 2.1 Navigate to the `ops` environment directory

```bash
cd terraform/envs/ops-uaenorth
```

### 2.2 Initialize Terraform

This command configures the backend to use the correct state file for the `ops` environment.

```bash
terraform init -backend-config=backend.hcl
```

### 2.3 Create and Select Terraform Workspace

Create and select the `ops` workspace to isolate the state for this environment.

```bash
# List existing workspaces
terraform workspace list

# Create a new workspace for ops environment
terraform workspace new ops

# Select the ops workspace (if it already exists)
terraform workspace select ops

# Verify you're in the correct workspace
terraform workspace show
```

### 2.4 Review Configuration

The `terraform.tfvars` file is already configured for the ops environment:

- **Environment**: `ops`
- **Location**: `uaenorth`
- **AKS Configuration**: Single system node pool (no user node pool needed for ops cluster)
- **Storage Accounts**: Will be created for Mimir, Loki, and Tempo

### 2.5 Plan the Deployment

Review the plan to see what resources will be created. You should see:
- New AKS cluster (`platform-core-ops-aks`)
- New resource group for observability (`rg-observability-ops-uaen-001`)
- Three new storage accounts for Mimir, Loki, and Tempo
- Network infrastructure (VNet, subnets, NSGs)
- Azure Container Registry
- Key Vault

```bash
terraform plan -out=tfplan
```

### 2.6 Apply the Configuration

This will start the provisioning of the `ops` cluster. This step will take some time.

```bash
terraform apply tfplan
```

### 2.7 Verify the Deployment

After the deployment completes, verify the resources were created:

```bash
# Check AKS cluster
az aks show --resource-group "rg-aks-ops-uaenorth-001" --name "platform-core-ops-aks"

# Check storage accounts
az storage account list --resource-group "rg-observability-ops-uaen-001" --output table

# Check Key Vault
az keyvault show --name "platform-core-ops-kv" --resource-group "rg-aks-ops-uaenorth-001"
```

## Step 3: Provision the Workload (`dev`) Cluster Agent Infrastructure

This step updates the `dev-uaenorth` environment to grant it permissions to the central Key Vault created in the `ops` environment.

### 3.1 Navigate to the `dev` environment directory

```bash
cd ../dev-uaenorth
```

### 3.2 Initialize Terraform

Re-initialize Terraform for the `dev` environment.

```bash
terraform init -backend-config=backend.hcl
```

### 3.3 Create and Select Terraform Workspace

Create and select the `dev` workspace to isolate the state for this environment.

```bash
# List existing workspaces
terraform workspace list

# Create a new workspace for dev environment (if it doesn't exist)
terraform workspace new dev

# Select the dev workspace (if it already exists)
terraform workspace select dev

# Verify you're in the correct workspace
terraform workspace show
```

### 3.4 Plan the Deployment

Review the plan. It should show the creation of a new `azurerm_key_vault_access_policy`. The plan will read remote state from the `ops` environment to get the Key Vault ID.

```bash
terraform plan -out=tfplan
```

### 3.5 Apply the Configuration

```bash
terraform apply tfplan
```

## Step 4: Bootstrap the `ops` Cluster with FluxCD

Now that the `ops-uaenorth` AKS cluster exists, we need to bootstrap it with FluxCD so it can start managing itself from the Git repository.

### 4.1 Get `ops` Cluster Credentials

Configure `kubectl` to point to your newly created `ops` cluster.

```bash
# Get the resource group and cluster name from Terraform output
OPS_AKS_RG=$(terraform -chdir="../../envs/ops-uaenorth" output -raw aks_cluster_resource_group_name)
OPS_AKS_NAME=$(terraform -chdir="../../envs/ops-uaenorth" output -raw aks_cluster_name)

az aks get-credentials --resource-group "${OPS_AKS_RG}" --name "${OPS_AKS_NAME}" --overwrite-existing
```

### 4.2 Run Flux Bootstrap

This command is similar to the one used for the `dev` cluster, but with the `--path` argument pointing to the `ops` cluster's configuration directory.

```bash
# --- Replace these placeholders ---
GITHUB_OWNER="YOUR_GITHUB_ORG"
GITHUB_REPO="YOUR_REPO_NAME"
FLUX_SSH_PRIVATE_KEY_FILE="~/.ssh/flux_github_deploy_key" # The same key used for dev
# ---

flux bootstrap github \
  --owner="${GITHUB_OWNER}" \
  --repository="${GITHUB_REPO}" \
  --branch=main \
  --path="./clusters/platform-core-ops-aks/flux-system" \
  --private-key-file="${FLUX_SSH_PRIVATE_KEY_FILE}" \
  --personal # Use if GITHUB_OWNER is your personal GitHub account, omit for an organization
```

## Step 5: Verify FluxCD Synchronization

### 5.1 Check the `ops` cluster

Ensure `kubectl` is still configured for the `ops` cluster.

```bash
flux get kustomizations --all-namespaces
```

You should see the `flux-system` kustomization, and it should eventually reconcile. It will then start reconciling the `infrastructure` kustomization, which in turn includes `observability`, and all the components underneath (mimir, loki, etc.).

### 5.2 Check the `dev` cluster

Switch your `kubectl` context back to the `dev` cluster.

```bash
az aks get-credentials --resource-group YOUR_DEV_AKS_RESOURCE_GROUP --name YOUR_DEV_AKS_CLUSTER_NAME --overwrite-existing
```

The `infrastructure` kustomization should have been updated automatically by Flux to include the new `observability` components.

```bash
flux get kustomizations --all-namespaces
```

Look for the `infra-observability` kustomization (or similar name based on your structure) and verify it's reconciled.

## Step 6: Deploy Observability Components via FluxCD

With the clusters bootstrapped and the foundational Terraform resources applied, FluxCD will now automatically deploy the observability stack based on the `HelmRelease` manifests we've added to the `flux-config` directory.

The deployment happens automatically as FluxCD syncs with your Git repository. The following steps are for verification.

### 6.1 Verify Central Stack Deployment (`ops` cluster)

Ensure your `kubectl` context is pointing to the `ops` cluster.

#### Check Namespaces

Verify the namespaces for the central components have been created.

```bash
kubectl get ns | grep observability
# EXPECTED OUTPUT:
# observability-grafana        Active   ...
# observability-loki           Active   ...
# observability-mimir          Active   ...
# observability-tempo          Active   ...
```

#### Check HelmReleases

Verify that FluxCD is deploying the Helm charts.

```bash
flux get helmreleases --all-namespaces
```

You should see releases for `grafana`, `loki`, `mimir`, and `tempo`. Wait for them to become `Ready`.

#### Check Pods

Once the HelmReleases are ready, check that the pods are running.

```bash
kubectl get pods -n observability-grafana
kubectl get pods -n observability-loki
kubectl get pods -n observability-mimir
kubectl get pods -n observability-tempo
```

### 6.2 Verify Agent Deployment (`dev` cluster)

Switch your `kubectl` context to the `dev` cluster.

#### Check Namespaces

```bash
kubectl get ns | grep observability-agent
# EXPECTED OUTPUT:
# observability-agent-prometheus   Active   ...
# observability-agent-promtail     Active   ...
```

#### Check HelmReleases

```bash
flux get helmreleases --all-namespaces
```

You should see releases for `prometheus-agent` and `promtail`.

#### Check Pods

```bash
kubectl get pods -n observability-agent-prometheus
kubectl get pods -n observability-agent-promtail
```

### 6.3 Verify Connectivity (Important)

The agents in the `dev` cluster need to be able to communicate with the services in the `ops` cluster. This relies on:

- **VNet Peering**: Assumed to be configured by the Terraform `network` module between the `dev` and `ops` VNets.
- **Internal DNS**: The service hostnames (e.g., `mimir.platform-core.internal`, `loki-gateway.observability-loki.svc.cluster.local`) must be resolvable from the `dev` cluster pods. This may require setting up a Private DNS Zone in Azure and linking it to both VNets.

#### Check Prometheus Agent Logs

```bash
kubectl logs -n observability-agent-prometheus -l app.kubernetes.io/name=prometheus -f
```

Look for successful "remote write" messages. Errors about "server returned HTTP status 400 Bad Request" or DNS resolution failures indicate a connectivity or configuration problem.

## Troubleshooting

### Terraform State Issues

- **Remote State Access Error on `dev` plan**: If `terraform plan` for the `dev` environment fails with an error about accessing the remote state, ensure that:
    - You have successfully run `terraform apply` on the `ops-uaenorth` environment first.
    - The `backend.hcl` configuration in `terraform/envs/dev-uaenorth/main.tf` (the `data "terraform_remote_state"` block) points to the correct storage container and key for the `ops` state file.
    - You have permissions to read the storage account where the `ops` state is stored.
    - You are using the correct Terraform workspace for each environment (`ops` for ops-uaenorth, `dev` for dev-uaenorth).

- **Workspace Issues**: If you encounter state-related errors:
    - Verify you're in the correct workspace with `terraform workspace show`
    - List available workspaces with `terraform workspace list`
    - Switch to the correct workspace with `terraform workspace select <workspace-name>`
    - Each environment should use its own workspace to maintain isolated state

### Flux Bootstrap Issues

- **Flux Bootstrap Fails**:
    - Verify your GitHub PAT (`GITHUB_TOKEN`) is correct and has `repo` scope if you are using it.
    - Ensure the public part of your SSH key (`--private-key-file`) has been added as a Deploy Key to your GitHub repository with read access.
    - Check that the `--path` argument correctly points to an existing directory in your Git repository.

### Agent Connectivity Issues

If agents in the `dev` cluster cannot reach services in the `ops` cluster:

- **DNS Resolution**: From a pod in the `dev` cluster, try to resolve the `ops` service hostname: `kubectl exec -it <some-pod-in-dev> -- nslookup mimir.platform-core.internal`. If it fails, your cross-cluster DNS is not set up correctly. This often requires an Azure Private DNS Zone.

- **Network Peering**: Ensure VNet peering is active and configured correctly between the two environments' virtual networks in Azure.

- **NSG Rules**: Check the Network Security Group rules for both the `ops` ingress subnet and the `dev` agent subnets to ensure traffic is allowed on the required ports (e.g., 80, 443).

---

Following these steps will result in a fully deployed central observability stack on the `ops` cluster and the necessary collection agents on your `dev` workload cluster, all managed via GitOps.
