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
  resource_group_name = "rg-keyvault-${local.environment}-${local.location}-001"  # Use existing resource group
  
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
  system_node_pool = var.aks.system_node_pool
  user_node_pool   = var.aks.user_node_pool

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

# Resource group for observability components
resource "azurerm_resource_group" "observability" {
  name     = "rg-observability-${var.environment}-${var.location_short}-001"
  location = var.location
  tags     = var.tags
} 