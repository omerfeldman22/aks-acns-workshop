# Output the Hubble UI service external IP (when available)
output "hubble_ui_external_ip" {
  description = "External IP address for Hubble UI LoadBalancer service"
  value       = try(kubernetes_service_v1.hubble_ui.status[0].load_balancer[0].ingress[0].ip, "Pending...")
}

output "frontend_external_ip" {
  description = "External IP address for Frontend LoadBalancer service"
  value       = try(kubernetes_service_v1.frontend.status[0].load_balancer[0].ingress[0].ip, "Pending...")
}