resource "azurerm_cognitive_deployment" "gpt_4o" {
  name                 = "gpt-4o"
  cognitive_account_id = data.azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "gp4o_mini" {
  depends_on = [
    data.azurerm_cognitive_account.this,
    azurerm_cognitive_deployment.gpt_4o
  ]
  name                 = "gpt-4o-mini"
  cognitive_account_id = data.azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "text_embedding_3_large" {
  depends_on = [
    data.azurerm_cognitive_account.this,
    azurerm_cognitive_deployment.gp4o_mini
  ]
  name                 = "text-embedding-3-large"
  cognitive_account_id = data.azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

resource "azapi_resource" "deepseek_r1_deployment" {    
    depends_on = [
      data.azurerm_cognitive_account.this,
      azurerm_cognitive_deployment.text_embedding_3_large
    ]
    type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
    name      = "deepseek-r1"
    parent_id = data.azurerm_cognitive_account.this.id

    body = {
        properties = {
            model = {
                format = "DeepSeek"
                name   = "DeepSeek-R1"
                version = "1"
            }
        }
        sku = {
            name     = "GlobalStandard"
            capacity = 250
        }
    }
}

resource "azapi_resource" "phi_4_deployment" {    
    depends_on = [
      data.azurerm_cognitive_account.this,
      azapi_resource.deepseek_r1_deployment
    ]
    type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
    name      = "phi-4"
    parent_id = data.azurerm_cognitive_account.this.id

    body = {
        properties = {
            model = {
                format  = "Microsoft"
                name    = "Phi-4"
                version = "7"
            }
        }
        sku = {
            name     = "GlobalStandard"
            capacity = 1
        }
    }
}