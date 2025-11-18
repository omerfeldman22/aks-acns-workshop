variable "subscription_id" {
  description = "The subscription ID in which the resources will be created."
  sensitive   = true
}

variable "base_name" {
  description = "The base name for the resources (will be used for prefix)."
}

variable "region" {
  description = "The region in which the resources will be created (example: swedencentral)."
  default     = "swedencentral"
}

variable "virtual_network_address_prefix" {
  description = "The address space that is used by the virtual network."
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  type        = string
  description = "The address space that is used by the AKS subnet."
  default     = "10.0.0.0/18"
}

variable "aks_service_cidr" {
  type        = string
  description = "(Optional) The Network Range used by the Kubernetes service."
  default     = "192.168.0.0/20"
}

variable "aks_dns_service_ip" {
  type        = string
  description = "(Optional) IP address within the Kubernetes service address range that will be used by cluster service discovery (kube-dns)."
  default     = "192.168.0.10"
}

variable "pod_cidr" {
  type        = string
  description = "(Optional) The IP address range used for the pods in the Kubernetes cluster."
  default     = "10.244.0.0/16"
}

variable "grafana_major_version" {
  type        = string
  description = "The major version of Grafana to deploy."
  default     = "11"
}