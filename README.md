Production Deployment & DevOps Pipeline

Enterprise-grade DevOps pipeline for deploying the full-stack e-commerce application (React frontend + Spring Boot microservices) to production: Infrastructure as Code, multi-stage CI/CD, Kubernetes orchestration, full observability, security scanning, auto-scaling, and disaster recovery.

<p align="left"> <img alt="Terraform" src="https://img.shields.io/badge/Terraform-1.5%2B-844FBA"> <img alt="Kubernetes" src="https://img.shields.io/badge/Kubernetes-EKS%20%2B%20Helm-326CE5"> <img alt="CI/CD" src="https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF"> <img alt="Monitoring" src="https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-E6522C"> <img alt="Security" src="https://img.shields.io/badge/Secrets-HashiCorp%20Vault-FFEC6E"> <img alt="License" src="https://img.shields.io/badge/License-MIT-lightgrey"> </p>
Table of Contents
Overview
Infrastructure Architecture
Technology Stack
CI/CD Pipeline
Deployment Strategies
Kubernetes & Helm
Monitoring & Alerting
Security
Auto-Scaling
Disaster Recovery
Cost Optimization
Repository Structure
Getting Started
CI/CD Secrets
Runbooks
Technical Requirements Checklist
Troubleshooting
Notes on This Scaffold
License
Overview

This project takes the full-stack e-commerce application from a working codebase to a production-deployed system operated with enterprise-grade DevOps practices. Every piece of infrastructure, every deployment, and every operational safeguard is defined as code and driven through an automated pipeline — nothing is configured by hand in production.

Goals:

Provision all cloud infrastructure as Terraform code, with isolated state per environment (dev/staging/prod).
Build a multi-stage CI/CD pipeline (GitHub Actions) gating every deploy behind linting, tests, static analysis, and security scanning.
Deploy to Kubernetes via Helm + Kustomize, with health probes, resource limits, and HPA/VPA/Cluster Autoscaler on every service.
Reduce deployment risk with a canary strategy in production — automatic promotion on success, automatic rollback with alerting on failure.
Achieve full observability before go-live: metrics, logs, and alerting wired to Slack/PagerDuty.
Harden the platform with defense-in-depth security: Vault-managed secrets, network policies, restricted pod security, automated scanning.
Document and drill a disaster recovery plan with concrete RTO/RPO targets and a tested multi-region failover procedure.
Infrastructure Architecture
┌─────────────────────────────────────────────────────────────┐
│                    AWS Account — us-east-1                  │
├─────────────────────────────────────────────────────────────┤
│   Route53 (DNS + health checks) · CloudFront (CDN) · ACM     │
├─────────────────────────────────────────────────────────────┤
│   VPC 10.0.0.0/16 — 3 Availability Zones                     │
│   ┌─────────────────────────────────────────────────────┐   │
│   │  PUBLIC SUBNETS — ALB / NGINX Ingress Controller     │   │
│   ├───────────────────────┬───────────────┬─────────────┤   │
│   │  PRIVATE SUBNETS      │  DATABASE     │  ElastiCache│   │
│   │  EKS Cluster          │  SUBNETS      │  (Redis,    │   │
│   │  (on-demand + spot)   │  RDS Postgres │   Multi-AZ) │   │
│   │  HPA · Cluster        │  (Multi-AZ)   │             │   │
│   │  Autoscaler           │               │             │   │
│   └───────────────────────┴───────────────┴─────────────┘   │
├─────────────────────────────────────────────────────────────┤
│   S3 (logs, Velero backups)  │  Vault / Secrets Manager      │
├─────────────────────────────────────────────────────────────┤
│   Prometheus · Grafana · Loki · Alertmanager (monitoring ns) │
└─────────────────────────────────────────────────────────────┘

Provisioned via 4 composable Terraform modules:

Module	Responsibility
modules/vpc	VPC, public/private/database subnets across 3 AZs, NAT gateways, route tables
modules/eks	EKS cluster, IAM roles, on-demand + spot managed node groups
modules/rds	PostgreSQL instance, subnet group, parameter group, enhanced monitoring
modules/networking	Security groups (database, redis, ALB) — least-privilege ingress

