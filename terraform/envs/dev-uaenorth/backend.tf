terraform {
  backend "azurerm" {
    # These values will be populated by the -backend-config arguments
    # during terraform init
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Disable automatic resource provider registration to avoid connection issues
  # You may need to manually register required providers if they're not already registered
  skip_provider_registration = true
}

# Configure the Azure AD Provider
provider "azuread" {
  # Configuration options
}

# Configure the Kubernetes Provider
provider "kubernetes" {
  # Configuration will be populated by AKS module outputs
}

# Configure the Helm Provider
provider "helm" {
  # Configuration will be populated by AKS module outputs
} 