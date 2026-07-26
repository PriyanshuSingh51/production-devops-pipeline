#!/usr/bin/env bash
# Restores an RDS instance from a snapshot into a NEW instance identifier
# (never overwrites the live instance in place).
set -euo pipefail

ENVIRONMENT=${1:?Usage: restore.sh <env> <snapshot-id> <new-instance-id>}
SNAPSHOT_ID=${2:?Usage: restore.sh <env> <snapshot-id> <new-instance-id>}
NEW_INSTANCE_ID=${3:?Usage: restore.sh <env> <snapshot-id> <new-instance-id>}

echo "==> Restoring ${SNAPSHOT_ID} into new instance ${NEW_INSTANCE_ID}"
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "${NEW_INSTANCE_ID}" \
  --db-snapshot-identifier "${SNAPSHOT_ID}" \
  --db-instance-class db.t3.medium

aws rds wait db-instance-available --db-instance-identifier "${NEW_INSTANCE_ID}"
echo "==> Restore complete. Point the application at ${NEW_INSTANCE_ID} after validation,"
echo "    then cut over via the config-server / Kubernetes secret, not by renaming in place."
