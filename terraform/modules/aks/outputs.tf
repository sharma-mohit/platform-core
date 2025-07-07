output "cluster_id" {
  description = "The Kubernetes Managed Cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
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

output "kubelet_identity_object_id" {
  description = "The Object ID of the User Assigned Identity used for the AKS cluster kubelet identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
} 