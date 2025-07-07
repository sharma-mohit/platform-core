output "mimir_storage_account_id" {
  description = "The ID of the Mimir storage account."
  value       = azurerm_storage_account.mimir.id
}

output "loki_storage_account_id" {
  description = "The ID of the Loki storage account."
  value       = azurerm_storage_account.loki.id
}

output "tempo_storage_account_id" {
  description = "The ID of the Tempo storage account."
  value       = azurerm_storage_account.tempo.id
}

output "central_key_vault_id" {
  description = "The ID of the Key Vault in the central ops cluster."
  value       = azurerm_key_vault.observability_kv.id
}
