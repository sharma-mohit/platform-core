module "observability_central" {
  source = "../../modules/observability-central"

  resource_group_name = azurerm_resource_group.observability.name
  location            = var.location
  central_cluster_name = module.aks.cluster_name
  key_vault_id        = module.keyvault.key_vault_id
  
  mimir_storage_account_name = "stmimirobs${var.environment}${var.location_short}001"
  loki_storage_account_name  = "stlokiobs${var.environment}${var.location_short}001"
  tempo_storage_account_name = "sttempoobs${var.environment}${var.location_short}001"
  
  tags = var.tags
} 