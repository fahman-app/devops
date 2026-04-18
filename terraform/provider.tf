terraform {
  required_version = ">= 1.4.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
  # Use GCS for remote Terraform state; values are passed via -backend-config in CI
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}
