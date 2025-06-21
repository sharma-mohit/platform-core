resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project}-${var.environment}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.project}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  oidc_issuer_enabled      = true
  workload_identity_enabled = true

  default_node_pool {
    name                = var.system_node_pool.name
    node_count          = var.system_node_pool.node_count
    vm_size             = var.system_node_pool.vm_size
    os_disk_size_gb     = var.system_node_pool.os_disk_size_gb
    vnet_subnet_id      = var.subnet_id
    #enable_auto_scaling = true
    #min_count           = var.system_node_pool.min_count
    #max_count           = var.system_node_pool.max_count
    max_pods            = 110
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    dns_service_ip     = "10.2.0.10"
    service_cidr       = "10.2.0.0/16"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
  }

  # Microsoft Defender for Containers - Updated syntax
  azure_policy_enabled = true
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.user_node_pool != null ? 1 : 0
  name                  = var.user_node_pool.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_node_pool.vm_size
  node_count            = var.user_node_pool.node_count
  os_disk_size_gb       = var.user_node_pool.os_disk_size_gb
  vnet_subnet_id        = var.subnet_id
  enable_auto_scaling   = var.user_node_pool.enable_auto_scaling
  min_count             = var.user_node_pool.enable_auto_scaling ? var.user_node_pool.min_count : null
  max_count             = var.user_node_pool.enable_auto_scaling ? var.user_node_pool.max_count : null
  max_pods              = 110
  tags                  = var.tags

  node_taints = var.user_node_pool.gpu_enabled ? ["nvidia.com/gpu=true:NoSchedule"] : []

  node_labels = merge(
    var.user_node_pool.gpu_enabled ? {
      "accelerator" = "nvidia"
    } : {},
    var.user_node_pool.node_labels
  )
}

resource "azurerm_resource_group" "rg" {
  name     = format(var.resource_group_name_pattern, var.environment, var.location)
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "${var.project}-${var.environment}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Role assignment for AKS to access Key Vault
resource "azurerm_role_assignment" "aks_keyvault" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
} 