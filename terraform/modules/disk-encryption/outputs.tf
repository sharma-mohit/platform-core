output "disk_encryption_set_id" {
  description = "The ID of the disk encryption set."
  value       = azurerm_disk_encryption_set.main.id
}

output "disk_encryption_set_access_policy_id" {
  description = "The ID of the Key Vault role assignment for the disk encryption set (used for dependency tracking)."
  value       = azurerm_role_assignment.disk_encryption_set.id
} 