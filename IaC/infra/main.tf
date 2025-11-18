data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "demo" {
  name     = "${var.base_name}-rg"
  location = var.region
}