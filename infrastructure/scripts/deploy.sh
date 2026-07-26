#!/usr/bin/env bash
# Deploys the platform to a given environment via Terraform + Helm.
#
# Usage: ./deploy.sh <dev|staging|prod> [image-tag]
set -euo pipefail

ENVIRONMENT=${1:?Usage: deploy.sh <dev|staging|prod> [image-tag]}
IMAGE_TAG=${2:-latest}
NAMESPACE=${ENVIRONMENT}
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo "==> Provisioning infrastructure for ${ENVIRONMENT} with Terraform"
cd "$ROOT_DIR/infrastructure/terraform/environments/${ENVIRONMENT}"
terraform init -upgrade
terraform apply -auto-approve

CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
echo "==> Updating kubeconfig for cluster ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1

echo "==> Applying Kustomize base + ${ENVIRONMENT} overlay"
kubectl apply -k "$ROOT_DIR/infrastructure/kubernetes/overlays/${ENVIRONMENT}"

echo "==> Installing/upgrading Helm releases"
cd "$ROOT_DIR/infrastructure/kubernetes/helm"
for chart in api-gateway product-service frontend; do
  helm upgrade --install "$chart" "./$chart" \
    --namespace "$NAMESPACE" --create-namespace \
    --set image.tag="$IMAGE_TAG" \
    -f "./$chart/values-${ENVIRONMENT}.yaml"
done

echo "==> Waiting for rollout"
kubectl -n "$NAMESPACE" rollout status deployment/api-gateway --timeout=300s
kubectl -n "$NAMESPACE" rollout status deployment/frontend --timeout=300s

echo "==> Deployment to ${ENVIRONMENT} complete."
