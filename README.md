# Production Deployment & DevOps Pipeline

Enterprise-grade DevOps pipeline for deploying the full-stack e-commerce application (React
frontend + Spring Boot microservices) to production: Infrastructure as Code, multi-stage
CI/CD, Kubernetes orchestration, full observability, security scanning, auto-scaling, and
disaster recovery.

## Project Goals

- **Never touch production by hand.** Every resource — cloud infrastructure, Kubernetes
  workloads, monitoring, secrets — is defined as code and applied through a pipeline.
- **Fail safe, not fast.** Canary deployments, automated rollback, and quality/security gates
  stand between a commit and production traffic.
- **See everything.** Metrics, logs, and alerts are wired up before the first real user hits
  the system, not after an incident.
- **Plan for failure.** Documented, drilled disaster-recovery and incident-response runbooks,
  not just a hope that nothing goes wrong.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloud Provider (AWS)                     │
├─────────────────────────────────────────────────────────────┤
│   VPC (10.0.0.0/16) — public / private / database subnets   │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│   │  EKS Cluster│  │ RDS Postgres │  │ ElastiCache │         │
│   │(on-dem+spot)│  │  (Multi-AZ)  │  │   (Redis)   │         │
│   └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│   ALB / ingress-nginx          │  CloudFront (CDN)           │
├─────────────────────────────────────────────────────────────┤
│   Prometheus · Grafana · Loki · Alertmanager                 │
└─────────────────────────────────────────────────────────────┘
```

Full detail in [`documentation/architecture.md`](documentation/architecture.md).

## Technology Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (EKS, RDS, ElastiCache, S3, CloudFront, Route53) |
| IaC | Terraform (modular: VPC, EKS, RDS, networking; per-environment state) |
| Orchestration | Kubernetes, Helm, Kustomize |
| CI/CD | GitHub Actions (multi-stage: quality → security → build → deploy) |
| Monitoring | Prometheus, Grafana, Loki, Alertmanager |
| Security | HashiCorp Vault, External Secrets Operator, Trivy, Snyk, OWASP Dependency Check, tfsec |
| Networking | NGINX Ingress, Kubernetes NetworkPolicies |

## Repository Structure

```
week12-production-deployment/
├── infrastructure/
│   ├── terraform/            # VPC, EKS, RDS, networking modules + per-env configs
│   ├── kubernetes/
│   │   ├── base/              # Kustomize base (namespaces, shared config)
│   │   ├── overlays/          # dev / staging / prod patches
│   │   └── helm/               # api-gateway, product-service, frontend charts
│   └── scripts/                # deploy.sh, backup.sh, monitoring.sh, run-smoke-tests.sh
├── .github/workflows/          # ci.yml, cd-dev/staging/prod.yml, security-scan.yml
├── monitoring/
│   ├── prometheus/             # prometheus.yml, alerts/, rules/
│   ├── grafana/                # dashboards/, datasources/, providers/
│   ├── loki/                   # loki-config.yaml
│   └── alertmanager/           # alertmanager.yml
├── security/
│   ├── trivy/   snyk/   vault/   policies/
├── databases/
│   ├── backups/   migrations/   scripts/
├── documentation/
│   ├── architecture.md
│   ├── deployment-guide.md
│   ├── disaster-recovery.md
│   └── runbooks/
└── README.md
```

## Getting Started

```bash
# 1. Provision infrastructure for an environment
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # fill in DB credentials
terraform init && terraform apply

# 2. Deploy the application (infra + kustomize + helm, end to end)
./infrastructure/scripts/deploy.sh dev <image-tag>

# 3. Stand up monitoring
./infrastructure/scripts/monitoring.sh
```

Full walkthrough — including CI/CD secrets setup, canary production deploys, and teardown — in
[`documentation/deployment-guide.md`](documentation/deployment-guide.md).

## CI/CD Pipeline

```
push/PR → CI (lint, test, SonarQube)
        → Security Scan (Trivy, Snyk, OWASP Dependency Check, tfsec)
        → Build & push images
        → CD: dev (auto)  →  CD: staging (auto, environment-gated)  →  CD: prod (canary + approval)
