#!/bin/bash

# Week 1 Prerequisites Validation Script
# This script validates all prerequisites for Phase 2 Week 1 implementation

set -e

DEBUG_MODE=false
# Check for debug flag
if [[ "$1" == "-d" || "$1" == "--debug" ]]; then
    DEBUG_MODE=true
    # Use existing YELLOW color for consistency, ensure NC (No Color) is defined or use literal escape codes
    YELLOW='\\033[1;33m'
    NC='\\033[0m' # No Color
    echo -e "${YELLOW}⚠️  Debug mode enabled. Script will print commands as they are executed.${NC}"
    set -x
    shift # Remove the debug flag from the list of arguments
fi

echo "🔍 Validating Week 1 Prerequisites for Phase 2 Implementation"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo ""
echo "1. Checking CLI Tools..."
echo "------------------------"

# Check FluxCD CLI
if command -v flux &> /dev/null; then
    FLUX_VERSION=$(flux --version)
    print_status 0 "FluxCD CLI installed: $FLUX_VERSION"
else
    print_status 1 "FluxCD CLI not found. Install with: curl -s https://fluxcd.io/install.sh | sudo bash"
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n 1)     
    print_status 0 "kubectl installed: $KUBECTL_VERSION"
else
    print_status 1 "kubectl not found"
fi

# Check Azure CLI
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
    print_status 0 "Azure CLI installed: $AZ_VERSION"
else
    print_status 1 "Azure CLI not found"
fi

# Check kustomize
if command -v kustomize &> /dev/null; then
    KUSTOMIZE_VERSION=$(kustomize version 2>/dev/null)
    print_status 0 "Kustomize installed: $KUSTOMIZE_VERSION"
else
    print_status 1 "Kustomize not found. Install with: brew install kustomize"
fi

echo ""
echo "2. Checking Azure Authentication..."
echo "-----------------------------------"

# Check Azure login
if az account show &> /dev/null; then
    ACCOUNT=$(az account show --query 'name' -o tsv)
    print_status 0 "Azure authenticated: $ACCOUNT"
else
    print_warning "Not authenticated to Azure. Attempting az login..."
    az login
    if az account show &> /dev/null; then
        ACCOUNT=$(az account show --query 'name' -o tsv)
        print_status 0 "Azure authenticated: $ACCOUNT"
    else
        print_status 1 "Azure login failed. Please check your credentials."
    fi
fi

# List available subscriptions and prompt user to select one
SUBSCRIPTIONS=$(az account list --query '[].{name:name, id:id}' -o tsv)
SUB_COUNT=$(echo "$SUBSCRIPTIONS" | wc -l | tr -d ' ')
if [ "$SUB_COUNT" -gt 1 ]; then
    echo "\nAvailable Azure subscriptions:"
    i=1
    while IFS=$'\t' read -r name id; do
        echo "$i) $name ($id)"
        SUB_NAMES[$i]="$name"
        SUB_IDS[$i]="$id"
        i=$((i+1))
    done <<< "$SUBSCRIPTIONS"
    echo -n "Select a subscription by number: "
    read -r SUB_CHOICE
    CHOSEN_ID=${SUB_IDS[$SUB_CHOICE]}
    if [ -n "$CHOSEN_ID" ]; then
        az account set --subscription "$CHOSEN_ID"
        print_status 0 "Azure subscription set: ${SUB_NAMES[$SUB_CHOICE]} ($CHOSEN_ID)"
    else
        print_status 1 "Invalid subscription selection."
    fi
fi

echo ""
echo "3. Checking AKS Cluster Access..."
echo "---------------------------------"

# Define environments
# ENVIRONMENTS=("dev" "stg" "prd")
ENVIRONMENTS=("dev")

for ENV in "${ENVIRONMENTS[@]}"; do
    echo "Checking $ENV environment..."
    
    # Check if AKS cluster exists and is accessible
    CLUSTER_NAME="platform-core-$ENV-aks" # platform-core-dev-aks
    RG_NAME="rg-aks-$ENV-uaenorth-001"
    
    if az aks show --name $CLUSTER_NAME --resource-group $RG_NAME &> /dev/null; then
        print_status 0 "AKS cluster exists: $CLUSTER_NAME"
        
        # Try to get credentials
        if az aks get-credentials --name $CLUSTER_NAME --resource-group $RG_NAME --overwrite-existing &> /dev/null; then
            print_status 0 "AKS credentials obtained for $ENV"
            
            # Test kubectl connectivity
            if kubectl get nodes --context $CLUSTER_NAME &> /dev/null; then
                NODE_COUNT=$(kubectl get nodes --context $CLUSTER_NAME --no-headers | wc -l)
                print_status 0 "kubectl connectivity verified: $NODE_COUNT nodes"
            else
                print_status 1 "kubectl connectivity failed for $ENV"
            fi
        else
            print_status 1 "Failed to get AKS credentials for $ENV"
        fi
    else
        print_status 1 "AKS cluster not found: $CLUSTER_NAME"
    fi
