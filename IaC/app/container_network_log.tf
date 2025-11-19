resource "kubernetes_manifest" "container_network_log_internal" {
  manifest = {
    apiVersion = "acn.azure.com/v1alpha1"
    kind       = "ContainerNetworkLog"

    metadata = {
      name = "frontend-to-backend"
    }

    spec = {
      includefilters = [
        {
          name = "frontend-to-backend"
          from = {
            labelSelector = {
              matchLabels = {
                "app" = "frontend"
              }
            }
          }
          to = {
            labelSelector = {
              matchLabels = {
                "app" = "backend"
              }
            }
          }
          protocol = ["tcp", "udp", "dns"]
          verdict  = ["forwarded", "dropped"]
        }
      ]
    }
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_manifest" "container_network_log_external" {
  manifest = {
    apiVersion = "acn.azure.com/v1alpha1"
    kind       = "ContainerNetworkLog"

    metadata = {
      name = "any-to-backend"
    }

    spec = {
      includefilters = [
        {
          name = "any-to-backend"
          to = {
            labelSelector = {
              matchLabels = {
                "app" = "frontend"
              }
            }
          }
          protocol = ["tcp", "udp", "dns"]
          verdict  = ["forwarded", "dropped"]
        }
      ]
    }
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}
