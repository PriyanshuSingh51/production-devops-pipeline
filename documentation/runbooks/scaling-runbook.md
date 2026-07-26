# Runbook: Scaling Under Load

## Symptoms

- HPA at `maxReplicas` and still CPU/memory-throttled
- p95 latency alert firing (`HighLatency`)
- Cluster Autoscaler logs show pending pods unable to schedule

## Steps

1. Confirm current HPA state:
   ```bash
   kubectl get hpa -n production
   ```
2. If HPA is maxed out, temporarily raise the ceiling:
   ```bash
   helm upgrade <chart> ./infrastructure/kubernetes/helm/<chart> \
     -n production --reuse-values --set autoscaling.maxReplicas=20
   ```
3. If pods are `Pending` due to node capacity, confirm the Cluster Autoscaler is provisioning
   new nodes (check node group `desiredSize` climbing in the EKS console / `kubectl get nodes -w`).
4. If autoscaler is stuck, check for a node group `maxSize` ceiling in
   `infrastructure/terraform/variables.tf` (`node_groups`) — raise and `terraform apply` if needed.
5. Check downstream capacity too — a scaled-up service can overwhelm its database
   (`RDSHighConnections` alert) or Kafka partition count. Scaling the app tier alone isn't
   always sufficient.
6. Once traffic subsides, confirm HPA scales back down (5-minute stabilization window) and
   revert any manual `maxReplicas` overrides.
