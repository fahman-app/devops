# DevOps — GKE Infrastructure & Kubernetes Templates

This repository contains the infrastructure-as-code and Kubernetes manifest **examples** for deploying applications on Google Kubernetes Engine (GKE).

## Repository Structure

```
├── terraform/              # GCP infrastructure provisioned with Terraform
│   ├── provider.tf         # Provider & backend configuration
│   ├── variables.tf        # Input variable definitions
│   ├── terraform.tfvars    # Variable values (project-specific)
│   ├── main.tf             # Core resources (VPC, GKE, PSC, Workload Identity, etc.)
│   └── outputs.tf          # Outputs (cluster name, endpoint, etc.)
│
├── kubernetes/             # Example Kubernetes manifests (templates)
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # ClusterIP Service template
│   ├── ingress.yaml        # GCE Ingress template
│   └── hpa.yaml            # HorizontalPodAutoscaler template
```

## Terraform — Infrastructure

Terraform provisions the following GCP resources:

### Networking

| Resource               | Description                                                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **VPC**                | Custom-mode VPC (`10.0.0.0/16` by default) with no auto-created subnets                                                    |
| **Public Subnet**      | `/19` subnet for public-facing resources                                                                                   |
| **Private Subnet**     | `/20` subnet with Private Google Access enabled; used by GKE                                                               |
| **Cloud Router & NAT** | Provides outbound internet access for resources on the private subnet                                                      |
| **PSC Endpoint**       | Private Service Connect endpoint for Cloud Storage — routes all `storage.googleapis.com` traffic privately through the VPC |
| **Private DNS**        | DNS zone mapping `storage.googleapis.com` to the PSC internal IP                                                           |
| **Global Static IPs**  | Reserved IPs for application ingresses (fahman-app, fahman-ed, and their backends)                                         |

### GKE

| Resource                 | Description                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------- |
| **GKE Cluster**          | Regional cluster on the private subnet with Workload Identity enabled                 |
| **Node Pool**            | Managed, auto-scaling node pool with auto-repair, auto-upgrade, and GKE metadata mode |
| **Node Service Account** | Dedicated SA with Artifact Registry reader and default node permissions               |

### Workload Identity & Secrets

| Resource                 | Description                                                                                         |
| ------------------------ | --------------------------------------------------------------------------------------------------- |
| **Workload Identity SA** | GCP service account bound to a Kubernetes ServiceAccount for Secret Manager access                  |
| **External Secrets SA**  | Dedicated SA for External Secrets Operator with Secret Manager access and Workload Identity binding |

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

| Variable                  | Description                              | Default         |
| ------------------------- | ---------------------------------------- | --------------- |
| `project_id`              | GCP project ID                           | —               |
| `region`                  | GCP region                               | —               |
| `location`                | GKE location (zone or region)            | —               |
| `cluster_name`            | Cluster name                             | `app-cluster`   |
| `machine_type`            | Node machine type                        | `e2-standard-2` |
| `min_nodes` / `max_nodes` | Autoscaling bounds                       | 1 / 3           |
| `vpc_cidr`                | VPC CIDR                                 | `10.0.0.0/16`   |
| `public_subnet_cidr`      | Public subnet CIDR                       | `10.0.0.0/19`   |
| `private_subnet_cidr`     | Private subnet CIDR                      | `10.0.32.0/20`  |
| `k8s_namespace`           | Namespace for Workload Identity binding  | `default`       |
| `k8s_service_account`     | K8s ServiceAccount for Workload Identity | `app-sa`        |

## Kubernetes — Example Manifests

> **⚠️ The files in `kubernetes/` are example templates, not ready-to-apply manifests.**
> They use `${VARIABLE}` placeholders that must be replaced with actual values before use (e.g. via `envsubst`, a CI/CD pipeline, or Helm).

### Placeholder Reference

| Placeholder                             | Description                     |
| --------------------------------------- | ------------------------------- |
| `${SERVICE_NAME}`                       | Application / microservice name |
| `${NAMESPACE_NAME}`                     | Target Kubernetes namespace     |
| `${DOCKER_IMAGE_TAG}`                   | Full container image reference  |
| `${SERVICE_PORT}`                       | Port the container listens on   |
| `${NUM_REPLICAS}`                       | Initial replica count           |
| `${CPU_REQUEST}` / `${CPU_LIMIT}`       | CPU resource request / limit    |
| `${MEMORY_REQUEST}` / `${MEMORY_LIMIT}` | Memory resource request / limit |
| `${SA_NAME}`                            | Kubernetes ServiceAccount name  |
| `${MINREPLICAS}` / `${MAXREPLICAS}`     | HPA min / max replicas          |

### Manifests

- **deployment.yaml** — Deployment with resource requests/limits, secret volume mounts (Secrets Store CSI driver), and environment variable injection.
- **service.yaml** — ClusterIP Service exposing port 80 → container target port.
- **ingress.yaml** — GCE Ingress with host rules for `app.fahman.com` and `ed.fahman.com` (TLS sections commented out, ready to enable).
- **hpa.yaml** — HorizontalPodAutoscaler targeting 50% average CPU utilisation.

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

## GitHub Environment Setup

The CI/CD workflows run under a GitHub Environment called **`Staging`**. You must configure the following **secrets** and **variables** in your repository settings under **Settings → Environments → Staging**.

### Secrets

| Secret                  | Description                                                          | Example                                                |
| ----------------------- | -------------------------------------------------------------------- | ------------------------------------------------------ |
| `GOOGLE_CREDENTIALS`    | GCP service account key JSON (base64 or raw) used for authentication | `{"type":"service_account",...}`                       |
| `GCP_PROJECT_ID`        | GCP project ID                                                       | `fahman`                                               |
| `GCP_REGION`            | GCP region                                                           | `europe-west3`                                         |
| `GCP_LOCATION`          | GKE cluster location (zone or region)                                | `europe-west3`                                         |
| `GKE_CLUSTER_NAME`      | Name of the GKE cluster                                              | `test-cluster`                                         |
| `GKE_MACHINE_TYPE`      | Node machine type (optional, defaults to `e2-standard-2`)            | `e2-standard-2`                                        |
| `GKE_MIN_NODES`         | Minimum node count (optional, defaults to `1`)                       | `1`                                                    |
| `GKE_MAX_NODES`         | Maximum node count (optional, defaults to `3`)                       | `3`                                                    |
| `TF_BACKEND_BUCKET`     | GCS bucket name for Terraform remote state                           | `my-tf-state-bucket`                                   |
| `TF_BACKEND_PREFIX`     | Prefix/path inside the state bucket                                  | `staging/terraform.tfstate`                            |
| `GCP_WORKLOAD_SA_EMAIL` | Email of the Workload Identity GCP service account                   | `test-cluster-workload@fahman.iam.gserviceaccount.com` |
| `GCP_SECRET_NAME`       | GCP Secret Manager secret name used by External Secrets              | `my-app-secrets`                                       |

### Variables

| Variable         | Description                                           | Example      |
| ---------------- | ----------------------------------------------------- | ------------ |
| `SERVICE_NAME`   | Application / microservice name used in K8s manifests | `fahman-app` |
| `NAMESPACE_NAME` | Kubernetes namespace to deploy into                   | `default`    |
| `SA_NAME`        | Kubernetes ServiceAccount name for the workload       | `app-sa`     |
