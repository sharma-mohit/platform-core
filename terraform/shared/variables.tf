variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "uaenorth"
}

variable "environment" {
  description = "The environment (dev, stg, prd)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd"
  }
}

variable "project" {
  description = "The project name"
  type        = string
  default     = "platform-core"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "platform-core"
    ManagedBy   = "terraform"
    Environment = "dev" # This will be overridden per environment
  }
}

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "The Azure tenant ID"
  type        = string
} 