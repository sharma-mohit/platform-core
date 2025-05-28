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

variable "resource_group_name_pattern" {
  description = "The pattern for the resource group name. Will be formatted with environment and location"
  type        = string
  default     = "rg-network-%s-%s-001"  # Will be formatted with environment and location
} 