output "disk_encryption_set_id" {
  description = "The ID of the disk encryption set."
  value       = azurerm_disk_encryption_set.main.id
}

output "disk_encryption_set_access_policy_id" {
  description = "The ID of the Key Vault access policy for the disk encryption set."
  value       = azurerm_key_vault_access_policy.disk_encryption_set.id
} 