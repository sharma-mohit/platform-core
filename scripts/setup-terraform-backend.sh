#!/bin/bash

# Exit on error
set -e

# Variables for shared Terraform state storage
RESOURCE_GROUP="rg-tfstate-platformcore-shared-uaen-001"
STORAGE_ACCOUNT="platformcoretfstate"
CONTAINER_NAME="tfstate"
LOCATION="uaenorth"
KEY_VAULT_NAME="kv-tfstate-shared-001"
KEY_VAULT_URI="https://$KEY_VAULT_NAME.vault.azure.net/"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "Please login to Azure first using 'az login'"
    exit 1
fi

echo "Setting up shared Terraform backend storage..."

# Create shared resource group if it doesn't exist
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "Creating shared resource group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location $LOCATION --tags createdBy="platform-core" environment="shared" project="platform-core" region="uaenorth" costCenter="platform-team" owner="platform-team"
fi

# Create Key Vault for customer-managed keys if it doesn't exist
if ! az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "Creating Key Vault $KEY_VAULT_NAME for customer-managed keys..."
    az keyvault create \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku standard \
        --enable-purge-protection true \
        --enable-rbac-authorization true
else
    echo "Key Vault $KEY_VAULT_NAME already exists."
fi

# Get current user object ID for Key Vault access
CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant current user Key Vault Administrator role
echo "Granting Key Vault Administrator role to current user..."
az role assignment create \
    --assignee $CURRENT_USER_OBJECT_ID \
    --role "Key Vault Administrator" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --output none 2>/dev/null || echo "Role assignment may already exist."

# Create storage account encryption key in Key Vault
echo "Creating storage account encryption key in Key Vault..."
az keyvault key create \
    --vault-name $KEY_VAULT_NAME \
    --name "storage-encryption-key" \
    --kty RSA \
    --size 2048 \
    --output none 2>/dev/null || echo "Key may already exist."

# Get the key URI (only if key creation was successful)
echo "Retrieving key URI..."
KEY_URI=$(az keyvault key show --vault-name $KEY_VAULT_NAME --name "storage-encryption-key" --query key.kid -o tsv 2>/dev/null)

if [ -z "$KEY_URI" ]; then
    echo "ERROR: Failed to retrieve key URI. Please check if the key was created successfully."
    echo "You can manually create the key using:"
    echo "  az keyvault key create --vault-name $KEY_VAULT_NAME --name 'storage-encryption-key' --kty RSA --size 2048"
    exit 1
fi

echo "Key URI retrieved: $KEY_URI"

# Create user-assigned managed identity for storage account
USER_ASSIGNED_IDENTITY_NAME="id-storage-shared-001"
echo "Creating user-assigned managed identity for storage account..."
az identity create \
    --name $USER_ASSIGNED_IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --output none 2>/dev/null || echo "User-assigned identity may already exist."

# Get the user-assigned identity principal ID and resource ID
USER_ASSIGNED_IDENTITY_PRINCIPAL_ID=$(az identity show \
    --name $USER_ASSIGNED_IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query principalId -o tsv)

USER_ASSIGNED_IDENTITY_ID=$(az identity show \
    --name $USER_ASSIGNED_IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query id -o tsv)

# Grant Key Vault permissions to the user-assigned managed identity using RBAC
echo "Granting 'Key Vault Crypto User' role to the user-assigned managed identity..."
az role assignment create \
    --assignee $USER_ASSIGNED_IDENTITY_PRINCIPAL_ID \
    --role "Key Vault Crypto User" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --output none 2>/dev/null || echo "Role assignment for user-assigned identity may already exist."

# Wait a moment for role assignment to propagate
echo "Waiting for 30 seconds for role assignment to propagate..."
sleep 30