State is isolated per environment (environments/{dev,staging,prod}) via separate S3 backend keys and a shared DynamoDB lock table.

Cloud portability: the reference implementation targets AWS (EKS/RDS/ElastiCache), but the Kubernetes-layer artifacts (Helm charts, Kustomize overlays, monitoring stack) are cloud-agnostic by design — the same architecture maps onto Azure (AKS, Azure SQL, Redis Cache) or GCP (GKE, Cloud SQL, Memorystore) by swapping only the Terraform provider and modules.

Technology Stack
Category	Technologies
Cloud Platform	AWS — EKS, RDS, ElastiCache, S3, CloudFront, Route53
Infrastructure as Code	Terraform (modular, per-env state), Helm, Kustomize
CI/CD	GitHub Actions — quality gates → security scan → build → deploy
Monitoring	Prometheus, Grafana, Loki, Alertmanager
Security	HashiCorp Vault + External Secrets Operator, Trivy, Snyk, OWASP Dependency Check, tfsec, NetworkPolicies, Pod Security Standards
Networking	NGINX Ingress Controller, cert-manager (Let's Encrypt)
Database Ops	Automated RDS snapshots, Multi-AZ failover, Flyway migrations, Velero backups
CI/CD Pipeline
push/PR → CI (lint, test, SonarQube)
        → Security Scan (Trivy, Snyk, OWASP Dependency Check, tfsec)
        → Build & push images (GHCR)
        → Deploy: dev (auto) → Deploy: staging (auto, gated) → Deploy: prod (canary + approval)
Stage	Workflow	What runs
1. Code Quality	ci.yml	ESLint/Checkstyle, SonarQube static analysis, Jest/JUnit unit tests
2. Security Scan	security-scan.yml	OWASP Dependency Check, Trivy (fs + IaC), Snyk, tfsec
3. Build & Package	ci.yml	Docker Buildx image build per service, push to GHCR
4. Deploy: Dev	cd-dev.yml	Auto-deploy on every push to develop
5. Deploy: Staging	cd-staging.yml	Auto after CI passes on main; environment-gated; runs smoke tests
6. Deploy: Production	cd-prod.yml	Canary (1 replica, 5-min bake) → promote or auto-rollback; Slack notification either way
Deployment Strategies
Strategy	Used in	Why
Rolling update	dev, staging	Simple, default Kubernetes behavior
Canary	production	Limits blast radius to a single replica before full rollout
Blue-green	production (major releases, documented extension)	Two full environments; instant cutover and rollback

Canary flow (production): deploy 1 canary replica → monitor for 5 minutes → check pod health → promote all services to the new version, or tear down the canary and roll back with a Slack alert.

Kubernetes & Helm

Two complementary tools manage the Kubernetes layer:

Kustomize (infrastructure/kubernetes/base + overlays/{dev,staging,prod}) for namespace-level resources that vary only slightly per environment (replica counts, resource sizing) via strategic merge patches.
Helm (infrastructure/kubernetes/helm/{api-gateway,product-service,frontend}) for the deployable application charts — each with per-environment values-{env}.yaml, HPA, PodDisruptionBudget, and ServiceMonitor.
product-service/
├── Chart.yaml
├── values.yaml
├── values-{dev,staging,production}.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── hpa.yaml
    ├── pdb.yaml
    ├── servicemonitor.yaml
    └── _helpers.tpl

product-service's chart is representative of all six backend microservices; frontend adds an nginx ConfigMap and a VerticalPodAutoscaler.

Standard resource/probe configuration:

yaml
resources:
  requests: { memory: "512Mi", cpu: "250m" }
  limits:   { memory: "1Gi",   cpu: "500m" }

probes:
  livenessProbe:
    httpGet: { path: /actuator/health/liveness, port: 8080 }
    initialDelaySeconds: 60
    periodSeconds: 10
  readinessProbe:
    httpGet: { path: /actuator/health/readiness, port: 8080 }
    initialDelaySeconds: 30
    periodSeconds: 5

autoscaling:
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
Monitoring & Alerting
Component	Purpose	Config
Prometheus	Metrics from every service's /actuator/prometheus	monitoring/prometheus/prometheus.yml
Alertmanager	Routes alerts by severity: critical → PagerDuty + Slack, warning/info → Slack	monitoring/alertmanager/alertmanager.yml
Grafana	Service Health, Business Metrics, Infrastructure & Cost dashboards	monitoring/grafana/
Loki	Centralized log aggregation, S3-backed, 30-day retention	monitoring/loki/loki-config.yaml

Sample alert rule:

yaml
- alert: HighErrorRate
  expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m])
        / rate(http_server_requests_seconds_count[5m]) > 0.05
  for: 2m
  labels: { severity: critical }
  annotations:
    summary: "High error rate detected"

