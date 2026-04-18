variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (e.g., us-central1)"
  type        = string
}

variable "location" {
  description = "GKE location (zone or regional, e.g., us-central1 or us-central1-a)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "app-cluster"
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "min_nodes" {
  description = "Minimum nodes in autoscaling"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum nodes in autoscaling"
  type        = number
  default     = 3
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the workload identity binding"
  type        = string
  default     = "default"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name for the workload identity binding"
  type        = string
  default     = "app-sa"
}
