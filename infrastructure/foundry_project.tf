resource "azapi_resource" "foundry_project" {
    type      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
    name      = local.project_name
    location  = azurerm_resource_group.this.location
    parent_id = azapi_resource.foundry.id

    identity {
        type = "SystemAssigned, UserAssigned"
        identity_ids = [
            azurerm_user_assigned_identity.foundry_identity.id
        ]
    }

    body = {
        properties = {
          displayName = local.project_name
        }
    }

    response_export_values = ["identity.principalId"]

}

data "azurerm_monitor_diagnostic_categories" "foundry_project" {
    resource_id = azapi_resource.foundry_project.id
}