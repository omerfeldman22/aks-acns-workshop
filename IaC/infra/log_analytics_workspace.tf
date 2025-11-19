
resource "azurerm_log_analytics_workspace" "demo" {
  name                = "${var.base_name}-log-analytics"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Azure Monitor integration - Data collection rule for Container Insights
resource "azurerm_monitor_data_collection_rule" "ci" {
  name                = "${var.base_name}-ci-dcr"
  resource_group_name = azurerm_resource_group.demo.name
  location            = var.region

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.demo.id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }

  depends_on = [
    azurerm_log_analytics_workspace.demo
  ]
}