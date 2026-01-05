resource "azapi_resource" "content_understanding" {
  count     = var.deploy_content_understanding ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name      = local.content_understanding_name
  location  = local.content_understanding_location
  parent_id = azurerm_resource_group.this.id

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.foundry_identity.id
    ]
  }

  body = {
    sku = {
      name = "S0"
    },
    kind = "AIServices",
    properties = {
      allowProjectManagement = true
      customSubDomainName    = local.content_understanding_name
      publicNetworkAccess    = "Enabled"
    }
  }
}

data "azurerm_cognitive_account" "content_understanding" {
  depends_on          = [azapi_resource.content_understanding]
  name                = local.content_understanding_name
  resource_group_name = azurerm_resource_group.this.name
}
