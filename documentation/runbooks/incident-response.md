# Runbook: General Incident Response

## Severity Levels

| Level | Definition | Response time |
|---|---|---|
| SEV1 | Full outage or data loss risk | Immediate, all-hands |
| SEV2 | Major feature degraded, no data risk | < 30 min |
| SEV3 | Minor degradation, workaround exists | Next business day |

## Steps

1. **Acknowledge** the PagerDuty/Alertmanager alert within 5 minutes.
2. **Triage**: check Grafana "Service Health" dashboard, then `kubectl -n production get pods`
   for crash loops or pending pods.
3. **Check recent changes**: `kubectl -n production rollout history deployment/<svc>` and the
   last few merged PRs — most incidents follow a recent deploy.
4. **Mitigate first, root-cause later**:
   - Bad deploy → `kubectl rollout undo deployment/<svc> -n production`
   - Resource exhaustion → check HPA (`kubectl get hpa -n production`), scale manually if the
     autoscaler hasn't caught up: `kubectl scale deployment/<svc> --replicas=<n> -n production`
   - Downstream dependency down → confirm circuit breakers are open (expected) and let them
     recover automatically once the dependency is healthy.
5. **Communicate**: post in `#platform-incidents` every 15 minutes with status, even if
   "still investigating."
6. **Resolve & verify**: confirm error rate/latency back to baseline on Grafana for 10+ minutes.
7. **Post-incident review** within 48 hours: timeline, root cause, action items with owners.
