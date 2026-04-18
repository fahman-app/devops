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

# Grant nodes the default node service account role (logging, monitoring, HPA)
resource "google_project_iam_member" "nodes_default_sa" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
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

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {}
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

    workload_metadata_config {
      mode = "GKE_METADATA"
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

# Workload Identity service account for GKE workloads
resource "google_service_account" "workload" {
  account_id   = "${var.cluster_name}-workload"
  display_name = "GKE Workload Identity"
}

# Allow the workload GSA to access Secret Manager
resource "google_project_iam_member" "workload_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.workload.email}"
}

# Bind Kubernetes ServiceAccount to the GCP ServiceAccount
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

# Service account for External Secrets Operator
resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets-sa"
  display_name = "External Secrets Operator"
}

# Grant External Secrets access to Secret Manager
resource "google_project_iam_member" "external_secrets_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# Bind External Secrets K8s SA to GCP SA via Workload Identity
resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
}

# Global static IP for the ed frontend ingress
resource "google_compute_global_address" "fahman_ed_ip" {
  name    = "fahman-ed-ip"
  project = var.project_id
}

# Global static IP for the app frontend ingress
resource "google_compute_global_address" "fahman_app_ip" {
  name    = "fahman-app-ip"
  project = var.project_id
}

# Global static IP for the ed backend ingress
resource "google_compute_global_address" "fahman_ed_be_ip" {
  name    = "fahman-ed-be-ip"
  project = var.project_id
}

resource "google_compute_global_address" "fahman_app_be_ip" {
  name    = "fahman-app-be-ip"
  project = var.project_id
}
