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
