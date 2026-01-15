resource "azurerm_container_registry" "acr" {
  name                = replace("${var.project}${var.environment}acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false
  tags                = var.tags

  network_rule_set {
    default_action = "Deny"
  }

  #georeplications {
  #  location = "uaecentral"
  #  zone_redundancy_enabled = true
  #  tags                     = var.tags
  #}
}

resource "azurerm_private_endpoint" "acr" {
  name                = "${var.project}-${var.environment}-acr-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.project}-${var.environment}-acr-psc"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "${var.project}-${var.environment}-acr-dnslink"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}

resource "azurerm_resource_group" "rg" {
  name     = format(var.resource_group_name_pattern, var.environment, var.location)
  location = var.location
  tags     = var.tags
}

 