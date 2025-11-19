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

# Grafana integration - Role assignment for monitoring
resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  principal_id         = azurerm_dashboard_grafana.demo.identity[0].principal_id
  role_definition_name = "Monitoring Reader"
  scope                = azurerm_kubernetes_cluster.demo.id

  depends_on = [
    azurerm_kubernetes_cluster.demo,
    azurerm_dashboard_grafana.demo
  ]
}

# Grafana - Monitoring Data Reader role for Azure Monitor workspace
resource "azurerm_role_assignment" "grafana_monitoring_data_reader" {
  principal_id         = azurerm_dashboard_grafana.demo.identity[0].principal_id
  role_definition_name = "Monitoring Data Reader"
  scope                = azurerm_monitor_workspace.demo.id

  depends_on = [
    azurerm_monitor_workspace.demo,
    azurerm_dashboard_grafana.demo
  ]
}

# Grafana - Log Analytics monitoring reader role for Container Insights
resource "azurerm_role_assignment" "grafana_log_monitoring_reader" {
  principal_id         = azurerm_dashboard_grafana.demo.identity[0].principal_id
  role_definition_name = "Monitoring Reader"
  scope                = azurerm_resource_group.demo.id

  depends_on = [
    azurerm_log_analytics_workspace.demo,
    azurerm_dashboard_grafana.demo
  ]
}