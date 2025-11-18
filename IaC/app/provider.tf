provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

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

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "docker" {
  registry_auth {
    address  = data.azurerm_container_registry.acr.login_server
    username = data.azurerm_container_registry.acr.admin_username
    password = data.azurerm_container_registry.acr.admin_password
  }
}
