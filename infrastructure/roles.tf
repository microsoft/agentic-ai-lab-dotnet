resource "azurerm_role_assignment" "ai_services_user" {
  scope                            = azapi_resource.foundry.id
  role_definition_name             = "Cognitive Services OpenAI User"
  principal_id                     = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "storage_owner" {
  scope                            = azurerm_storage_account.this.id
  role_definition_name             = "Storage Blob Data Owner"
  principal_id                     = data.azurerm_client_config.current.object_id
  depends_on                      = [azurerm_storage_account.this]
}

resource "azurerm_role_assignment" "storage_contributor_msi" {
  scope                            = azurerm_storage_account.this.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.foundry_identity.principal_id
  depends_on                      = [azurerm_storage_account.this]
}