```

Production deploys run a **canary** (1 replica, 5-minute bake) before promoting to a full
rollout, and automatically roll back on failure with a Slack notification either way. See
`.github/workflows/`.

## Monitoring & Alerting

- **Prometheus** scrapes every service's `/actuator/prometheus` endpoint (`monitoring/prometheus/prometheus.yml`).
- **Alert rules** cover application signals (error rate, p95 latency, crash loops) and
  infrastructure signals (node CPU/memory, PV capacity, Kafka lag, RDS connections)
  (`monitoring/prometheus/alerts/`).
- **Alertmanager** routes by severity: critical → PagerDuty + Slack, warning/info → Slack
  (`monitoring/alertmanager/alertmanager.yml`).
- **Grafana** ships 3 pre-built dashboards: Service Health, Business Metrics, Infrastructure
  (`monitoring/grafana/dashboards/`).
- **Loki** aggregates logs from every pod, S3-backed, 30-day retention.

## Security

- Secrets never live in Git or plain Kubernetes Secrets manifests — HashiCorp Vault +
  External Secrets Operator sync them in at runtime (`security/vault/`).
- Every PR and a weekly schedule run Trivy (containers + IaC), Snyk (dependencies), OWASP
  Dependency Check, and tfsec (Terraform) — see `.github/workflows/security-scan.yml`.
- Kubernetes namespaces enforce the `restricted` Pod Security Standard; NetworkPolicies default
  to deny-all with explicit per-service allow rules (`security/policies/`).
- CI/CD uses a least-privilege, deploy-only RBAC `Role` — never cluster-admin.

## Auto-Scaling

| Mechanism | Scope | Config |
|---|---|---|
| Horizontal Pod Autoscaler | Per service, CPU 70% / memory 80% | Helm chart `autoscaling` values, 2–10 replicas |
| Vertical Pod Autoscaler | Frontend (right-sizes requests/limits) | `frontend` chart `verticalPodAutoscaler` |
| Cluster Autoscaler | Node groups (on-demand + spot) | Terraform `node_groups` `min_size`/`max_size` |

## Disaster Recovery

RPO 15 min / RTO 30 min for critical services; full documented failover and failback runbooks
for a complete region loss, quarterly DR drills, and automated backup-restore testing. See
[`documentation/disaster-recovery.md`](documentation/disaster-recovery.md).

## Runbooks

- [`documentation/runbooks/incident-response.md`](documentation/runbooks/incident-response.md) — general triage process
- [`documentation/runbooks/scaling-runbook.md`](documentation/runbooks/scaling-runbook.md) — scaling under load
- [`documentation/runbooks/database-failover.md`](documentation/runbooks/database-failover.md) — RDS AZ failover

## Cost Optimization

- Spot instances for stateless workloads (~30–70% savings depending on instance pool).
- Reserved instances for steady-state database/compute baseline.
- S3 Intelligent-Tiering and lifecycle transitions (Standard-IA at 30 days, Glacier at 90).
- CloudFront caching to reduce origin data-transfer costs.
- Autoscalers scale down aggressively off-peak (5-minute stabilization window on HPA scale-down).

## Notes on This Scaffold

This repository is a complete, ready-to-adapt Infrastructure-as-Code and CI/CD scaffold. It was
generated in a sandbox without live AWS/Kubernetes credentials or Maven/npm registry access, so
nothing here has been applied against real cloud infrastructure. Before running it for real:

- Fill in `terraform.tfvars` for each environment with real credentials (never commit them).
- Create the `ecommerce-terraform-state` S3 bucket and `terraform-lock` DynamoDB table once, by hand, before first `terraform init`.
- Point image repository values (`ghcr.io/your-org/...`) at your actual container registry.
- Replace placeholder domains (`*.ecommerce.com`) with your real DNS zone.
- Configure the GitHub repository secrets listed in `documentation/deployment-guide.md`.