Additional rules cover latency, pod crash loops, node CPU/memory pressure, PV capacity, Kafka consumer lag, and RDS connection saturation (monitoring/prometheus/alerts/).

Security
Secrets: HashiCorp Vault + External Secrets Operator sync Vault paths into native Kubernetes Secrets every 15 minutes — no plaintext secrets in Git (security/vault/).
Scanning: Trivy (containers + IaC), Snyk (dependencies), OWASP Dependency Check, tfsec (Terraform) — wired into every PR and a weekly schedule (security/, .github/workflows/security-scan.yml).
Network policy: default-deny-all per namespace, explicit allow rules per service (security/policies/network-policy.yaml).
Pod security: the Kubernetes restricted Pod Security Standard is enforced at the namespace level — non-root, read-only root filesystem, no privilege escalation, all capabilities dropped.
RBAC: the CI/CD service account is scoped to a least-privilege, deploy-only Role — never cluster-admin (security/policies/iam-rbac.yaml).
Auto-Scaling
Mechanism	Scope	Config
Horizontal Pod Autoscaler	Per service, CPU 70% / memory 80%	Helm chart autoscaling values, 2–10 replicas
Vertical Pod Autoscaler	Frontend (right-sizes requests/limits)	frontend chart verticalPodAutoscaler
Cluster Autoscaler	Node groups (on-demand + spot)	Terraform node_groups min_size/max_size
Disaster Recovery
Metric	Critical services	Non-critical services
RPO	15 minutes	4 hours
RTO	30 minutes	4 hours

Complete system recovery (full region loss): RTO 8 hours.

Backup strategy:

Asset	Method	Schedule	Retention
RDS PostgreSQL	Automated snapshots + continuous transaction log	Daily full 03:00 UTC	30 days (prod)
Kubernetes cluster state	Velero	Daily 03:00 UTC	30 days
Application config	Git	Every commit	Indefinite
S3 uploads	Versioning + lifecycle policy	Continuous	365 days (Glacier @ 90d)

Multi-region topology: primary (us-east-1, 100% traffic) + secondary (us-west-2, warm standby with a promoted RDS read replica), failover via Route53 health-checked routing. Full failover/failback runbook in documentation/disaster-recovery.md.

Cost Optimization
Lever	Approach
Compute	Spot instances for stateless services; reserved instances for the database baseline
Autoscaling	HPA/Cluster Autoscaler scale down aggressively off-peak (5-min stabilization window)
Storage	S3 Intelligent-Tiering; EBS gp3; lifecycle transition to Glacier at 90 days
Network	CloudFront caching; VPC endpoints to avoid NAT data-transfer charges
Monitoring	Priority-based sampling, log retention limits, alert consolidation
Repository Structure
week12-production-deployment/
├── infrastructure/
│   ├── terraform/
│   │   ├── modules/ (vpc, eks, rds, networking)
│   │   ├── environments/ (dev, staging, prod)
│   │   └── main.tf, variables.tf, outputs.tf
│   ├── kubernetes/
│   │   ├── base/ (namespaces, services, configs)
│   │   ├── overlays/ (dev, staging, prod)
│   │   └── helm/ (api-gateway, product-service, frontend)
│   └── scripts/ (deploy.sh, backup.sh, monitoring.sh, run-smoke-tests.sh)
├── .github/workflows/
│   ├── ci.yml
│   ├── security-scan.yml
│   ├── cd-dev.yml
│   ├── cd-staging.yml
│   └── cd-prod.yml
├── monitoring/
│   ├── prometheus/ (prometheus.yml, alerts/, rules/)
│   ├── grafana/ (dashboards/, datasources/, providers/)
│   ├── loki/ (loki-config.yaml)
│   └── alertmanager/ (alertmanager.yml)
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
Getting Started
Prerequisites
Terraform >= 1.5.0
AWS CLI v2, configured with credentials able to create VPC/EKS/RDS/S3 resources
kubectl, helm 3.x, kustomize
An S3 bucket + DynamoDB table for Terraform remote state (create once, by hand, before first use)
1. Provision Infrastructure
bash
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # fill in DB credentials
terraform init
terraform apply
2. Deploy the Application
bash
aws eks update-kubeconfig --region us-east-1 --name ecommerce-dev
kubectl apply -k infrastructure/kubernetes/overlays/dev

