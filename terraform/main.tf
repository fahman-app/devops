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

# Static internal IP for PSC endpoint
resource "google_compute_address" "psc_storage" {
  name         = "${var.cluster_name}-psc-storage"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.private.id
  region       = var.region
  purpose      = "GCE_ENDPOINT"
}

# PSC forwarding rule targeting Cloud Storage
resource "google_compute_forwarding_rule" "psc_storage" {
  name                  = "${var.cluster_name}-psc-storage"
  region                = var.region
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_address.psc_storage.id
  load_balancing_scheme = ""
  target                = "vpc-sc"
  allow_psc_global_access = true
}

# DNS zone to route *.googleapis.com to the PSC endpoint
resource "google_dns_managed_zone" "psc_storage" {
  name        = "${var.cluster_name}-psc-storage"
  dns_name    = "storage.googleapis.com."
  visibility  = "private"

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
  rrdatas      = [google_compute_address.psc_storage.address]
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
