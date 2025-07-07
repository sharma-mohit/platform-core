# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Create Key Vault key for disk encryption
resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "${var.project}-${var.environment}-disk-encryption-key"
  key_vault_id = var.key_vault_id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}

# Create Disk Encryption Set
resource "azurerm_disk_encryption_set" "main" {
  name                = "${var.project}-${var.environment}-aks-des"
  resource_group_name = var.resource_group_name
  location            = var.location
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption.id
  encryption_type     = "EncryptionAtRestWithPlatformAndCustomerKeys"  # Double encryption

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Disk Encryption Set access to Key Vault
resource "azurerm_key_vault_access_policy" "disk_encryption_set" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_disk_encryption_set.main.identity[0].principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey"
  ]
} 