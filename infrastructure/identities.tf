resource "azurerm_user_assigned_identity" "foundry_identity" {
  name                = "${local.ai_foundry_name}-identity"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}