# Task 1: Deploy an Azure Container Instance using a Docker image

# Використовуємо ту саму ресурсну групу, що й у попередній лабі
resource "azurerm_resource_group" "rg9b" {
  name     = "az104-rg9"
  location = "East US"
}

# Генерація унікального суфікса для DNS-імені
resource "random_id" "dns_suffix" {
  byte_length = 4
}

# Створення Container Instance
resource "azurerm_container_group" "aci1" {
  name                = "az104-c1"
  location            = azurerm_resource_group.rg9b.location
  resource_group_name = azurerm_resource_group.rg9b.name
  ip_address_type     = "Public"
  dns_name_label      = "az104-viktoriia-${random_id.dns_suffix.hex}"
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }
}