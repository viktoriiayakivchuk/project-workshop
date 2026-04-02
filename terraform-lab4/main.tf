provider "azurerm" {
  features {}
}

# --- Task 1: Resource Group & Core Networking ---

resource "azurerm_resource_group" "rg" {
  name     = "az104-rg4"
  location = "East US"
}

resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet {
    name             = "SharedServicesSubnet"
    address_prefixes = ["10.20.10.0/24"]
  }

  subnet {
    name             = "DatabaseSubnet"
    address_prefixes = ["10.20.20.0/24"]
  }
}

# --- Task 2: Manufacturing Networking ---

resource "azurerm_virtual_network" "mfg_vnet" {
  name                = "ManufacturingVnet"
  address_space       = ["10.30.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet {
    name             = "SensorSubnet1"
    address_prefixes = ["10.30.20.0/24"]
  }

  subnet {
    name             = "SensorSubnet2"
    address_prefixes = ["10.30.21.0/24"]
  }
}

# --- Task 3: Security (ASG & NSG) ---

resource "azurerm_application_security_group" "asg_web" {
  name                = "asg-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "myNSGSecure"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                                  = "AllowASG"
    priority                              = 100
    direction                             = "Inbound"
    access                                = "Allow"
    protocol                              = "Tcp"
    source_port_range                     = "*"
    destination_port_ranges               = ["80", "443"]
    source_application_security_group_ids = [azurerm_application_security_group.asg_web.id]
    destination_address_prefix            = "*"
  }

  security_rule {
    name                       = "DenyInternetOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Окремий ресурс для асоціації NSG з підмережею (згідно з кроком 4 Task 3)
resource "azurerm_subnet_network_security_group_association" "core_nsg_assoc" {
  subnet_id                 = "${azurerm_virtual_network.core_vnet.id}/subnets/SharedServicesSubnet"
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- Task 4: DNS Zones ---

resource "azurerm_dns_zone" "public" {
  name                = "contoso.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "private" {
  name                = "private.contoso.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "manufacturing-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = azurerm_virtual_network.mfg_vnet.id
}