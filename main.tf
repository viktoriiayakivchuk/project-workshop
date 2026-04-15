# --- Допоміжні ресурси ---
resource "random_id" "sa_id" {
  byte_length = 4
}

# --- Task 1: Основна інфраструктура (Region 1) ---
resource "azurerm_resource_group" "rg_region1" {
  name     = "az104-rg-region1"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "az104-10-vnet1"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg_region1.location
  resource_group_name = azurerm_resource_group.rg_region1.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg_region1.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.10.0.0/24"]
  depends_on           = [azurerm_virtual_network.vnet1]
}

resource "azurerm_network_interface" "nic" {
  name                = "az104-10-nic"
  location            = azurerm_resource_group.rg_region1.location
  resource_group_name = azurerm_resource_group.rg_region1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_subnet.subnet]
}

resource "azurerm_windows_virtual_machine" "vm0" {
  name                = "az104-10-vm0"
  resource_group_name = azurerm_resource_group.rg_region1.name
  location            = azurerm_resource_group.rg_region1.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!" 

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# --- Task 2: Recovery Services Vault (Region 1) ---
resource "azurerm_recovery_services_vault" "vault" {
  name                = "az104-rsv-region1"
  location            = azurerm_resource_group.rg_region1.location
  resource_group_name = azurerm_resource_group.rg_region1.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  soft_delete_enabled = true
}

# --- Task 3: Backup Policy & VM Protection ---
resource "azurerm_backup_policy_vm" "policy" {
  name                = "az104-backup"
  resource_group_name = azurerm_resource_group.rg_region1.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  timezone            = "FLE Standard Time" 

  backup {
    frequency = "Daily" 
    time      = "00:00" 
  }

  retention_daily {
    count = 30 
  }

  instant_restore_retention_days = 2 
}

resource "azurerm_backup_protected_vm" "vm_backup" {
  resource_group_name = azurerm_resource_group.rg_region1.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = azurerm_windows_virtual_machine.vm0.id
  backup_policy_id    = azurerm_backup_policy_vm.policy.id
}

# --- Task 4: Monitoring (Storage Account & Diagnostics) ---
resource "azurerm_storage_account" "sa_logs" {
  name                     = "viklogs${random_id.sa_id.hex}" 
  resource_group_name      = azurerm_resource_group.rg_region1.name
  location                 = azurerm_resource_group.rg_region1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_monitor_diagnostic_setting" "vault_diagnostics" {
  name               = "Logs and Metrics to storage"
  target_resource_id = azurerm_recovery_services_vault.vault.id
  storage_account_id = azurerm_storage_account.sa_logs.id

  # Використовуємо Resource Specific категорії
  enabled_log { category = "CoreAzureBackup" }
  enabled_log { category = "AddonAzureBackupJobs" }
  enabled_log { category = "AddonAzureBackupAlerts" }
  enabled_log { category = "AddonAzureBackupPolicy" }
  enabled_log { category = "AddonAzureBackupStorage" }
  enabled_log { category = "AzureSiteRecoveryJobs" }
  enabled_log { category = "AzureSiteRecoveryEvents" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# --- Task 5: Disaster Recovery (Region 2) ---
resource "azurerm_resource_group" "rg_region2" {
  name     = "az104-rg-region2"
  location = "North Europe"
}

resource "azurerm_recovery_services_vault" "vault_region2" {
  name                = "az104-rsv-region2"
  location            = azurerm_resource_group.rg_region2.location
  resource_group_name = azurerm_resource_group.rg_region2.name
  sku                 = "Standard"
}