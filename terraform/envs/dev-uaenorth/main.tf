terraform {
  required_version = ">= 1.0.0"
}

# Import shared configuration
module "shared" {
  source = "../../shared"

  environment     = local.environment
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Set environment-specific variables
locals {
  environment = "dev"
  location    = "uaenorth"
  
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
  system_node_pool = {
    name            = "system"
    node_count      = 2
    vm_size         = "Standard_D4s_v3"
    os_disk_size_gb = 100
    min_count       = 1
    max_count       = 3
  }
  
  user_node_pool = {
    name                  = "user"
    node_count            = 1
    vm_size               = "Standard_D4s_v3"
    os_disk_size_gb       = 100
    enable_auto_scaling = false
    gpu_enabled           = false
    min_count             = 0
    max_count             = 2
    node_labels           = {}
  }
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