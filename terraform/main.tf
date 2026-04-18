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

# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Public subnet (/19 = 8190 hosts)
resource "google_compute_subnetwork" "public" {
  name          = "${var.cluster_name}-public"
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.public_subnet_cidr
  region        = var.region
}

# Private subnet (/20 = 4094 hosts)
resource "google_compute_subnetwork" "private" {
  name                     = "${var.cluster_name}-private"
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.private_subnet_cidr
  region                   = var.region
  private_ip_google_access = true
}

# Cloud Router (needed for NAT)
resource "google_compute_router" "router" {
  name    = "${var.cluster_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

# Cloud NAT (allows private subnet egress)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Global internal IP for PSC endpoint
resource "google_compute_global_address" "psc_storage" {
  name         = "${var.cluster_name}-psc-storage"
  address_type = "INTERNAL"
  address      = "10.0.48.1"
  network      = google_compute_network.vpc.id
  purpose      = "PRIVATE_SERVICE_CONNECT"
}

# PSC forwarding rule targeting Google APIs (global)
# Name must be 8-20 lowercase alphanumeric chars, starting with a letter, no hyphens
resource "google_compute_global_forwarding_rule" "psc_storage" {
  name                    = "pscstoragefwr01"
  network                 = google_compute_network.vpc.id
  ip_address              = google_compute_global_address.psc_storage.id
  load_balancing_scheme   = ""
  target                  = "vpc-sc"
}

# Wait for DNS API to propagate
resource "time_sleep" "dns_api_ready" {
  depends_on      = [google_project_service.dns]
  create_duration = "30s"
}

# DNS zone to route *.googleapis.com to the PSC endpoint
resource "google_dns_managed_zone" "psc_storage" {
  name       = "${var.cluster_name}-psc-storage"
  dns_name   = "storage.googleapis.com."

  depends_on = [time_sleep.dns_api_ready]
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_dns_record_set" "psc_storage" {
  managed_zone = google_dns_managed_zone.psc_storage.name
  name         = "storage.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc_storage.address]
}

resource "google_dns_record_set" "psc_storage_wildcard" {
  managed_zone = google_dns_managed_zone.psc_storage.name
  name         = "*.storage.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["storage.googleapis.com."]
}

# GKE cluster (no default node pool)
resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.location
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.private.name
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
