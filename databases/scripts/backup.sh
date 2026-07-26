#!/usr/bin/env bash
# Manual on-demand RDS snapshot. For scheduled backups, see the automated
# RDS backup window configured in Terraform and the Velero schedule in
# databases/backups/velero-schedule.yaml.
set -euo pipefail

ENVIRONMENT=${1:?Usage: backup.sh <dev|staging|prod>}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_ID="ecommerce-${ENVIRONMENT}-manual-${TIMESTAMP}"

echo "==> Creating RDS snapshot: ${SNAPSHOT_ID}"
aws rds create-db-snapshot \
  --db-instance-identifier "ecommerce-${ENVIRONMENT}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}"

aws rds wait db-snapshot-available --db-snapshot-identifier "${SNAPSHOT_ID}"
echo "==> Snapshot ${SNAPSHOT_ID} is available."
