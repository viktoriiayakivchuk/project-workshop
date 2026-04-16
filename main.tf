# Task 1
resource "azurerm_resource_group" "rg7" {
  name     = "az104-rg7"
  location = "East US"
}

resource "random_id" "server" {
  byte_length = 8
}

resource "azurerm_storage_account" "storage" {
  name                          = "staz104${lower(random_id.server.hex)}"
  resource_group_name           = azurerm_resource_group.rg7.name
  location                      = azurerm_resource_group.rg7.location
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  public_network_access_enabled = true 

  blob_properties {
    versioning_enabled = true
  }
}

# Об'єднаний блок правил для Task 1 та Task 3
resource "azurerm_storage_account_network_rules" "network_rules" {
  storage_account_id = azurerm_storage_account.storage.id

  default_action             = "Deny"
  # Ми прибрали ip_rules, щоб залишити доступ тільки для VNet згідно з Task 3
  virtual_network_subnet_ids = [azurerm_subnet.subnet.id]
  bypass                     = ["AzureServices"]
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.storage.id

  rule {
    name    = "Movetocool"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
}

# Task 2
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container_immutability_policy" "retention" {
  storage_container_resource_manager_id = azurerm_storage_container.data.resource_manager_id
  immutability_period_in_days           = 180
}

# Task 3: Manage Azure Files
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg7.location
  resource_group_name = azurerm_resource_group.rg7.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg7.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_storage_share" "share" {
  name                 = "share1"
  storage_account_name = azurerm_storage_account.storage.name
  quota                = 1
}