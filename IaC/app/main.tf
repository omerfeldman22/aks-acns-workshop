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

# Deploy Retina Flow Log CRD
resource "kubernetes_manifest" "retina_flow_log" {
  manifest = {
    apiVersion = "acn.azure.com/v1alpha1"
    kind       = "RetinaNetworkFlowLog"
    
    metadata = {
      name = "demo-retinanetworkflowlog"
    }
    
    spec = {
      includefilters = [
        {
          name = "sample-filter"
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

# Deploy AMA Metrics Settings ConfigMap
resource "kubernetes_config_map_v1" "ama_metrics_settings" {
  metadata {
    name      = "ama-metrics-settings-configmap"
    namespace = "kube-system"
  }

  data = {
    "schema-version" = "v1"
    "config-version" = "ver1"
    
    "prometheus-collector-settings" = <<-EOT
      cluster_alias = ""
      https_config = true
    EOT
    
    "default-scrape-settings-enabled" = <<-EOT
      kubelet = true
      coredns = false
      cadvisor = true
      kubeproxy = false
      apiserver = false
      kubestate = true
      nodeexporter = true
      windowsexporter = false
      windowskubeproxy = false
      kappiebasic = true
      networkobservabilityRetina = true
      networkobservabilityHubble = true
      networkobservabilityCilium = true
      prometheuscollectorhealth = false
      controlplane-apiserver = true
      controlplane-cluster-autoscaler = false
      controlplane-node-auto-provisioning = false
      controlplane-kube-scheduler = false
      controlplane-kube-controller-manager = false
      controlplane-etcd = true
      acstor-capacity-provisioner = true
      acstor-metrics-exporter = true
      local-csi-driver = true
      ztunnel = false
      istio-cni = false
      waypoint-proxy = false
    EOT
    
    "pod-annotation-based-scraping" = <<-EOT
      podannotationnamespaceregex = ""
    EOT
    
    "default-targets-metrics-keep-list" = <<-EOT
      kubelet = ""
      coredns = ""
      cadvisor = ""
      kubeproxy = ""
      apiserver = ""
      kubestate = ""
      nodeexporter = ""
      windowsexporter = ""
      windowskubeproxy = ""
      podannotations = ""
      kappiebasic = ""
      networkobservabilityRetina = ""
      networkobservabilityHubble = "hubble.*"
      networkobservabilityCilium = ""
      controlplane-apiserver = ""
      controlplane-cluster-autoscaler = ""
      controlplane-node-auto-provisioning = ""
      controlplane-kube-scheduler = ""
      controlplane-kube-controller-manager = ""
      controlplane-etcd = ""
      acstor-capacity-provisioner = ""
      acstor-metrics-exporter = ""
      local-csi-driver = ""
      ztunnel = ""
      istio-cni = ""
      waypoint-proxy = ""
      minimalingestionprofile = true
    EOT
    
    "default-targets-scrape-interval-settings" = <<-EOT
      kubelet = "30s"
      coredns = "30s"
      cadvisor = "30s"
      kubeproxy = "30s"
      apiserver = "30s"
      kubestate = "30s"
      nodeexporter = "30s"
      windowsexporter = "30s"
      windowskubeproxy = "30s"
      kappiebasic = "30s"
      networkobservabilityRetina = "30s"
      networkobservabilityHubble = "30s"
      networkobservabilityCilium = "30s"
      prometheuscollectorhealth = "30s"
      acstor-capacity-provisioner = "30s"
      acstor-metrics-exporter = "30s"
      local-csi-driver = "30s"
      ztunnel = "30s"
      istio-cni = "30s"
      waypoint-proxy = "30s"
      podannotations = "30s"
    EOT
    
    "debug-mode" = <<-EOT
      enabled = false
    EOT
  }

  depends_on = [data.azurerm_kubernetes_cluster.aks]
}

# Output the Hubble UI service external IP (when available)
output "hubble_ui_external_ip" {
  description = "External IP address for Hubble UI LoadBalancer service"
  value       = try(kubernetes_service_v1.hubble_ui.status[0].load_balancer[0].ingress[0].ip, "Pending...")
}


# ========================================
# Docker Images Build and Push
# ========================================

# Get hash of frontend directory for change detection
locals {
  frontend_files = fileset("${path.cwd}/../../apps/frontend", "**")
  backend_files  = fileset("${path.cwd}/../../apps/backend", "**")
  
  frontend_hash = md5(join("", [for f in local.frontend_files : filemd5("${path.cwd}/../../apps/frontend/${f}")]))
  backend_hash  = md5(join("", [for f in local.backend_files : filemd5("${path.cwd}/../../apps/backend/${f}")]))
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
# Kubernetes Resources - Frontend
# ========================================

resource "kubernetes_namespace_v1" "frontend" {
  metadata {
    name = "frontend-ns"
    labels = {
      app = "network-policy-test"
    }
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

        # Anti-affinity to keep frontend on different node from backend
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "tier"
                    operator = "In"
                    values   = ["backend"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
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

# ========================================
# Kubernetes Resources - Backend
# ========================================

resource "kubernetes_namespace_v1" "backend" {
  metadata {
    name = "backend-ns"
    labels = {
      app = "network-policy-test"
    }
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

        # Anti-affinity to keep backend on different node from frontend
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "tier"
                    operator = "In"
                    values   = ["frontend"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
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

# ========================================
# Outputs
# ========================================

output "frontend_external_ip" {
  description = "External IP address for Frontend LoadBalancer service"
  value       = try(kubernetes_service_v1.frontend.status[0].load_balancer[0].ingress[0].ip, "Pending...")
}

output "backend_service_url" {
  description = "Internal URL for backend service"
  value       = "http://backend.backend-ns.svc.cluster.local:8000"
}
