locals {
  backend_files  = fileset("${path.cwd}/../../apps/backend", "**")
  backend_hash  = md5(join("", [for f in local.backend_files : filemd5("${path.cwd}/../../apps/backend/${f}")]))
}

# Build and push backend image
resource "docker_image" "backend" {
  name = "${data.azurerm_container_registry.acr.login_server}/backend:latest"

  build {
    context    = "${path.module}/../../apps/backend"
    dockerfile = "Dockerfile"
    tag        = ["${data.azurerm_container_registry.acr.login_server}/backend:latest"]
  }

  triggers = {
    dir_sha1 = local.backend_hash
  }
}

resource "docker_registry_image" "backend" {
  name = docker_image.backend.name

  keep_remotely = true
}

# ========================================
# Kubernetes Resources 
# ========================================

resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend-ns"
  }
}

resource "kubernetes_deployment_v1" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.backend.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app  = "backend"
          tier = "backend"
        }
      }

      spec {
        container {
          name              = "fastapi"
          image             = "${data.azurerm_container_registry.acr.login_server}/backend:latest"
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8000
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        node_selector = {
          "workload" = "user"
        }

        # Anti-affinity to ensure backend and frontend run on different nodes
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  tier = "frontend"
                }
              }
              topology_key = "kubernetes.io/hostname"
              namespaces   = ["frontend-ns"]
            }
          }
        }
      }
    }
  }

  depends_on = [docker_registry_image.backend]
}

resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.backend.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "backend"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment_v1.backend]
}