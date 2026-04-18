#!/usr/bin/env bash
set -euo pipefail

REPO="fahman-app/devops"
ENV="Staging"

echo "Setting secrets for ${REPO} environment: ${ENV}"

# Secrets (from terraform.tfvars values)
gh secret set GCP_PROJECT_ID   --repo "$REPO" --env "$ENV" --body "fahman"
gh secret set GCP_REGION       --repo "$REPO" --env "$ENV" --body "europe-west3"
gh secret set GCP_LOCATION     --repo "$REPO" --env "$ENV" --body "europe-west3"
gh secret set GKE_CLUSTER_NAME --repo "$REPO" --env "$ENV" --body "test-cluster"
gh secret set GKE_MACHINE_TYPE --repo "$REPO" --env "$ENV" --body "e2-standard-2"
gh secret set GKE_MIN_NODES    --repo "$REPO" --env "$ENV" --body "1"
gh secret set GKE_MAX_NODES    --repo "$REPO" --env "$ENV" --body "3"
gh secret set TF_BACKEND_BUCKET --repo "$REPO" --env "$ENV" --body "fahman-terraform"
gh secret set TF_BACKEND_PREFIX --repo "$REPO" --env "$ENV" --body "root"

echo ""
echo "✅ All secrets set. GOOGLE_CREDENTIALS was already added manually."
