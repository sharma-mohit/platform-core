# Environment specific variables
project         = "platform-core"
environment     = "ops"
location        = "uaenorth"

# Azure specific values
subscription_id = "b139cf36-b4d2-4653-bab0-6d98354a68ef"
tenant_id       = "909b0a4b-54de-4250-b223-b55c49dabac7"

# Terraform state configuration
terraform_state_storage_account_name = "sttfstateplatformcore"
terraform_state_resource_group_name = "rg-tfstate-platformcore-shared-uaen-001"

# Override any common variables if needed
# network = {
#   vnet_address_space = ["10.0.0.0/16"]
#   subnets = {
#     aks = {
#       address_prefixes = ["10.0.0.0/20"]
#       service_endpoints = ["Microsoft.KeyVault", "Microsoft.ContainerRegistry", "Microsoft.Storage"]
#     }
#     acr = {
#       address_prefixes = ["10.0.16.0/24"]
#       service_endpoints = ["Microsoft.ContainerRegistry"]
#     }
#     keyvault = {
#       address_prefixes = ["10.0.17.0/24"]
#       service_endpoints = ["Microsoft.KeyVault"]
#     }
#   }
# }

# Override AKS configuration if needed
aks = {
  kubernetes_version = "1.30.4"
  system_node_pool = {
    name            = "system"
    node_count      = 1
    vm_size         = "Standard_D2s_v3"
    os_disk_size_gb = 100
    min_count       = 1
    max_count       = 2
  }
  user_node_pool = null
}

tags = {
  Project     = "platform-core"
  ManagedBy   = "terraform"
  Environment = "ops"
  Owner       = "platform-team"
  CostCenter  = "ai-platform"
  createdBy    = "mohit.sharma"
  projectName  = "platform-core"
  workLoadName = "ops"
} 