variable "environment" {
  description = "The environment (dev, stg, prd)"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
}

variable "disk_encryption_set_access_policy_id" {
  description = "The ID of the Key Vault access policy for the disk encryption set. Used to establish a dependency."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "The name of the resource group where AKS resources will be created"
  type        = string
}

variable "project" {
  description = "The project name"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34.1"
}

variable "subnet_id" {
  description = "The subnet ID for the AKS cluster"
  type        = string
}


variable "disk_encryption_set_id" {
  description = "The ID of the disk encryption set for customer-managed key encryption"
  type        = string
  default     = null
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    name            = string
    node_count      = number
    vm_size         = string
    os_disk_size_gb = number
    min_count       = number
    max_count       = number
  })
}

variable "user_node_pool" {
  description = "User node pool configuration"
  type = object({
    name                = string
    node_count          = number
    vm_size             = string
    os_disk_size_gb     = number
    enable_auto_scaling = bool
    min_count           = number
    max_count           = number
    gpu_enabled         = bool
    node_labels         = map(string)
  })
  default = {
    name                = "user"
    node_count          = 1
    vm_size             = "Standard_D4s_v3"
    os_disk_size_gb     = 100
    enable_auto_scaling = false
    min_count           = 1
    max_count           = 3
    gpu_enabled         = false
    node_labels         = {}
  }
}

variable "resource_group_name_pattern" {
  description = "The pattern for the resource group name. Will be formatted with environment and location"
  type        = string
  default     = "rg-aks-%s-%s-001" # Will be formatted with environment and location
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace."
  type        = string
}