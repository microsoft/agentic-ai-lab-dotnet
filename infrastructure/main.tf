

locals {
  location                              = var.region
  resource_name                         = "${random_pet.this.id}-${random_id.this.dec}"
  ai_services_name                      = "${local.resource_name}-ai-services"
  ai_foundry_name                       = "${local.resource_name}-foundry"
  hub_name                              = "${local.resource_name}-aihub"
  project_name                          = "${local.resource_name}-project"
  kv_name                               = "${local.resource_name}-kv"
  bing_name                             = "${local.resource_name}-bing-grounding"
  acr_name                              = "${replace(local.resource_name, "-", "")}acr"
  storage_account_name                  = "${replace(local.resource_name, "-", "")}sa"
  appinsights_name                      = "${local.resource_name}-appinsights"
  loganalytics_name                     = "${local.resource_name}-logs"
  search_service_name                   = "${local.resource_name}-search"
  openai_name                           = "${local.resource_name}-openai"
  content_understanding_name            = "${local.resource_name}-content-understanding"
  content_safety_name                   = "${local.resource_name}-content-safety"
  content_understanding_location        = "westus" # Content Understanding is only available in West US
  bing_ground_connection_name           = "bing-connection"
  ai_search_connection_name             = "search-connection"
  aoai_connection_name                  = "aoai-connection"
  app_insights_connection_name          = "app-insights-connection"
  content_understanding_connection_name = "content-understanding-connection"
  storage_connection_name               = "storage-connection"
}