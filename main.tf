terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" 
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg6" {
  name     = "az104-rg6"
  location = "North Europe" # Змінено для кращої доступності SKU
}

# Task 1: Provision an infrastructure - Virtual Network
resource "azurerm_virtual_network" "vnet1" {
  name                = "az104-06-vnet1"
  address_space       = ["10.60.0.0/22"]
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name
}

resource "azurerm_subnet" "subnet0" {
  name                 = "Subnet0"
  resource_group_name  = azurerm_resource_group.rg6.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.60.0.0/24"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "Subnet1"
  resource_group_name  = azurerm_resource_group.rg6.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.60.1.0/24"]
}

# Task 1: Provision an infrastructure - Virtual Machines (Count: 2)
resource "azurerm_network_interface" "nic" {
  count               = 2 # Обмежено до 2 для дотримання квоти ядер
  name                = "az104-06-nic${count.index}"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = count.index == 0 ? azurerm_subnet.subnet0.id : azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  count               = 2
  name                = "az104-06-vm${count.index}"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location
  size                = "Standard_D2s_v3" 
  admin_username      = "student"
  admin_password      = "Pa55w.rd1234"
  
  custom_data = base64encode(<<-EOF
    <powershell>
    Install-WindowsFeature -name Web-Server -IncludeManagementTools
    Remove-Item C:\inetpub\wwwroot\iisstart.htm
    Add-Content -Path C:\inetpub\wwwroot\iisstart.htm -Value "Hello World from $env:computername"
    </powershell>
    EOF
  )

  network_interface_ids = [azurerm_network_interface.nic[count.index].id]

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

# Task 2: Configure an Azure Load Balancer - Public IP
resource "azurerm_public_ip" "lb_pip" {
  name                = "az104-lbpip"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Task 2: Configure an Azure Load Balancer - Create LB
resource "azurerm_lb" "lb" {
  name                = "az104-lb"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "az104-fe"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

# Task 2: Configure an Azure Load Balancer - Backend Pool
resource "azurerm_lb_backend_address_pool" "be_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "az104-be"
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_assoc" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.be_pool.id
}

# Task 2: Configure an Azure Load Balancer - Health Probe
resource "azurerm_lb_probe" "hp" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "az104-hp"
  port            = 80
  protocol        = "Tcp"
  interval_in_seconds = 5
}

# Task 2: Configure an Azure Load Balancer - Load Balancing Rule
resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "az104-lbrule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "az104-fe"
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.be_pool.id]
  probe_id                       = azurerm_lb_probe.hp.id
}

# Вивід IP-адреси для тестування
output "load_balancer_public_ip" {
  value = azurerm_public_ip.lb_pip.ip_address
}
# Task 2: Security - Create NSG to allow HTTP
resource "azurerm_network_security_group" "nsg" {
  name                = "az104-06-nsg"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Прив'язка NSG до обох підмереж (щоб пустити трафік до машин)
resource "azurerm_subnet_network_security_group_association" "assoc0" {
  subnet_id                 = azurerm_subnet.subnet0.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "assoc1" {
  subnet_id                 = azurerm_subnet.subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Task 3: Dedicated Subnet for Application Gateway
resource "azurerm_subnet" "subnet_agw" {
  name                 = "Subnet-AGW"
  resource_group_name  = azurerm_resource_group.rg6.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.60.3.0/24"]
}

# Task 3: Public IP for Application Gateway
resource "azurerm_public_ip" "agw_pip" {
  name                = "az104-06-pip-agw"
  location            = azurerm_resource_group.rg6.location
  resource_group_name = azurerm_resource_group.rg6.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Task 3: Path-based Routing Configuration
resource "azurerm_application_gateway" "app_gw" {
  name                = "az104-06-appgw"
  resource_group_name = azurerm_resource_group.rg6.name
  location            = azurerm_resource_group.rg6.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "agw-ip-config"
    subnet_id = azurerm_subnet.subnet_agw.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "agw-fe-config"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  # Пул для зображень (використовуємо vm0)
  backend_address_pool {
    name         = "az104-imagebe"
    ip_addresses = [azurerm_network_interface.nic[0].private_ip_address]
  }

  # Пул для відео (використовуємо vm1)
  backend_address_pool {
    name         = "az104-videobe"
    ip_addresses = [azurerm_network_interface.nic[1].private_ip_address]
  }

  backend_http_settings {
    name                  = "az104-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "agw-listener"
    frontend_ip_configuration_name = "agw-fe-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # ОСНОВНЕ: Правило маршрутизації за шляхом
  request_routing_rule {
    name               = "path-routing-rule"
    rule_type          = "PathBasedRouting" 
    http_listener_name = "agw-listener"
    url_path_map_name  = "url-path-map"
    priority           = 10
  }

  url_path_map {
    name                               = "url-path-map"
    default_backend_address_pool_name  = "az104-imagebe"
    default_backend_http_settings_name = "az104-http"

    path_rule {
      name                       = "imagesBackend"
      paths                      = ["/image/*"]
      backend_address_pool_name  = "az104-imagebe"
      backend_http_settings_name = "az104-http"
    }

    path_rule {
      name                       = "videosBackend"
      paths                      = ["/video/*"]
      backend_address_pool_name  = "az104-videobe"
      backend_http_settings_name = "az104-http"
    }
  }
}