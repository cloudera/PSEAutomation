# Terraform Block
terraform {
  required_version = ">= 1.4.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}
# Provider Block
provider "azurerm" {
  features {}
  # profile = "default"
}

data "azurerm_resource_group" "cdp" {
  name = var.resource_group_name
}

data "azurerm_subnet" "gateway" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.network_resource_group_name
}

resource "azurerm_public_ip" "keycloak" {
  name                = "${var.workshop_name}-keyc-pip"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = data.azurerm_resource_group.cdp.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "keycloak" {
  name                = var.kc_security_group
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = data.azurerm_resource_group.cdp.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.local_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.local_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.local_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "userassignment"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = var.local_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "keycloak" {
  name                = "${var.workshop_name}-keyc-nic"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = data.azurerm_resource_group.cdp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.gateway.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.keycloak.id
  }
}

resource "azurerm_network_interface_security_group_association" "keycloak" {
  network_interface_id      = azurerm_network_interface.keycloak.id
  network_security_group_id = azurerm_network_security_group.keycloak.id
}

resource "azurerm_linux_virtual_machine" "keycloak" {
  name                = "${var.workshop_name}-keyc"
  location            = data.azurerm_resource_group.cdp.location
  resource_group_name = data.azurerm_resource_group.cdp.name
  size                = var.instance_type
  admin_username      = "ubuntu"

  network_interface_ids = [
    azurerm_network_interface.keycloak.id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/install-docker.sh", {
    keycloak_admin_password = var.keycloak_admin_password,
    domain                  = var.domain,
    workshop_name           = var.workshop_name,
    wildcard_fullchain      = var.wildcard_fullchain,
    wildcard_privkey        = var.wildcard_privkey,
  }))

  provisioner "file" {
    source      = "cloudera-newco-wshps.png"
    destination = "/tmp/cloudera-newco-wshps.png"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/userconfig/.${var.workshop_name}/${var.ssh_key_name}.pem")
      host        = azurerm_public_ip.keycloak.ip_address
    }
  }

  provisioner "file" {
    source      = "cloudera-wshps.png"
    destination = "/tmp/cloudera-wshps.png"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/userconfig/.${var.workshop_name}/${var.ssh_key_name}.pem")
      host        = azurerm_public_ip.keycloak.ip_address
    }
  }
}
