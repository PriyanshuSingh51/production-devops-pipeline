# Disaster Recovery Plan

## Objectives

| Metric | Critical services | Non-critical services |
|---|---|---|
| **RPO** (Recovery Point Objective) | 15 minutes | 4 hours |
| **RTO** (Recovery Time Objective) | 30 minutes | 4 hours |

Complete system recovery (worst case, full region loss): **RTO 8 hours**.

## Backup Strategy

| Asset | Method | Schedule | Retention |
|---|---|---|---|
| RDS PostgreSQL | Automated snapshots + continuous transaction log backup | Daily full (03:00 UTC) + continuous | 30 days (prod), cross-region copy weekly |
| Kubernetes cluster state | Velero | Daily (03:00 UTC) | 30 days |
| Application config | Git (this repository) | Every commit | Indefinite |
| S3 application data / uploads | Versioning + lifecycle policy | Continuous | 365 days (Glacier after 90) |
| Kafka topics | Replication factor 2–3 across brokers | Continuous | Per-topic retention (7–30 days) |

See `databases/backups/` for the Velero schedule and RDS backup policy, and
`infrastructure/scripts/backup.sh` / `databases/scripts/backup.sh` for on-demand backups.

## Multi-Region Design

```
Primary Region: us-east-1        Secondary Region: us-west-2
──────────────────────────       ──────────────────────────
100% production traffic          Standby — pre-warmed
3 AZs, EKS + RDS Multi-AZ        Read replica of RDS
Route53 health-checked           Application instances scaled to 1 (warm)
```

- **Route53** health checks the primary region's ALB every 30 seconds.
- On sustained failure, Route53 failover routing shifts traffic to the secondary region's ALB.
- The secondary region's RDS read replica is promoted to a standalone primary as part of the
  failover runbook (not automatic — see below).
- **Failback** to the primary region is always a deliberate, manual action taken only after the
  root cause is resolved and validated in a game-day-style check.

## Failover Runbook (Region Loss)

1. **Detect**: PagerDuty alert from Route53 health check failure / Alertmanager critical alerts firing across the board.
2. **Confirm**: on-call engineer verifies it's a genuine regional outage (check AWS Health Dashboard), not a transient blip.
3. **Promote database**: promote the `us-west-2` RDS read replica to a standalone primary.
   ```bash
   aws rds promote-read-replica --db-instance-identifier ecommerce-prod-west-replica
   ```
4. **Scale up standby services**: `kubectl -n production scale deployment --all --replicas=<prod-level>` in the west cluster, or `helm upgrade` with `values-production.yaml`.
5. **Repoint configuration**: update `config-server` / Kubernetes Secrets to point at the newly-promoted database endpoint.
6. **Confirm DNS failover**: verify Route53 is now resolving to the west ALB (`dig app.ecommerce.com`).
7. **Verify**: run smoke tests against the west environment.
8. **Communicate**: status page update + Slack `#platform-incidents`.
9. **Post-incident**: write the incident report within 48 hours; schedule the failback.

## Failback Runbook

1. Confirm the primary region is healthy (AWS Health Dashboard clear, infra validated).
2. Re-establish `us-east-1` as a read replica of the now-primary `us-west-2` database.
3. Let it fully catch up (`ReplicaLag` metric ≈ 0).
4. During a low-traffic window, promote `us-east-1` back to primary and repoint `config-server`.
5. Shift Route53 weighting back to 100% `us-east-1`.
6. Scale `us-west-2` back down to standby levels.

## Testing

- **Quarterly DR drills**: simulate a region failure in a non-production account; time the team
  against the RTO/RPO targets above; document gaps.
- **Automated recovery testing**: a scheduled job restores the latest RDS snapshot into a
  scratch instance and runs a data-integrity check monthly (see `databases/scripts/restore.sh`).
- **Backup restoration drill**: quarterly, restore a Velero backup into a throwaway namespace
  and verify all resources come back cleanly.

## Communication Plan

| Audience | Channel | Trigger |
|---|---|---|
| On-call engineer | PagerDuty | Any critical alert |
| Platform team | Slack `#platform-incidents` | Incident declared |
| Customers | Status page | Customer-visible impact > 5 minutes |
| Leadership | Email/Slack DM | RTO target at risk of being missed |

## Related Documents

- [`documentation/architecture.md`](architecture.md) — infrastructure and monitoring overview
- [`documentation/runbooks/`](runbooks) — scenario-specific runbooks
- [`databases/backups/rds-backup-policy.md`](../databases/backups/rds-backup-policy.md)
