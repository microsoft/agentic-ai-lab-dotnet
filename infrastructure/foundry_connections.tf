resource "azapi_resource" "ai_search_connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name      = local.ai_search_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "CognitiveSearch"
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azapi_resource.ai_search.id
        type       = "ai_search"
      }
      target = azapi_resource.ai_search.output.properties.endpoint
      credentials = {
        key = data.azapi_resource_action.search_keys.output.primaryKey
      }
    }
  }
}

resource "azapi_resource" "bing_connection" {
  depends_on = [azapi_resource.ai_search_connection]
  type       = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"

  name      = local.bing_ground_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "ApiKey"
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azapi_resource.bing_grounding.id
        type       = "bing_grounding"
      }
      target = azapi_resource.bing_grounding.output.properties.endpoint
      credentials = {
        key = data.azapi_resource_action.bing_keys.output.key1
      }
    }
  }
}

resource "azapi_resource" "aoai_connection" {
  depends_on = [azapi_resource.bing_connection]
  type       = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"

  name      = local.aoai_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "AzureOpenAI"
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cognitive_account.azure_open_ai.id
        type       = "azure_open_ai"
      }
      target = azurerm_cognitive_account.azure_open_ai.endpoint
      credentials = {
        key = azurerm_cognitive_account.azure_open_ai.primary_access_key
      }
    }
  }
}

resource "azapi_resource" "content_understanding_connection" {
  depends_on = [azapi_resource.aoai_connection]
  type       = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"

  name      = local.content_understanding_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "AzureOpenAI"
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = data.azurerm_cognitive_account.content_understanding.id
        type       = "azure_open_ai"
      }
      target = data.azurerm_cognitive_account.content_understanding.id
      credentials = {
        key = data.azurerm_cognitive_account.content_understanding.primary_access_key      }
    }
  }
}

resource "azapi_resource" "app_insights_connection" {
  depends_on = [azapi_resource.content_understanding_connection]
  type       = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"

  name      = local.app_insights_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "AppInsights"
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_application_insights.this.id
        type       = "azure_app_insights"
      }
      target = azurerm_application_insights.this.id
      credentials = {
        key = azurerm_application_insights.this.connection_string
      }
    }
  }
}

resource "azapi_resource" "storage_connection" {
  depends_on = [azapi_resource.app_insights_connection,]
  type       = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"

  name      = local.storage_connection_name
  parent_id = azapi_resource.foundry_project.id

  body = {
    properties = {
      category      = "AzureBlob"
      authType      = "ManagedIdentity"
      isSharedToAll = true
      metadata = {
        ApiType       = "Azure"
        ResourceId    = azurerm_storage_account.this.id
        type          = "azure_storage"
        ContainerName = azurerm_storage_container.this.name
        AccountName   = azurerm_storage_account.this.name
      }
      target = azurerm_storage_account.this.primary_blob_endpoint
      credentials = {
        clientId   = azurerm_user_assigned_identity.foundry_identity.client_id
        resourceId = azurerm_user_assigned_identity.foundry_identity.id
      }
    }
  }
}
