locals {
  frontend_files = fileset("${path.cwd}/../../apps/frontend", "**")
  frontend_hash = md5(join("", [for f in local.frontend_files : filemd5("${path.cwd}/../../apps/frontend/${f}")]))
}

# Build and push frontend image
resource "docker_image" "frontend" {
  name = "${data.azurerm_container_registry.acr.login_server}/frontend:latest"

  build {
    context    = "${path.module}/../../apps/frontend"
    dockerfile = "Dockerfile"
    tag        = ["${data.azurerm_container_registry.acr.login_server}/frontend:latest"]
  }

  triggers = {
    dir_sha1 = local.frontend_hash
  }
}

resource "docker_registry_image" "frontend" {
  name = docker_image.frontend.name

  keep_remotely = true
}

# ========================================
# Kubernetes Resources 
# ========================================

resource "kubernetes_namespace_v1" "frontend" {
  metadata {
    name = "frontend-ns"
  }
}

resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.frontend.metadata[0].name
    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app  = "frontend"
          tier = "frontend"
        }
      }

      spec {
        container {
          name  = "streamlit"
          image = "${data.azurerm_container_registry.acr.login_server}/frontend:latest"

          port {
            name           = "http"
            container_port = 8501
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        node_selector = {
          "workload" = "user"
        }

        # Anti-affinity to ensure frontend and backend run on different nodes
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  tier = "backend"
                }
              }
              topology_key = "kubernetes.io/hostname"
              namespaces   = ["backend-ns"]
            }
          }
        }
      }
    }
  }

  depends_on = [docker_registry_image.frontend]
}

resource "kubernetes_service_v1" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.frontend.metadata[0].name
    labels = {
      app = "frontend"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "frontend"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8501
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment_v1.frontend]
}