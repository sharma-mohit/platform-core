variable "resource_group_name" {
  description = "The name of the resource group in which to create the resources."
  type        = string
}

variable "location" {
  description = "The Azure region where the resources will be created."
  type        = string
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, stg, prd, ops)."
  type        = string
}

variable "central_cluster_name" {
  description = "The name of the central operations AKS cluster."
  type        = string
}

variable "key_vault_id" {
  description = "The ID of the Azure Key Vault to store secrets in."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}

variable "mimir_storage_account_name" {
  description = "The name of the storage account for Mimir."
  type        = string
}

variable "loki_storage_account_name" {
  description = "The name of the storage account for Loki."
  type        = string
}

variable "tempo_storage_account_name" {
  description = "The name of the storage account for Tempo."
  type        = string
}
