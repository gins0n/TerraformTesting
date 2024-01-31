# Create Resource Group

resource "azurerm_resource_group" "main-rg" {
   name     = "l-cslab-ew-rg-arinfra"
   location = "West Europe"

   tags = {
     CreatedBy = "Adam Rioux"
     User = "Adam Rioux"
     Use = "Resource Group for Terraform testing lab"
   }
 
}


#Create vNet

resource "azurerm_virtual_network" "main-vnet" {
  name                = "l-cslab-ew-vnet-arvnet"
  address_space       = ["10.0.0.0/16"]
  location            = "West Europe"
  resource_group_name = azurerm_resource_group.main-rg.name
}

#subnets

resource "azurerm_subnet" "client-subnet" {
  name = "l-cslab-ew-sn-testclientsubnet"
  resource_group_name = azurerm_resource_group.main-rg.name
  virtual_network_name = azurerm_virtual_network.main-vnet.name
  address_prefix = "10.0.1.0/24"
}

resource "azurerm_subnet" "domain-subnet" {
  name = "l-cslab-ew-sn-testdomainsubnet"
  resource_group_name = azurerm_resource_group.main-rg.name
  virtual_network_name = azurerm_virtual_network.main-vnet.name
  address_prefix = "10.0.2.0/24"
}

#Nics

resource "azurerm_network_interface" "clientnic" {
  name = "l-cslab-ew-Nic-arclientnic"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name

  ip_configuration {
    name = "l-cslab-ew-ipconfig-aripconfig1"
    subnet_id = azurerm_subnet.client-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.1.50"
  }
}

resource "azurerm_network_interface" "domainnic" {
  name = "l-cslab-ew-Nic-ardomainnic"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name

  ip_configuration {
    name = "l-cslab-ew-ipconfig-aripconfig2"
    subnet_id = azurerm_subnet.domain-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.2.50"
    public_ip_address_id = azurerm_public_ip.domainpip.id
  }
}


#IP Addresses

resource "azurerm_public_ip" "domainpip" {
  name = "l-cslab-ew-pip-ariouxpip" 
  resource_group_name = azurerm_resource_group.main-rg.name
  location = azurerm_resource_group.main-rg.location
  allocation_method = "Static"
}


#VMs

resource "azurerm_virtual_machine" "clientvm" {
  name = "l-cslab-ew-vm-ariouxclient"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name
  network_interface_ids = [azurerm_network_interface.clientnic.id]
  vm_size = "Standard_b2ms"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2022-Datacenter"
    version = "latest"
  }

 storage_os_disk {
  name = "l-cslab-ew-vm-ariouxclient-d"
  caching = "ReadWrite"
  create_option = "FromImage"
  managed_disk_type = "Standard_LRS"
}
os_profile {
  computer_name = "lcslabewvmarc"
  admin_username = "testadmin"
  admin_password = "Password1234!"
}

os_profile_windows_config {
  }
}

resource "azurerm_virtual_machine" "domainvm" {
  name = "l-cslab-ew-vm-ariouxdomain"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name
  network_interface_ids = [azurerm_network_interface.domainnic.id]
  vm_size = "Standard_b2ms"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2022-Datacenter"
    version = "latest"
  }

 storage_os_disk {
  name = "l-cslab-ew-vm-ariouxdomain-d"
  caching = "ReadWrite"
  create_option = "FromImage"
  managed_disk_type = "Standard_LRS"
}

os_profile {
  computer_name = "lcslabewvmard"
  admin_username = "testadmin"
  admin_password = "Password1234!"
}

os_profile_windows_config {
  }
}


#NSGs

resource "azurerm_network_security_group" "domainnsg" {
  name = "l-cslab-ew-nsg-domainnsg"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name

  security_rule {
  name = "RDPCorporateAllow"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "3389"
    destination_port_range = "*"
    source_address_prefixes = [""]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name = "InboundDenyvNet"
    priority = 110
    direction = "Inbound"
    access = "Deny"
    protocol = "*"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name = "RDPOutboundAllow"
    priority = 120
    direction = "Outbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "3389"
    destination_port_range = "*"
    source_address_prefix = "10.0.2.50"
    destination_address_prefix = "10.0.1.50"
  }

  security_rule {
    name = "DenyAnyOutbound"
    priority = 130
    direction = "Outbound"
	access = "Deny"
    protocol = "*"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "10.0.2.50"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "clientnsg" {

  name = "l-cslab-ew-nsg-clientnsg"
  location = azurerm_resource_group.main-rg.location
  resource_group_name = azurerm_resource_group.main-rg.name

  security_rule {
    name = "AllowDomainRDPInbound"
    priority = 100
    direction ="Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "3389"
    destination_port_range = "*"
    source_address_prefix = "10.0.2.50"
    destination_address_prefix =  "10.0.1.50"
  }

  security_rule {
    name  = "InboundDenyvNet"
    priority = 110
    direction = "Inbound"
    access = "Deny"
    protocol = "*"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "10.0.0.0/16"
    destination_address_prefix = "10.0.1.50"
  }  

security_rule {
    name = "OutboundDenyvNet"
priority = 120
    direction = "Outbound"
    access = "Deny"
    protocol = "*"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "10.0.1.0/24"
    destination_address_prefix = "10.0.0.0/16"
    }
  }


# nsgAssociations

resource "azurerm_subnet_network_security_group_association" "domain" {
subnet_id = azurerm_subnet.domain-subnet.id
network_security_group_id = azurerm_network_security_group.domainnsg.id
}

resource "azurerm_subnet_network_security_group_association" "client" {
  subnet_id = azurerm_subnet.client-subnet.id
  network_security_group_id = azurerm_network_security_group.clientnsg.id
}

