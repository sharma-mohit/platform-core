# Common variables
variable "project" {
  description = "The project name"
  type        = string
}

variable "organization" {
  description = "The organization name"
  type        = string
  default     = "your-org" # Default value, can be overridden
}

variable "environment" {
  description = "The environment (dev, stg, prd)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "uaenorth"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

# Azure specific variables
variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
}

# Network variables
variable "network" {
  description = "Network configuration"
  type = object({
    vnet_address_space = list(string)
    subnets = map(object({
      address_prefixes  = list(string)
      service_endpoints = list(string)
    }))
  })
  default = null
}

# AKS variables
variable "aks" {
  description = "AKS configuration"
  type = object({
    kubernetes_version = string
    system_node_pool = object({
      name            = string
      node_count      = number
      vm_size         = string
      os_disk_size_gb = number
      min_count       = number
      max_count       = number
    })
    user_node_pool = object({
      name            = string
      node_count      = number
      vm_size         = string
      os_disk_size_gb = number
      min_count       = number
      max_count       = number
      gpu_enabled     = bool
    })
  })
  default = null
}

# ACR variables
variable "acr" {
  description = "ACR configuration"
  type = object({
    sku = string
    geo_replications = list(object({
      location                  = string
      zone_redundancy_enabled   = bool
    }))
  })
  default = null
}

# Key Vault variables
variable "keyvault" {
  description = "Key Vault configuration"
  type = object({
    sku                        = string
    soft_delete_retention_days = number
    purge_protection_enabled   = bool
  })
  default = null
}

# Log Analytics variables
variable "log_analytics" {
  description = "Log Analytics configuration"
  type = object({
    retention_in_days = number
    sku              = string
  })
  default = null
}

# Security variables
variable "security" {
  description = "Security configuration"
  type = object({
    enable_private_cluster = bool
    enable_network_policy  = bool
    enable_rbac           = bool
    enable_defender       = bool
  })
  default = null
} 