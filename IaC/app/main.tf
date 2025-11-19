# Data source to get AKS cluster credentials
data "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.base_name}-aks"
  resource_group_name = "${var.base_name}-rg"
}

# Data source to get ACR details
data "azurerm_container_registry" "acr" {
  name                = "${var.base_name}acr"
  resource_group_name = "${var.base_name}-rg"
}