# Create storage account with user-assigned managed identity for CMK encryption
if ! az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "Creating storage account $STORAGE_ACCOUNT with user-assigned managed identity and CMK encryption..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku "Standard_LRS" \
        --encryption-services "blob" \
        --allow-blob-public-access "false" \
        --min-tls-version "TLS1_2" \
        --identity-type "UserAssigned" \
        --user-identity-id "$USER_ASSIGNED_IDENTITY_ID" \
        --encryption-key-source "Microsoft.Keyvault" \
        --encryption-key-vault "$KEY_VAULT_URI" \
        --encryption-key-name "storage-encryption-key" \
        --key-vault-user-identity-id "$USER_ASSIGNED_IDENTITY_ID"
else
    echo "Storage account $STORAGE_ACCOUNT already exists."
fi

# Enable versioning and soft delete for recovery
echo "Enabling versioning and soft delete for storage account..."
az storage account blob-service-properties update \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 7

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query '[0].value' \
    --output tsv)

# Create containers for each environment
echo "Creating containers for each environment..."

# Dev environment container
DEV_CONTAINER="tfstate-dev-uaenorth"
if ! az storage container show --name $DEV_CONTAINER --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY &> /dev/null; then
    echo "Creating container $DEV_CONTAINER..."
    az storage container create \
        --name $DEV_CONTAINER \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY
else
    echo "Container $DEV_CONTAINER already exists."
fi

# Ops environment container
OPS_CONTAINER="tfstate-ops-uaenorth"
if ! az storage container show --name $OPS_CONTAINER --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY &> /dev/null; then
    echo "Creating container $OPS_CONTAINER..."
    az storage container create \
        --name $OPS_CONTAINER \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY
else
    echo "Container $OPS_CONTAINER already exists."
fi

# Staging environment container (for future use)
STG_CONTAINER="tfstate-stg-uaenorth"
if ! az storage container show --name $STG_CONTAINER --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY &> /dev/null; then
    echo "Creating container $STG_CONTAINER..."
    az storage container create \
        --name $STG_CONTAINER \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY
else
    echo "Container $STG_CONTAINER already exists."
fi

# Production environment container (for future use)
PRD_CONTAINER="tfstate-prd-uaenorth"
if ! az storage container show --name $PRD_CONTAINER --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY &> /dev/null; then
    echo "Creating container $PRD_CONTAINER..."
    az storage container create \
        --name $PRD_CONTAINER \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY
else
    echo "Container $PRD_CONTAINER already exists."
fi

echo ""
echo "✅ Shared Terraform backend storage setup complete!"
echo "📦 Storage Account: $STORAGE_ACCOUNT"
echo "🏗️  Resource Group: $RESOURCE_GROUP"
echo "🔐 Key Vault: $KEY_VAULT_NAME"
echo "📍 Location: $LOCATION"
echo ""
echo "📁 Created containers:"
echo "   - $DEV_CONTAINER (for dev-uaenorth)"
echo "   - $OPS_CONTAINER (for ops-uaenorth)"
echo "   - $STG_CONTAINER (for stg-uaenorth)"
echo "   - $PRD_CONTAINER (for prd-uaenorth)"
echo ""
echo "📝 Backend configurations for each environment:"
echo ""
echo "For dev-uaenorth (terraform/envs/dev-uaenorth/backend.hcl):"
echo "   storage_account_name = \"$STORAGE_ACCOUNT\""
echo "   container_name       = \"$DEV_CONTAINER\""
echo "   key                  = \"platform-core-dev.tfstate\""
echo "   resource_group_name  = \"$RESOURCE_GROUP\""
echo ""
echo "For ops-uaenorth (terraform/envs/ops-uaenorth/backend.hcl):"
echo "   storage_account_name = \"$STORAGE_ACCOUNT\""
echo "   container_name       = \"$OPS_CONTAINER\""
echo "   key                  = \"platform-core-ops.tfstate\""
echo "   resource_group_name  = \"$RESOURCE_GROUP\""
echo ""
echo "🚀 You can now run:"
echo "   cd terraform/envs/dev-uaenorth"
echo "   terraform init -backend-config=backend.hcl"
echo ""
echo "   cd terraform/envs/ops-uaenorth"
echo "   terraform init -backend-config=backend.hcl" 