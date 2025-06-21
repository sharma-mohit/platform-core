terraform {
  required_version = ">= 1.0.0"
}

# Set environment-specific variables
locals {
  environment = var.environment
  location    = var.location
  
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Environment = local.environment
    }
  )
}

# Network Module
module "network" {
  source = "../../modules/network"

  environment = local.environment
  location    = local.location
  project     = var.project
  tags        = local.common_tags
}

# AKS Module
module "aks" {
  source = "../../modules/aks"

  environment = local.environment
  location    = local.location
  project     = var.project
  tags        = local.common_tags
  
  # Network configuration
  subnet_id   = module.network.aks_subnet_id # AKS nodes will reside in this subnet
  
  # Node pool configuration
  system_node_pool = var.aks.system_node_pool
  user_node_pool   = var.aks.user_node_pool
  keyvault_id = module.keyvault.key_vault_id
}

# ACR Module
module "acr" {
  source = "../../modules/acr"

  environment = local.environment
  location    = local.location
  project     = var.project
  tags        = local.common_tags
  
  # Network configuration
  vnet_id         = module.network.vnet_id
  subnet_id       = module.network.acr_subnet_id
  aks_identity_id = module.aks.cluster_identity_id
}

# Key Vault Module
module "keyvault" {
  source = "../../modules/keyvault"

  environment = local.environment
  location    = local.location
  project     = var.project
  tags        = local.common_tags
  tenant_id   = var.tenant_id
  
  # Network configuration
  vnet_id         = module.network.vnet_id
  subnet_id       = module.network.keyvault_subnet_id
  
  # Access configuration
  aks_identity_id            = module.aks.cluster_identity_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id
} 

# Resource group for observability components
resource "azurerm_resource_group" "observability" {
  name     = "rg-observability-${var.environment}-${var.location_short}-001"
  location = var.location
  tags     = var.tags
} 