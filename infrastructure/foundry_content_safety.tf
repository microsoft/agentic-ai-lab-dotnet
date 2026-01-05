resource "azurerm_cognitive_account" "content_safety" {
  name                  = local.content_safety_name
  resource_group_name   = azurerm_resource_group.this.name
  location              = local.location
  custom_subdomain_name = local.content_safety_name
  kind                  = "ContentSafety"

  sku_name = "S0"
  identity {
    type = "SystemAssigned"
  }
}

