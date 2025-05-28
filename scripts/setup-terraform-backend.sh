#!/bin/bash

# Exit on error
set -e

# Variables
RESOURCE_GROUP="rg-sbox-iai-aen-001"
STORAGE_ACCOUNT="platformcoretfstate"
CONTAINER_NAME="tfstate"
LOCATION="uaenorth"

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

echo "Setting up Terraform backend storage..."

# Create resource group if it doesn't exist
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo "Creating resource group $RESOURCE_GROUP..."
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

# Create storage account if it doesn't exist
if ! az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo "Creating storage account $STORAGE_ACCOUNT..."
    az storage account create \
        --name $STORAGE_ACCOUNT \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --sku Standard_LRS \
        --encryption-services blob \
        --allow-blob-public-access false \
        --min-tls-version TLS1_2
fi

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query '[0].value' \
    --output tsv)

# Create container if it doesn't exist
if ! az storage container show --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY &> /dev/null; then
    echo "Creating container $CONTAINER_NAME..."
    az storage container create \
        --name $CONTAINER_NAME \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY
fi

echo "Terraform backend storage setup complete!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "You can now initialize Terraform with the backend configuration." 