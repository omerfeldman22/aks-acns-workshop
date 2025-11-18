resource "azurerm_monitor_workspace" "demo" {
  name                = "${var.base_name}-monitor"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region
}

resource "azurerm_dashboard_grafana" "demo" {
  name                              = "${var.base_name}-grafana"
  resource_group_name               = azurerm_resource_group.demo.name
  location                          = var.region
  sku                               = "Standard"
  api_key_enabled                   = false
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true
  zone_redundancy_enabled           = false

  grafana_major_version = var.grafana_major_version

  identity {
    type = "SystemAssigned"
  }

  # Integrate with Azure Monitor workspace for Prometheus metrics
  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.demo.id
  }

  depends_on = [
    azurerm_monitor_workspace.demo
  ]
}

# Assign Grafana Admin role to current user
resource "azurerm_role_assignment" "grafana_admin" {
  scope                = azurerm_dashboard_grafana.demo.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_dashboard_grafana.demo]
}

resource "azurerm_log_analytics_workspace" "demo" {
  name                = "${var.base_name}-log-analytics"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
