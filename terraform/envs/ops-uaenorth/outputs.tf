output "central_key_vault_id" {
  description = "The ID of the Key Vault in the central ops cluster."
  value       = module.observability_central.central_key_vault_id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = module.aks.aks_cluster_name
}

output "aks_cluster_resource_group_name" {
  description = "The resource group of the AKS cluster."
  value       = azurerm_resource_group.aks.name
} 