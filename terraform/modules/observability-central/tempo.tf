resource "azurerm_storage_container" "tempo" {
  name                  = "tempo"
  storage_account_name  = azurerm_storage_account.tempo.name
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "tempo_storage_key" {
  name         = "${var.central_cluster_name}-tempo-storage-key"
  value        = azurerm_storage_account.tempo.primary_access_key
  key_vault_id = var.key_vault_id
  tags         = var.tags
}
