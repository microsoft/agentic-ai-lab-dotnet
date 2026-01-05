resource "azurerm_cognitive_account" "azure_open_ai" {
  name                  = local.openai_name
  resource_group_name   = azurerm_resource_group.this.name
  location              = local.location
  custom_subdomain_name = local.openai_name
  kind                  = "OpenAI"

  sku_name = "S0"
}

resource "azurerm_cognitive_deployment" "aoai_gpt_4o_deployment" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.azure_open_ai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "aoai_text_embedding3_small" {
  name                 = "text-embedding-3-large"
  cognitive_account_id = azurerm_cognitive_account.azure_open_ai.id
  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  sku {
    name = "GlobalStandard"
  }
}