# Or run the wrapper script (infra + kustomize + helm, end to end):
./infrastructure/scripts/deploy.sh dev <image-tag>
3. Stand Up Monitoring
bash
./infrastructure/scripts/monitoring.sh
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000
4. Verify
bash
kubectl -n production get pods
kubectl -n production get hpa
curl https://api.ecommerce.com/api/products
Tear Down
bash
helm uninstall api-gateway product-service frontend -n dev
kubectl delete -k infrastructure/kubernetes/overlays/dev
cd infrastructure/terraform/environments/dev && terraform destroy
CI/CD Secrets
Secret	Used by
AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY	cd-*.yml — deploy to EKS
SONAR_TOKEN / SONAR_HOST_URL	ci.yml — code quality gate
SNYK_TOKEN	security-scan.yml
SLACK_WEBHOOK_URL	cd-prod.yml — deploy notifications

Configure GitHub Environments (staging, production) with required reviewers under Settings → Environments to add a manual approval gate in front of those workflows.

Runbooks
documentation/runbooks/incident-response.md — general triage process
documentation/runbooks/scaling-runbook.md — scaling under load
documentation/runbooks/database-failover.md — RDS AZ failover
documentation/disaster-recovery.md — full region failover/failback
Technical Requirements Checklist
#	Requirement	Where
1	CI/CD Pipeline with GitHub Actions	5 workflows in .github/workflows/
2	Infrastructure as Code with Terraform	4 modules × 3 environments, S3 remote state
3	Kubernetes deployment with Helm charts	3 charts with HPA/PDB/ServiceMonitor
4	Cloud platform deployment (EKS/AKS/GKE)	EKS reference implementation; portable architecture
5	Monitoring: Prometheus, Grafana, Loki, Alertmanager	Full stack in monitoring/
6	Security scanning: Trivy, Snyk, OWASP	All three + tfsec in security-scan.yml
7	Database management: backups, replication, failover	RDS Multi-AZ, snapshots, Velero, failover runbook
8	Load balancing (NGINX/Traefik/Istio)	NGINX Ingress Controller on all Helm charts
9	Auto-scaling: HPA, Cluster Autoscaler	HPA on every chart; Cluster Autoscaler via node groups
10	Secrets management: Vault / AWS Secrets Manager	HashiCorp Vault + External Secrets Operator
Troubleshooting
Symptom	Likely Cause	Fix
terraform apply fails acquiring lock	Another apply in progress, or a stale lock	Check the DynamoDB lock table; force-unlock only if certain
Pods stuck Pending	Node group at capacity	Check Cluster Autoscaler logs; verify node group maxSize
Canary never promotes	frontend-canary pod not Running	kubectl describe pod — usually image pull or readiness probe failure
Alerts not firing	Alertmanager route/receiver misconfigured	amtool config routes inside the Alertmanager pod
403 from Vault	Kubernetes auth role/service account mismatch	Confirm the pod's ServiceAccount matches the Vault role binding
Notes on This Scaffold

This repository is a complete, ready-to-adapt Infrastructure-as-Code and CI/CD scaffold, generated without live AWS/Kubernetes credentials — nothing here has been applied against real cloud infrastructure. Before running it for real:

Fill in terraform.tfvars for each environment with real credentials (never commit them).
Create the ecommerce-terraform-state S3 bucket and terraform-lock DynamoDB table once, by hand.
Point image repository values (ghcr.io/your-org/...) at your actual container registry.
Replace placeholder domains (*.ecommerce.com) with your real DNS zone.
Configure the GitHub repository secrets listed above.
