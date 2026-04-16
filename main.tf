# Task 1: Core Services Infrastructure
resource "azurerm_resource_group" "rg5" {
  name     = "az104-rg5"
  location = "West Europe" 
}

resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
}

resource "azurerm_subnet" "core_subnet" {
  name                 = "Core"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "core_nic" {
  name                = "core-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.core_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "core_vm" {
  name                = "CoreServicesVM"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!"
  network_interface_ids = [azurerm_network_interface.core_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Task 2: Manufacturing Infrastructure
resource "azurerm_virtual_network" "mfg_vnet" {
  name                = "ManufacturingVnet"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
}

resource "azurerm_subnet" "mfg_subnet" {
  name                 = "Manufacturing"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.mfg_vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}

resource "azurerm_network_interface" "mfg_nic" {
  name                = "mfg-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mfg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "mfg_vm" {
  name                = "ManufacturingVM"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!"
  network_interface_ids = [azurerm_network_interface.mfg_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Task 4: VNet Peering
resource "azurerm_virtual_network_peering" "core_to_mfg" {
  name                         = "CoreServicesVnet-to-ManufacturingVnet"
  resource_group_name          = azurerm_resource_group.rg5.name
  virtual_network_name         = azurerm_virtual_network.core_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.mfg_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "mfg_to_core" {
  name                         = "ManufacturingVnet-to-CoreServicesVnet"
  resource_group_name          = azurerm_resource_group.rg5.name
  virtual_network_name         = azurerm_virtual_network.mfg_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.core_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Task 6: Custom Routing
resource "azurerm_subnet" "perimeter_subnet" {
  name                 = "perimeter"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_route_table" "rt" {
  name                          = "rt-CoreServices"
  location                      = azurerm_resource_group.rg5.location
  resource_group_name           = azurerm_resource_group.rg5.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "PerimetertoCore"
    address_prefix         = "10.0.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.7"
  }
}

resource "azurerm_subnet_route_table_association" "assoc" {
  subnet_id      = azurerm_subnet.core_subnet.id
  route_table_id = azurerm_route_table.rt.id
}