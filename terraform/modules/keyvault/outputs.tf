output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.kv.id
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = var.resource_group_name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

output "private_endpoint_ip" {
  description = "The private IP address of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address
} 