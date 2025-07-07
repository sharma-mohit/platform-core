variable "project" {
  description = "The project name"
  type        = string
}

variable "environment" {
  description = "The environment (dev, stg, prd, ops)"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the disk encryption set will be created"
  type        = string
}

variable "key_vault_id" {
  description = "The ID of the Azure Key Vault where the encryption key will be stored"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
} 