done

echo ""
echo "4. Checking Azure Container Registry..."
echo "--------------------------------------"

for ENV in "${ENVIRONMENTS[@]}"; do
    ACR_NAME="platformcore${ENV}acr" #platformcoredevacr
    RG_NAME="rg-acr-$ENV-uaenorth-001"
    
    if az acr show --resource-group $RG_NAME --name $ACR_NAME &> /dev/null; then
        print_status 0 "ACR exists: $ACR_NAME"
        
        # # Test ACR login
        # if az acr login --resource-group $RG_NAME --name $ACR_NAME &> /dev/null; then
        #     print_status 0 "ACR login successful for $ENV"
        # else
        #     print_warning "ACR login failed for $ENV (may need admin enabled)"
        # fi
    else
        print_status 1 "ACR not found: $ACR_NAME"
    fi
done

echo ""
echo "5. Checking Azure Key Vault..."
echo "------------------------------"

for ENV in "${ENVIRONMENTS[@]}"; do
    KV_NAME="platform-core-$ENV-kv"
    RG_NAME="rg-keyvault-$ENV-uaenorth-001" #rg-keyvault-dev-uaenorth-001
    
    if az keyvault show --name $KV_NAME --resource-group $RG_NAME &> /dev/null; then
        print_status 0 "Key Vault exists: $KV_NAME"
        
        # # Test Key Vault access
        # if az keyvault secret list --vault-name $KV_NAME &> /dev/null; then
        #     print_status 0 "Key Vault access verified for $ENV"
        # else
        #     print_status 1 "Key Vault access denied for $ENV"
        # fi
    else
        print_status 1 "Key Vault not found: $KV_NAME"
    fi
done

echo ""
echo "6. Checking SSH Keys for GitHub..."
echo "----------------------------------"

# Check if common SSH key files exist
SSH_KEYS_FOUND=0
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
  print_status 0 "Standard SSH key (id_rsa or id_ed25519) found."
  SSH_KEYS_FOUND=1
else
  print_warning "No standard SSH key (id_rsa or id_ed25519) found in ~/.ssh/. Manual check needed if using custom key."
fi

if [ -f "$FLUX_PRIVATE_KEY_FILE" ]; then
    print_status 0 "FluxCD private key ($FLUX_PRIVATE_KEY_FILE) found."
    SSH_KEYS_FOUND=1
else
    print_warning "FluxCD private key ($FLUX_PRIVATE_KEY_FILE) NOT found. This will be needed for Flux bootstrap."
fi

if [ $SSH_KEYS_FOUND -eq 0 ]; then
    OVERALL_STATUS=1
fi

echo ""
echo "7. Checking Network Connectivity..."
echo "-----------------------------------"

# Test GitHub connectivity
if curl -s --connect-timeout 5 https://github.com > /dev/null; then
  print_status 0 "GitHub connectivity verified"
else
  print_status 1 "Cannot reach GitHub"
  OVERALL_STATUS=1
fi

# Test Azure Portal connectivity
if curl -s --connect-timeout 5 https://portal.azure.com > /dev/null; then
  print_status 0 "Azure Portal connectivity verified"
else
  print_status 1 "Cannot reach Azure Portal"
  OVERALL_STATUS=1
fi

echo ""
echo "8. Checking Environment Variables..."
echo "---------------------------------"

# Check for GITHUB_TOKEN (optional, but good for API operations)
if [ -z "$GITHUB_TOKEN" ]; then
  print_warning "GITHUB_TOKEN not set (may be needed for some GitHub API operations/scripts)"
else
  print_status 0 "GITHUB_TOKEN is set"
fi

echo ""
echo "=============================================================="
echo "🎯 Prerequisites Validation Complete!"
echo ""
echo "Next Steps:"
echo "1. Fix any ❌ issues above"
echo "2. Address any ⚠️  warnings if needed"
echo "3. Proceed with Week 1 Day 1-2: FluxCD Bootstrap"
echo ""
echo "Ready to start Week 1 implementation? 🚀"
echo "==============================================================" 