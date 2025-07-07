resource "azurerm_storage_container" "mimir" {
  name                  = "mimir"
  storage_account_name  = azurerm_storage_account.mimir.name
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "mimir_storage_key" {
  name         = "${var.central_cluster_name}-mimir-storage-key"
  value        = azurerm_storage_account.mimir.primary_access_key
  key_vault_id = var.key_vault_id
  tags         = var.tags
}
