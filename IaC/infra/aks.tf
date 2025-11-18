resource "azurerm_kubernetes_cluster" "demo" {
  name                = "${var.base_name}-aks"
  location            = var.region
  resource_group_name = azurerm_resource_group.demo.name
  dns_prefix          = "${var.base_name}-aks"
  kubernetes_version  = "1.33"

  private_cluster_enabled = false

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 4
    vnet_subnet_id       = azurerm_subnet.aks.id
    
    os_sku = "AzureLinux"

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane = "cilium"
    
    # Service and pod CIDR configuration
    service_cidr   = var.aks_service_cidr
    dns_service_ip = var.aks_dns_service_ip
    pod_cidr       = var.pod_cidr
    
    # Load balancer configuration - Standard SKU for public access
    load_balancer_sku = "standard"
    
    ip_versions = ["IPv4"]
    
    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  # System-assigned managed identity for AKS cluster
  identity {
    type = "SystemAssigned"
  }

  # Azure Monitor Container Insights integration
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.demo.id
    msi_auth_for_monitoring_enabled = true
  }

  # Azure Monitor managed Prometheus metrics
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  depends_on = [
    azurerm_subnet.aks,
    azurerm_log_analytics_workspace.demo
  ]

  lifecycle {
    ignore_changes = [
      network_profile[0].advanced_networking
    ]
  }
}

# User node pool for workloads
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.demo.id
  vm_size               = "Standard_D4s_v5"
  auto_scaling_enabled  = true
  min_count             = 2
  max_count             = 4
  vnet_subnet_id        = azurerm_subnet.aks.id
  
  os_sku = "AzureLinux"

  # Node labels for workload scheduling
  node_labels = {
    "workload" = "user"
  }

  upgrade_settings {
    drain_timeout_in_minutes      = 0
    max_surge                     = "10%"
    node_soak_duration_in_minutes = 0
  }

  depends_on = [azurerm_kubernetes_cluster.demo]
}

# Enable ACNS using AzAPI provider
resource "azapi_update_resource" "aks_acns" {
  type        = "Microsoft.ContainerService/managedClusters@2025-09-02-preview"
  resource_id = azurerm_kubernetes_cluster.demo.id

  body = {
    properties = {
      networkProfile = {
        advancedNetworking = {
          enabled = true
          observability = {
            enabled = true
          }
          security = {
            enabled                 = true
            advancedNetworkPolicies = "L7"
            transitEncryption = {
              type = "WireGuard"
            }
          }
          performance = {
            accelerationMode = "BpfVeth"
          }
        }
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster.demo]
}

# ACR integration - Role assignment
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.demo.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.demo.id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_kubernetes_cluster.demo,
    azurerm_container_registry.demo
  ]
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

# Associate Container Insights DCR with AKS cluster
resource "azurerm_monitor_data_collection_rule_association" "ci" {
  name                    = "${var.base_name}-ci-dcra"
  target_resource_id      = azurerm_kubernetes_cluster.demo.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.ci.id

  depends_on = [
    azurerm_kubernetes_cluster.demo,
    azurerm_monitor_data_collection_rule.ci
  ]
}

# Associate Prometheus DCR with AKS cluster
resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "${var.base_name}-prometheus-dcra"
  target_resource_id      = azurerm_kubernetes_cluster.demo.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id

  depends_on = [
    azurerm_kubernetes_cluster.demo,
    azurerm_monitor_data_collection_rule.prometheus
  ]
}