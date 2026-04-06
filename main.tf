# Task 1: Create and configure an Azure Container App and environment

# 1. Ресурсна група (якщо ти її видалила, вона створиться заново)
resource "azurerm_resource_group" "rg9c" {
  name     = "az104-rg9"
  location = "East US"
}

# 2. Log Analytics Workspace (необхідний для моніторингу середовища)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "viktoriia-law"
  location            = azurerm_resource_group.rg9c.location
  resource_group_name = azurerm_resource_group.rg9c.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 3. Container App Environment (Середовище my-environment)
resource "azurerm_container_app_environment" "env" {
  name                       = "my-environment"
  location                   = azurerm_resource_group.rg9c.location
  resource_group_name        = azurerm_resource_group.rg9c.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

# 4. Container App (Застосунок my-app)
resource "azurerm_container_app" "app" {
  name                         = "my-app"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg9c.name
  revision_mode                = "Single"

  template {
    container {
      name   = "hello-world-container"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}