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
