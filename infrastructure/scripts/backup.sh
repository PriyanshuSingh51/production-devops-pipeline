#!/usr/bin/env bash
# Triggers an on-demand backup: RDS snapshot + Velero cluster backup.
#
# Usage: ./backup.sh <dev|staging|prod>
set -euo pipefail

ENVIRONMENT=${1:?Usage: backup.sh <dev|staging|prod>}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "==> Taking RDS snapshot for ecommerce-${ENVIRONMENT}"
aws rds create-db-snapshot \
  --db-instance-identifier "ecommerce-${ENVIRONMENT}" \
  --db-snapshot-identifier "ecommerce-${ENVIRONMENT}-manual-${TIMESTAMP}"

echo "==> Triggering Velero cluster backup"
velero backup create "ecommerce-${ENVIRONMENT}-manual-${TIMESTAMP}" \
  --include-namespaces "${ENVIRONMENT}" \
  --wait

echo "==> Backup ${TIMESTAMP} complete for ${ENVIRONMENT}."
