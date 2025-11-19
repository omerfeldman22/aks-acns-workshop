resource "azurerm_monitor_workspace" "demo" {
  name                = "${var.base_name}-monitor"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region
}

# Data collection rule for Prometheus metrics
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                = "${var.base_name}-prometheus-dcr"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.demo.id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  depends_on = [
    azurerm_monitor_workspace.demo
  ]
}