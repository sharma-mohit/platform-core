variable "environment" {
  description = "The environment (dev, stg, prd)"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
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

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

variable "vnet_id" {
  description = "The ID of the Virtual Network"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the Key Vault private endpoint"
  type        = string
}

variable "aks_identity_id" {
  description = "The ID of the AKS cluster's managed identity"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace for diagnostics"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access the Key Vault"
  type        = list(string)
  default     = []
}

variable "resource_group_name" {
  description = "The name of the resource group where the Key Vault will be created"
  type        = string
} 