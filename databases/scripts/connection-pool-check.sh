#!/usr/bin/env bash
# Quick health check of HikariCP connection pool usage across services,
# useful before/after a database failover.
set -euo pipefail

NAMESPACE=${1:-production}

for svc in product-service order-service payment-service user-service inventory-service; do
  echo "== $svc =="
  kubectl -n "$NAMESPACE" exec deploy/"$svc" -- \
    curl -s localhost:8080/actuator/metrics/hikaricp.connections.active | \
    jq '.measurements[0].value' 2>/dev/null || echo "  (metrics endpoint unavailable)"
done
