#!/usr/bin/env bash
# Installs/updates the kube-prometheus-stack (Prometheus, Grafana,
# Alertmanager) and Loki via Helm, then applies our custom dashboards,
# alert rules, and datasources on top.
set -euo pipefail

NAMESPACE=monitoring
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  -f "$ROOT_DIR/monitoring/prometheus/prometheus.yml" \
  --set alertmanager.configFromSecret=false

helm upgrade --install loki grafana/loki-stack \
  --namespace "$NAMESPACE" \
  -f "$ROOT_DIR/monitoring/loki/loki-config.yaml"

echo "==> Applying custom Prometheus alert rules"
kubectl apply -n "$NAMESPACE" -f "$ROOT_DIR/monitoring/prometheus/alerts/"
kubectl apply -n "$NAMESPACE" -f "$ROOT_DIR/monitoring/prometheus/rules/"

echo "==> Applying Grafana dashboard/datasource provisioning"
kubectl create configmap grafana-dashboards \
  --from-file="$ROOT_DIR/monitoring/grafana/dashboards" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Monitoring stack ready. Port-forward Grafana with:"
echo "    kubectl -n $NAMESPACE port-forward svc/kube-prometheus-stack-grafana 3000:80"
