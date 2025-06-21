output "cluster_id" {
  description = "The Kubernetes Managed Cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  description = "The Kubernetes Managed Cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_identity_id" {
  description = "The ID of the User Assigned Identity used for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "kube_config" {
  description = "The Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kube_config_host" {
  description = "The Kubernetes cluster server host"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.rg.id
}

output "kubelet_identity_object_id" {
  description = "The Object ID of the User Assigned Identity used for the AKS cluster kubelet identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
} 