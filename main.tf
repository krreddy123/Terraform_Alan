terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.10.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  subscription_id = "#4ec16287-a91b-4a08-9e9d-ef48ad50ecdc#"
  tenant_id = "#1f47f2e8-91ed-4125-af35-38adddeabf22#"
  client_id = "#1483991f-79ac-4bcc-8efa-86368ea45889#"
  client_secret = "#suv8Q~tZ5QY0bGQVasrjgUy96lTbr6UGetOdkbz.#"
  features {}
}

locals {
  resource_group_name = "tf-pr-grp"
  location            = "North Europe"
  virtual_network = {
    name = "Tf-Pr-VN"
    address_space = "10.0.0.0/16"
  }
  subnets=[
    {
      name="SubNet-A"
      address_prefixes="10.0.1.0/24"
    },
    {
      name="SubNet-B"
      address_prefixes="10.0.2.0/24"
    }
  ]

}

resource "azurerm_resource_group" "tfrgrp" {
  name     = local.resource_group_name
  location = local.location
}

#Create Azure virtual network 

resource "azurerm_virtual_network" "TfPrVN" {
  name                = local.virtual_network.name
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = [local.virtual_network.address_space]
  depends_on = [
   azurerm_resource_group.tfrgrp
  ]
}
resource "azurerm_subnet" "SubNet-A" {
  name                 = local.subnets[0].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[0].address_prefixes]
  depends_on = [
    azurerm_virtual_network.TfPrVN
  ]
}

resource "azurerm_subnet" "SubNet-B" {
  name                 = local.subnets[1].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     = [local.subnets[1].address_prefixes]
  depends_on = [
    azurerm_virtual_network.TfPrVN
  ]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic1"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubNet-A.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PubIP1.id
  }
  depends_on = [
    azurerm_subnet.SubNet-A
  ]
}

resource "azurerm_public_ip" "PubIP1" {
  name                = "PubA"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
  depends_on = [
    azurerm_resource_group.tfrgrp
  ]
}

output "SubnetA-id" {
  value = azurerm_subnet.SubNet-A.id
}

resource "azurerm_network_security_group" "appnsg" {
  name                = "appnsg-1"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  depends_on = [
    azurerm_resource_group.tfrgrp
  ]
}

resource "azurerm_subnet_network_security_group_association" "appnsglinking" {
  subnet_id                 = azurerm_subnet.SubNet-A.id
  network_security_group_id = azurerm_network_security_group.appnsg.id
  depends_on = [
    azurerm_network_security_group.appnsg
  ]
}

resource "azurerm_windows_virtual_machine" "appvm" {
  name                = "appvm-1"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2S_v3"
  admin_username      = "adminuser"
  admin_password      = "Azure@123"
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

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
  depends_on = [
    azurerm_network_interface.nic,
    azurerm_resource_group.tfrgrp
  ]
}






