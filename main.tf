# === TASK 1: Resource Group & Random Suffix ===

resource "azurerm_resource_group" "rg9" {
  name     = "az104-rg9"
  location = "West Europe"
}

resource "random_id" "webapp_suffix" {
  byte_length = 4
}

# === TASK 2: App Service Plan (Standard S1) ===

resource "azurerm_service_plan" "asp9" {
  name                = "az104-asp9"
  resource_group_name = azurerm_resource_group.rg9.name
  location            = azurerm_resource_group.rg9.location
  os_type             = "Linux"
  sku_name            = "S1" 
}

# Основний Web App (Production)
resource "azurerm_linux_web_app" "webapp" {
  name                = "viktoriia-webapp-${random_id.webapp_suffix.hex}"
  resource_group_name = azurerm_resource_group.rg9.name
  location            = azurerm_service_plan.asp9.location
  service_plan_id     = azurerm_service_plan.asp9.id

  site_config {
    always_on = false
    application_stack {
      php_version = "8.2"
    }
  }
}

# Створюємо Deployment Slot "staging"
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.webapp.id

  site_config {
    always_on = false
    application_stack {
      php_version = "8.2"
    }
  }
}

# === TASK 3: Configure Deployment from GitHub ===

resource "azurerm_app_service_source_control_slot" "github_staging" {
  slot_id                = azurerm_linux_web_app_slot.staging.id
  repo_url               = "https://github.com/Azure-Samples/php-docs-hello-world"
  branch                 = "master"
  use_manual_integration = true
}