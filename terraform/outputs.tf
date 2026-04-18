output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "cluster_location" {
  value       = google_container_cluster.primary.location
  description = "GKE cluster location"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE API server endpoint"
}

output "node_service_account" {
  value       = google_service_account.nodes.email
  description = "Email of the node service account"
}

output "workload_service_account" {
  value       = google_service_account.workload.email
  description = "Email of the workload identity service account"
}

output "fahman_ed_ip" {
  value       = google_compute_global_address.fahman_ed_ip.address
  description = "Global static IP for the ed frontend ingress"
}

output "fahman_app_ip" {
  value       = google_compute_global_address.fahman_app_ip.address
  description = "Global static IP for the app frontend ingress"
}

output "fahman_ed_be_ip" {
  value       = google_compute_global_address.fahman_ed_be_ip.address
  description = "Global static IP for the ed backend ingress"
}

output "fahman_app_be_ip" {
  value       = google_compute_global_address.fahman_app_be_ip.address
  description = "Global static IP for the app backend ingress"
}
