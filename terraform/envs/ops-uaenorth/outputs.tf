output "central_key_vault_id" {
  description = "The ID of the Key Vault in the central ops cluster."
  value       = module.observability_central.central_key_vault_id
} 