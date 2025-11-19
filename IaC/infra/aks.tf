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
    network_data_plane  = "cilium"

    service_cidr   = var.aks_service_cidr
    dns_service_ip = var.aks_dns_service_ip
    pod_cidr       = var.pod_cidr

    load_balancer_sku = "standard"

    ip_versions = ["IPv4"]

    load_balancer_profile {
      managed_outbound_ip_count = 1
    }
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  lifecycle {
    ignore_changes = [
      network_profile[0].advanced_networking,
      microsoft_defender,
      oms_agent
    ]
  }

  depends_on = [
    azurerm_subnet.aks,
    azurerm_log_analytics_workspace.demo
  ]
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

# This process involves null_resource because as of the terraform implementation date (18/11/2025), the high log scale mode enablement is only supported via Azure CLI.
resource "null_resource" "enable_oms_and_flow_logs" {
  provisioner "local-exec" {
    command = "az aks enable-addons -a monitoring --enable-high-log-scale-mode -g ${azurerm_resource_group.demo.name} -n ${azurerm_kubernetes_cluster.demo.name} --workspace-resource-id ${azurerm_log_analytics_workspace.demo.id}"
  }

  depends_on = [
    azurerm_kubernetes_cluster.demo,
    azurerm_log_analytics_workspace.demo
  ]
}

# Enable ACNS using AzAPI provider because it's not yet supported in azurerm provider (18/11/2025)
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

      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricLabelsAllowlist      = ""
            metricAnnotationsAllowList = ""
          }
        }
      }
      
      addonProfiles = {
        omsagent = {
          enabled = true
          config = {
            logAnalyticsWorkspaceResourceID = azurerm_log_analytics_workspace.demo.id
            useAADAuth                      = "true"
            enableRetinaNetworkFlags        = "True"
          }
        }
      }
    }
  }

  depends_on = [null_resource.enable_oms_and_flow_logs]
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