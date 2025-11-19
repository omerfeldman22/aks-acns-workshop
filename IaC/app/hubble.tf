# Deploy Hubble UI ServiceAccount
resource "kubernetes_service_account_v1" "hubble_ui" {
  metadata {
    name      = "hubble-ui"
    namespace = "kube-system"
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}

# Deploy Hubble UI ClusterRole
resource "kubernetes_cluster_role_v1" "hubble_ui" {
  metadata {
    name = "hubble-ui"
    labels = {
      "app.kubernetes.io/part-of" = "retina"
    }
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["componentstatuses", "endpoints", "namespaces", "nodes", "pods", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["cilium.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}

# Deploy Hubble UI ClusterRoleBinding
resource "kubernetes_cluster_role_binding_v1" "hubble_ui" {
  metadata {
    name = "hubble-ui"
    labels = {
      "app.kubernetes.io/part-of" = "retina"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "hubble-ui"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "hubble-ui"
    namespace = "kube-system"
  }

  depends_on = [kubernetes_cluster_role_v1.hubble_ui, kubernetes_service_account_v1.hubble_ui]
}

# Deploy Hubble UI ConfigMap
resource "kubernetes_config_map_v1" "hubble_ui_nginx" {
  metadata {
    name      = "hubble-ui-nginx"
    namespace = "kube-system"
  }

  data = {
    "default.conf" = <<-EOT
      server {
          listen       8081;
          server_name  localhost;
          root /app;
          index index.html;
          client_max_body_size 1G;
          location / {
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              # CORS
              add_header Access-Control-Allow-Methods "GET, POST, PUT, HEAD, DELETE, OPTIONS";
              add_header Access-Control-Allow-Origin *;
              add_header Access-Control-Max-Age 1728000;
              add_header Access-Control-Expose-Headers content-length,grpc-status,grpc-message;
              add_header Access-Control-Allow-Headers range,keep-alive,user-agent,cache-control,content-type,content-transfer-encoding,x-accept-content-transfer-encoding,x-accept-response-streaming,x-user-agent,x-grpc-web,grpc-timeout;
              if ($request_method = OPTIONS) {
                  return 204;
              }
              # /CORS
              location /api {
                  proxy_http_version 1.1;
                  proxy_pass_request_headers on;
                  proxy_hide_header Access-Control-Allow-Origin;
                  proxy_pass http://127.0.0.1:8090;
              }
              location / {
                  try_files $uri $uri/ /index.html /index.html;
              }
              # Liveness probe
              location /healthz {
                  access_log off;
                  add_header Content-Type text/plain;
                  return 200 'ok';
              }
          }
      }
    EOT
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}

# Deploy Hubble UI Deployment
resource "kubernetes_deployment_v1" "hubble_ui" {
  metadata {
    name      = "hubble-ui"
    namespace = "kube-system"
    labels = {
      "k8s-app"                   = "hubble-ui"
      "app.kubernetes.io/name"    = "hubble-ui"
      "app.kubernetes.io/part-of" = "retina"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "k8s-app" = "hubble-ui"
      }
    }

    template {
      metadata {
        labels = {
          "k8s-app"                   = "hubble-ui"
          "app.kubernetes.io/name"    = "hubble-ui"
          "app.kubernetes.io/part-of" = "retina"
        }
      }

      spec {
        service_account_name            = "hubble-ui"
        automount_service_account_token = true

        container {
          name              = "frontend"
          image             = "mcr.microsoft.com/oss/cilium/hubble-ui:v0.12.2"
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8081
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8081
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8081
            }
          }

          volume_mount {
            name       = "hubble-ui-nginx-conf"
            mount_path = "/etc/nginx/conf.d"
          }

          volume_mount {
            name       = "tmp-dir"
            mount_path = "/tmp"
          }

          termination_message_policy = "FallbackToLogsOnError"
        }

        container {
          name              = "backend"
          image             = "mcr.microsoft.com/oss/cilium/hubble-ui-backend:v0.12.2"
          image_pull_policy = "Always"

          env {
            name  = "EVENTS_SERVER_PORT"
            value = "8090"
          }

          env {
            name  = "FLOWS_API_ADDR"
            value = "hubble-relay:443"
          }

          env {
            name  = "TLS_TO_RELAY_ENABLED"
            value = "true"
          }

          env {
            name  = "TLS_RELAY_SERVER_NAME"
            value = "ui.hubble-relay.cilium.io"
          }

          env {
            name  = "TLS_RELAY_CA_CERT_FILES"
            value = "/var/lib/hubble-ui/certs/hubble-relay-ca.crt"
          }

          env {
            name  = "TLS_RELAY_CLIENT_CERT_FILE"
            value = "/var/lib/hubble-ui/certs/client.crt"
          }

          env {
            name  = "TLS_RELAY_CLIENT_KEY_FILE"
            value = "/var/lib/hubble-ui/certs/client.key"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8090
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8090
            }
          }

          port {
            name           = "grpc"
            container_port = 8090
          }

          volume_mount {
            name       = "hubble-ui-client-certs"
            mount_path = "/var/lib/hubble-ui/certs"
            read_only  = true
          }

          termination_message_policy = "FallbackToLogsOnError"
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        volume {
          name = "hubble-ui-nginx-conf"
          config_map {
            name         = "hubble-ui-nginx"
            default_mode = "0644"
          }
        }

        volume {
          name = "tmp-dir"
          empty_dir {}
        }

        volume {
          name = "hubble-ui-client-certs"
          projected {
            default_mode = "0400"
            sources {
              secret {
                name = "hubble-relay-client-certs"
                items {
                  key  = "tls.crt"
                  path = "client.crt"
                }
                items {
                  key  = "tls.key"
                  path = "client.key"
                }
                items {
                  key  = "ca.crt"
                  path = "hubble-relay-ca.crt"
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account_v1.hubble_ui,
    kubernetes_config_map_v1.hubble_ui_nginx
  ]
}

# Deploy Hubble UI Service
resource "kubernetes_service_v1" "hubble_ui" {
  metadata {
    name      = "hubble-ui"
    namespace = "kube-system"
    labels = {
      "k8s-app"                   = "hubble-ui"
      "app.kubernetes.io/name"    = "hubble-ui"
      "app.kubernetes.io/part-of" = "retina"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "k8s-app" = "hubble-ui"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8081
    }
  }

  depends_on = [kubernetes_deployment_v1.hubble_ui]
}