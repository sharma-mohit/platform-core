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

variable "vnet_id" {
  description = "The ID of the Virtual Network"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the ACR private endpoint"
  type        = string
}

variable "resource_group_name_pattern" {
  description = "The pattern for the resource group name. Will be formatted with environment and location"
  type        = string
  default     = "rg-acr-%s-%s-001"  # Will be formatted with environment and location
}

variable "aks_identity_id" {
  description = "The ID of the AKS cluster's managed identity"
  type        = string
  default     = null
} 