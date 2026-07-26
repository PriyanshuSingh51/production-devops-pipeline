# RDS Backup Policy

| Setting | Value |
|---|---|
| Automated backups | Enabled, daily |
| Backup window | 03:00–04:00 UTC |
| Retention | 30 days (prod), 7 days (staging/dev) |
| Multi-AZ | Enabled in prod (automatic failover) |
| Point-in-time recovery | Supported within the retention window |
| Manual snapshots | Taken before major migrations via `databases/scripts/backup.sh` |
| Cross-region copy | Snapshots replicated to `us-west-2` weekly for DR |

Configured in Terraform: `infrastructure/terraform/modules/rds/main.tf`
(`backup_retention_period`, `backup_window`, `multi_az`).
