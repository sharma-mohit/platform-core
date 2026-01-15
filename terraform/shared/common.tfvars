# Common variables shared across all environments
# These values should be reviewed and updated according to your organization's requirements

# Project and Organization
project     = "platform-core"
organization = "inception"

# Common Tags
tags = {
  Project     = "platform-core"
  ManagedBy   = "terraform"
  Environment = "common"  # This will be overridden by environment-specific tfvars
}

# Network Configuration
network = {
  vnet_address_space = ["10.0.0.0/16"]
  subnets = {
    aks = {
      address_prefixes = ["10.0.0.0/20"]
      service_endpoints = [
        "Microsoft.KeyVault",
        "Microsoft.ContainerRegistry",
        "Microsoft.Storage"
      ]
    }
    acr = {
      address_prefixes = ["10.0.16.0/24"]
      service_endpoints = ["Microsoft.ContainerRegistry"]
    }
    keyvault = {
      address_prefixes = ["10.0.17.0/24"]
      service_endpoints = ["Microsoft.KeyVault"]
    }
  }
}

# AKS Configuration
aks = {
  kubernetes_version = "1.34.1"
  system_node_pool = {
    name            = "system"
    node_count      = 2
    vm_size         = "Standard_D4s_v3"
    os_disk_size_gb = 100
    min_count       = 2
    max_count       = 4
  }
  user_node_pool = {
    name            = "user"
    node_count      = 2
    vm_size         = "Standard_D4s_v3"
    os_disk_size_gb = 100
    min_count       = 2
    max_count       = 4
    gpu_enabled     = false
  }
}

# ACR Configuration
acr = {
  sku = "Premium"  # Required for geo-replication and private endpoint
  geo_replications = [
    {
      location = "uaecentral"
      zone_redundancy_enabled = true
    }
  ]
}

# Key Vault Configuration
keyvault = {
  sku = "Premium"  # Required for private endpoint
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

# Log Analytics Configuration
log_analytics = {
  retention_in_days = 30
  sku              = "PerGB2018"
}

# Security Configuration
security = {
  enable_private_cluster = true
  enable_network_policy  = true
  enable_rbac           = true
  enable_defender       = true
} 