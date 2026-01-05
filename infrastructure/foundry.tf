data "azurerm_cognitive_account" "this" {
    depends_on          = [azapi_resource.foundry]
    name                = local.ai_foundry_name
    resource_group_name = azurerm_resource_group.this.name
}

data "azurerm_monitor_diagnostic_categories" "this" {
    resource_id = data.azurerm_cognitive_account.this.id
}

resource "azapi_resource" "foundry" {
    type      = "Microsoft.CognitiveServices/accounts@2025-06-01"
    name      = local.ai_foundry_name
    location  = azurerm_resource_group.this.location
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
            customSubDomainName    = local.ai_foundry_name
            publicNetworkAccess    = "Enabled"
        }
    }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
    depends_on = [
        data.azurerm_monitor_diagnostic_categories.this
    ]

    name                       = "diag"
    target_resource_id         = data.azurerm_cognitive_account.this.id
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

    dynamic "enabled_log" {
        for_each = toset(data.azurerm_monitor_diagnostic_categories.this.log_category_types)
        content {
            category = enabled_log.value
        }
    }

    enabled_metric {
        category = "AllMetrics"
    }
}

