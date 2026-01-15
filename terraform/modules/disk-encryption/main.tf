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
  encryption_type     = "EncryptionAtRestWithPlatformAndCustomerKeys" # Double encryption

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Disk Encryption Set access to Key Vault using RBAC
# When Key Vault has RBAC enabled, we must use role assignments instead of access policies
resource "azurerm_role_assignment" "disk_encryption_set" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.main.identity[0].principal_id
} 