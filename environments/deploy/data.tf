data "azurerm_resource_group" "vm" {
  name = var.existing_resource_group_name
}

data "azurerm_virtual_network" "main" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group
}

data "azurerm_subnet" "main" {
  name                 = var.existing_subnet_name
  virtual_network_name = data.azurerm_virtual_network.main.name
  resource_group_name  = var.existing_vnet_resource_group
}
