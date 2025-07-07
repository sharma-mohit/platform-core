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

# Create resource group for AKS
resource "azurerm_resource_group" "aks" {
  name     = "rg-aks-${local.environment}-${local.location}-001"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.project}-${local.environment}-law"
  location            = local.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Network Module
module "network" {
  source = "../../modules/network"

  environment = local.environment
  location    = local.location
  project     = var.project
  tags        = local.common_tags
}

# Key Vault Module
module "keyvault" {
  source = "../../modules/keyvault"

  environment         = local.environment
  location            = local.location
  project             = var.project
  tags                = local.common_tags
  tenant_id           = var.tenant_id
  resource_group_name = azurerm_resource_group.aks.name
  
  # Network configuration
  vnet_id         = module.network.vnet_id
  subnet_id       = module.network.keyvault_subnet_id
  
  # Access configuration
  aks_identity_id            = "00000000-0000-0000-0000-000000000000"  # Placeholder, will be set via role assignment
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  
  # Allow current client IP for terraform operations
  allowed_ip_ranges = var.allowed_ip_ranges
}

# Disk Encryption Module for customer-managed keys (required by Azure policies)
module "disk_encryption" {
  source = "../../modules/disk-encryption"

  environment         = local.environment
  location            = local.location
  project             = var.project
  tags                = local.common_tags
  resource_group_name = azurerm_resource_group.aks.name
  key_vault_id        = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

# AKS Module
module "aks" {
  source = "../../modules/aks"

  environment                   = local.environment
  location                      = local.location
  project                       = var.project
  tags                          = local.common_tags
  resource_group_name           = azurerm_resource_group.aks.name
  log_analytics_workspace_id    = azurerm_log_analytics_workspace.aks.id
  
  # Network configuration
  subnet_id   = module.network.aks_subnet_id # AKS nodes will reside in this subnet
  
  # Disk encryption configuration (required by Azure policies)
  disk_encryption_set_id = module.disk_encryption.disk_encryption_set_id
  disk_encryption_set_access_policy_id = module.disk_encryption.disk_encryption_set_access_policy_id
  
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
    min_count             = 1
    max_count             = 5
    enable_auto_scaling   = false
    gpu_enabled           = false
    node_labels           = {}
  }

  depends_on = [module.disk_encryption]
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
}

# Role assignments (created after modules to avoid circular dependencies)

# Grant AKS cluster identity access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.acr_id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.cluster_identity_id
}

# Grant AKS cluster identity access to Key Vault
resource "azurerm_role_assignment" "aks_kv_secrets" {
  scope                = module.keyvault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.cluster_identity_id
}

# Get outputs from ops environment for observability
data "terraform_remote_state" "ops" {
  backend = "azurerm"
  
  config = {
    storage_account_name = var.terraform_state_storage_account_name
    container_name       = "tfstate"
    key                  = "ops-uaenorth.terraform.tfstate"
    resource_group_name  = var.terraform_state_resource_group_name
  }
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = module.aks.aks_cluster_name
}

output "aks_cluster_resource_group_name" {
  description = "The name of the resource group containing the AKS cluster."
  value       = azurerm_resource_group.aks.name
} 