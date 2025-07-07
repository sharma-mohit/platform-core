variable "workload_cluster_identity_principal_id" {
  description = "The principal ID of the workload cluster's managed identity (e.g., kubelet identity)."
  type        = string
}

variable "central_key_vault_id" {
  description = "The ID of the central Key Vault."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, stg, prd)."
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {}
}
