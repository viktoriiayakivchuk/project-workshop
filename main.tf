resource "azurerm_resource_group" "rg11" {
  name     = "az104-rg11"
  location = "Sweden Central"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az104-11-vnet"
  address_space       = ["10.11.0.0/16"]
  location            = azurerm_resource_group.rg11.location
  resource_group_name = azurerm_resource_group.rg11.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg11.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.11.0.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "az104-11-nic"
  location            = azurerm_resource_group.rg11.location
  resource_group_name = azurerm_resource_group.rg11.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Task 4: Закоментовано для імітації видалення та перевірки Alert
/*
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "az104-11-vm0"
  resource_group_name = azurerm_resource_group.rg11.name
  location            = azurerm_resource_group.rg11.location
  size                = "Standard_D2as_v5"
  admin_username      = "localadmin"
  admin_password      = "MyP@ssw0rd!2024"

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "da" {
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
}
*/

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-az104-11"
  location            = azurerm_resource_group.rg11.location
  resource_group_name = azurerm_resource_group.rg11.name
  sku                 = "PerGB2018"
}

# Task 3
resource "azurerm_monitor_action_group" "alert_ops" {
  name                = "Alert the operations team"
  resource_group_name = azurerm_resource_group.rg11.name
  short_name          = "AlertopsTeam"

  email_receiver {
    name                    = "VM was deleted"
    email_address           = "твій_email@приклад.com" 
    use_common_alert_schema = true
  }
}

# Task 2
resource "azurerm_monitor_activity_log_alert" "vm_delete_alert" {
  name                = "VM was deleted"
  resource_group_name = azurerm_resource_group.rg11.name
  scopes              = ["/subscriptions/${data.azurerm_subscription.current.subscription_id}"]
  description         = "A VM in your resource group was deleted"

  criteria {
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    category       = "Administrative"
    level          = "Informational"
  }

  action {
    action_group_id = azurerm_monitor_action_group.alert_ops.id
  }
}

data "azurerm_subscription" "current" {}

# Task 5: Правило обробки сповіщень для пригнічення під час обслуговування
resource "azurerm_monitor_alert_processing_rule_suppression" "maintenance_window" {
  name                = "Planned-Maintenance"
  resource_group_name = azurerm_resource_group.rg11.name
  
  scopes              = [azurerm_resource_group.rg11.id]

  description         = "Suppress notifications during planned maintenance."

  schedule {
    effective_from  = "2026-04-15T22:00:00" 
    effective_until = "2026-04-16T07:00:00" 
    time_zone       = "FLE Standard Time"   
  }
}