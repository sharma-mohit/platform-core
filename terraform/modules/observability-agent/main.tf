terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "agent_access" {
  key_vault_id = var.central_key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.workload_cluster_identity_principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}
