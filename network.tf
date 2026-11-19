terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "cdfa317b-7cd2-48df-a47c-98541acf6ea6"
}

data "azurerm_resource_group" "mexico" {
  name = "RGMXCFX"
}

resource "azurerm_virtual_network" "mexico" {
  name                = "vnet-mxc-vpn"
  location            = "mexicocentral"
  resource_group_name = data.azurerm_resource_group.mexico.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-mxc-workload"
  resource_group_name  = data.azurerm_resource_group.mexico.name
  virtual_network_name = azurerm_virtual_network.mexico.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "vpn" {
  name                 = "snet-mxc-vpn"
  resource_group_name  = data.azurerm_resource_group.mexico.name
  virtual_network_name = azurerm_virtual_network.mexico.name
  address_prefixes     = ["10.1.1.0/24"]
}
