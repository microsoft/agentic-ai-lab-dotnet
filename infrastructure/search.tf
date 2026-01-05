resource "azapi_resource" "ai_search" {
  type                      = "Microsoft.Search/searchServices@2025-05-01"
  name                      = local.search_service_name
  parent_id                 = azurerm_resource_group.this.id
  location                  = azurerm_resource_group.this.location
  schema_validation_enabled = true

  body = {
    sku = {
      name = "standard"
    }

    identity = {
      type = "SystemAssigned"
    }

    properties = {
      replicaCount     = 1
      partitionCount   = 1
      hostingMode      = "default"
      semanticSearch   = "standard"
      disableLocalAuth = false
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }
    }
  }

  response_export_values = ["properties.endpoint"]
}

data "azapi_resource_action" "search_keys" {
  type                   = "Microsoft.Search/searchServices@2025-05-01"
  resource_id            = azapi_resource.ai_search.id
  action                 = "listAdminKeys"
  method                 = "POST"
  response_export_values = ["*"]
  depends_on             = [azapi_resource.ai_search]
}
