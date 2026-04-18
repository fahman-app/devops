# Enable required APIs
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"
}

# Enable Artifact Registry API
resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

# Service account for nodes
resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE nodes"
}

# Grant nodes permission to pull images from Artifact Registry
resource "google_project_iam_member" "nodes_artifact_read" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# GKE cluster (no default node pool)
resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.location
  network                  = "default"
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  # Reduce auth surface; use kubectl via gcloud auth plugin
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  ip_allocation_policy {}

  depends_on = [google_project_service.container]
}

# Managed node pool
resource "google_container_node_pool" "primary_nodes" {
  name     = "primary-pool"
  location = var.location
  cluster  = google_container_cluster.primary.name

  node_config {
    machine_type   = var.machine_type
    service_account = google_service_account.nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      cluster = var.cluster_name
    }
  }

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
