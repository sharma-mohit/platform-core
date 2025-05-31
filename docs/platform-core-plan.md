# 🧱 Revised Platform Core Plan (Everything-as-Code)

A fully automated, production-grade AI platform infrastructure built entirely as code — supporting multi-region AKS clusters, secure and scalable GPU workloads, GitOps deployment, and AI/ML capabilities.

---

## 1. ENVIRONMENTS AND REGIONS

- **dev-uaenorth**
- **stg-uaenorth**
- **prd-uaenorth**

---

## 2. INFRASTRUCTURE ARCHITECTURE

### AKS Cluster Strategy
- GPU and CPU node pools (NVIDIA H100, AMD)
- MIG configuration for NVIDIA
- Taints, affinities, autoscaling, node labels
- Cluster Autoscaler and Node Problem Detector

### Multi-Environment & Region Support
- Folder structure per environment
- Separate remote backend
- Hub-Spoke VNet topology
- Azure Firewall for egress filtering

### Network & Connectivity
- Private Endpoints for ACR, Key Vault, Storage
- NSGs, UDRs, private DNS zones
- Both internal and public ingress exposure

---

## 3. STATE MANAGEMENT

- Remote backend using Azure Storage
- State locking with `azurerm` backend
- Versioned backups and promotion strategy
- Optional Terraform Cloud integration

---

## 4. IDENTITY & ACCESS MANAGEMENT

- Azure AD integration for AKS
- Workload Identity (AAD Pod Identity or native)
- Modular RBAC templates for:
  - Devs
  - Platform team
  - Automation bots
- Service principal and secret rotation

---

## 5. COST MANAGEMENT

- Resource tagging: environment, region, team, owner
- Spot node pools for test workloads
- Scheduled scaling policies
- Prometheus + Grafana cost dashboards

---

## 6. DEVOPS & GITOPS

### CI/CD Integration
- GitLab pipelines with:
  - PR validation
  - Plan → Apply → Promote workflows
  - Image scanning with Trivy
  - Drift detection

### GitOps Structure (FluxCD)
- GitOps repo: `gitops-bootstrap/clusters/<env-region>/` using FluxCD and Kustomize
- App Helm templates and Kustomize overlays
- Canary, blue-green, and rollback support
- FluxCD Kustomizations for base and environment-specific configurations

---

## 7. SECRET MANAGEMENT

- External Secrets Operator (ESO)
- Azure Key Vault integration
- Key Vault lifecycle rules
- Optional SOPS or SealedSecrets for Git
- Secret auditing scripts

---

## 8. AI/ML COMPONENTS

### GPU Support
- NVIDIA H100 and AMD with all operators
- GPU scheduling, tolerations, MIG config
- Node labeling and GPU plugin management

### AI/ML Tooling
- MLflow or Weights & Biases
- KServe, BentoML, vLLM for model serving
- Qdrant, Azure CosmosDB (Mongo) for vector storage

### Data Management
- Azure Data Lake Gen2 integration
- Argo Workflows or K8s Jobs for batch
- PVCs for model artifacts
- Data versioning optional with DVC/Pachyderm

---

## 9. MONITORING & SECURITY

### Observability
- Prometheus, Grafana, Loki, Tempo
- Custom dashboards:
  - GPU usage
  - Inference latency
  - Cost per namespace
- Alerting + anomaly detection

### Security
- Trivy container scanning
- Kyverno / OPA Gatekeeper
- Network policy enforcement
- Microsoft Defender for Containers

---

## 10. IMPLEMENTATION STRATEGY

### Layer Separation
- Terraform → infra
- FluxCD with Kustomize → GitOps
- Helm/Kustomize → config
- GitLab CI → pipelines

### Modularity
- Reusable Terraform modules
- Helm templates per app class
- Namespace-based multi-tenancy

### Operational Procedures
- Kubeconfig scripts
- Terraform Makefile
- Disaster recovery runbooks

---

## 11. NEXT STEPS

- Generate full starter repo (DONE)
- Define GitOps manifests
- Build Helm charts
- Configure CI pipelines

