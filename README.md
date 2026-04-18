# DevOps — GKE Infrastructure & Kubernetes Templates

This repository contains the infrastructure-as-code and Kubernetes manifest **examples** for deploying applications on Google Kubernetes Engine (GKE).

## Repository Structure

```
├── terraform/          # GCP infrastructure provisioned with Terraform
│   ├── provider.tf     # Provider & backend configuration
│   ├── variables.tf    # Input variable definitions
│   ├── terraform.tfvars# Variable values (project-specific)
│   ├── main.tf         # Core resources (VPC, GKE, PSC, etc.)
│   └── outputs.tf      # Outputs (cluster name, endpoint, etc.)
│
├── kubernetes/         # Example Kubernetes manifests (templates)
│   ├── deployment.yaml # Deployment template
│   ├── service.yaml    # ClusterIP Service template
│   ├── ingress.yaml    # NGINX Ingress template
│   └── hpa.yaml        # HorizontalPodAutoscaler template
```

## Terraform — Infrastructure

Terraform provisions the following GCP resources:

| Resource | Description |
|---|---|
| **VPC** | Custom-mode VPC (`10.0.0.0/16` by default) with no auto-created subnets |
| **Public Subnet** | `/19` subnet for public-facing resources |
| **Private Subnet** | `/20` subnet with Private Google Access enabled; used by GKE |
| **Cloud Router & NAT** | Provides outbound internet access for resources on the private subnet |
| **PSC Endpoint** | Private Service Connect endpoint for Cloud Storage — routes all `storage.googleapis.com` traffic privately through the VPC |
| **Private DNS** | DNS zone mapping `storage.googleapis.com` to the PSC internal IP |
| **GKE Cluster** | Regional cluster on the private subnet, default node pool removed |
| **Node Pool** | Managed, auto-scaling node pool with auto-repair and auto-upgrade |
| **Service Account** | Dedicated node SA with Artifact Registry reader permissions |
| **API Enablement** | Automatically enables the Container and Artifact Registry APIs |

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.4.0
- `gcloud` CLI authenticated with a project that has billing enabled
- A GCS bucket for Terraform remote state (configured via `-backend-config`)

### Usage

```bash
cd terraform

# Initialise (provide your state bucket)
terraform init -backend-config="bucket=YOUR_STATE_BUCKET"

# Review the plan
terraform plan

# Apply
terraform apply
```

### Configuration

All tuneable values live in `terraform.tfvars`. See `variables.tf` for descriptions and defaults.

| Variable | Description | Default |
|---|---|---|
| `project_id` | GCP project ID | — |
| `region` | GCP region | — |
| `location` | GKE location (zone or region) | — |
| `cluster_name` | Cluster name | `app-cluster` |
| `machine_type` | Node machine type | `e2-standard-2` |
| `min_nodes` / `max_nodes` | Autoscaling bounds | 1 / 3 |
| `vpc_cidr` | VPC CIDR | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDR | `10.0.0.0/19` |
| `private_subnet_cidr` | Private subnet CIDR | `10.0.32.0/20` |

## Kubernetes — Example Manifests

> **⚠️ The files in `kubernetes/` are example templates, not ready-to-apply manifests.**
> They use `${VARIABLE}` placeholders that must be replaced with actual values before use (e.g. via `envsubst`, a CI/CD pipeline, or Helm).

### Placeholder Reference

| Placeholder | Description |
|---|---|
| `${SERVICE_NAME}` | Application / microservice name |
| `${NAMESPACE_NAME}` | Target Kubernetes namespace |
| `${DOCKER_IMAGE_TAG}` | Full container image reference |
| `${SERVICE_PORT}` | Port the container listens on |
| `${NUM_REPLICAS}` | Initial replica count |
| `${CPU_REQUEST}` / `${CPU_LIMIT}` | CPU resource request / limit |
| `${MEMORY_REQUEST}` / `${MEMORY_LIMIT}` | Memory resource request / limit |
| `${SA_NAME}` | Kubernetes ServiceAccount name |
| `${MINREPLICAS}` / `${MAXREPLICAS}` | HPA min / max replicas |

### Manifests

- **deployment.yaml** — Deployment with resource requests/limits, secret volume mounts (GKE Secret Store CSI), and environment variable injection.
- **service.yaml** — ClusterIP Service exposing port 80 → container target port.
- **ingress.yaml** — NGINX Ingress with two host rules (TLS sections commented out, ready to enable).
- **hpa.yaml** — HorizontalPodAutoscaler targeting 50 % average CPU utilisation.

### Example: Rendering Templates

```bash
export SERVICE_NAME=my-app
export NAMESPACE_NAME=production
export DOCKER_IMAGE_TAG=us-central1-docker.pkg.dev/my-project/repo/my-app:latest
export SERVICE_PORT=8080
export NUM_REPLICAS=2
# ... set remaining variables

envsubst < kubernetes/deployment.yaml | kubectl apply -f -
```
