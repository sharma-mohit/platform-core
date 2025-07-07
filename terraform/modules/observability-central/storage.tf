# Create Key Vault for customer-managed keys
resource "azurerm_key_vault" "observability_kv" {
  name                        = "${var.project_name}-obs-kv"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization   = true

  tags = var.tags
}

# Grant current user Key Vault Administrator role
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.observability_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Create storage account encryption key in Key Vault
resource "azurerm_key_vault_key" "storage_encryption_key" {
  name         = "observability-storage-encryption-key"
  key_vault_id = azurerm_key_vault.observability_kv.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]

  depends_on = [azurerm_role_assignment.kv_admin]
}

# Create user-assigned managed identity for storage accounts
resource "azurerm_user_assigned_identity" "storage_identity" {
  name                = "id-${var.project_name}-obs"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Grant Key Vault permissions to the user-assigned managed identity
resource "azurerm_role_assignment" "storage_identity_kv" {
  scope                = azurerm_key_vault.observability_kv.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.storage_identity.principal_id

  depends_on = [azurerm_key_vault.observability_kv]
}

resource "azurerm_storage_account" "mimir" {
  name                     = var.mimir_storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_identity.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage_encryption_key.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage_identity.id
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.storage_identity_kv]
}

resource "azurerm_storage_account" "loki" {
  name                     = var.loki_storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_identity.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage_encryption_key.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage_identity.id
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.storage_identity_kv]
}

resource "azurerm_storage_account" "tempo" {
  name                     = var.tempo_storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage_identity.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage_encryption_key.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage_identity.id
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.storage_identity_kv]
}
