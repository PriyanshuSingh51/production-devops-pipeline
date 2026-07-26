# Runbook: Database Failover (Single-Region, Multi-AZ)

Applies to a transient AZ-level RDS failure (not a full region loss — see
`documentation/disaster-recovery.md` for that scenario).

## Symptoms

- `RDSHighConnections` or connection-refused errors from services
- AWS RDS console shows a Multi-AZ failover event

## Steps

1. RDS Multi-AZ failover is **automatic** — typically completes in 60–120 seconds. The
   endpoint DNS name does not change; the underlying IP does.
2. Confirm application recovery — services using the standard JDBC driver with connection
   validation (HikariCP `connectionTestQuery`/`validationTimeout`) should reconnect
   automatically. Verify with:
   ```bash
   ./databases/scripts/connection-pool-check.sh production
   ```
3. If a service's pool is stuck holding stale connections, restart it:
   ```bash
   kubectl rollout restart deployment/<svc> -n production
   ```
4. Check Grafana's Database Performance panel for a latency spike around the failover window
   — expected and should recover within a minute or two.
5. If failover does not complete automatically within 5 minutes, escalate to SEV1 and follow
   `documentation/runbooks/incident-response.md`.
