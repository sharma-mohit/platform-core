resource "random_password" "grafana_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&"
}

resource "azurerm_key_vault_secret" "grafana_admin_password" {
  name         = "${var.central_cluster_name}-grafana-admin-password"
  value        = random_password.grafana_admin.result
  key_vault_id = var.key_vault_id
  tags         = var.tags
}
