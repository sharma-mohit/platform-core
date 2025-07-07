resource "azurerm_storage_container" "loki" {
  name                  = "loki"
  storage_account_name  = azurerm_storage_account.loki.name
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "loki_storage_key" {
  name         = "${var.central_cluster_name}-loki-storage-key"
  value        = azurerm_storage_account.loki.primary_access_key
  key_vault_id = var.key_vault_id
  tags         = var.tags
}
