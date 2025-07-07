# 🧱 Revised Platform Core Plan (Everything-as-Code)

A fully automated, production-grade AI platform infrastructure built entirely as code — supporting multi-region AKS clusters, secure and scalable GPU workloads, GitOps deployment, centralized multi-cluster observability, and AI/ML capabilities with UAE sovereign cloud compliance and customer-managed key encryption.

---

## 1. ENVIRONMENTS AND REGIONS

- **dev-uaenorth**
- **stg-uaenorth**
- **prd-uaenorth**
- **ops-uaenorth** (Central Operations Cluster)

---

## 2. INFRASTRUCTURE ARCHITECTURE

### AKS Cluster Strategy
- GPU and CPU node pools (NVIDIA H100, AMD)
- MIG configuration for NVIDIA
- Taints, affinities, autoscaling, node labels
- Cluster Autoscaler and Node Problem Detector
- Customer-managed key disk encryption
- Workload Identity for secure authentication

### Multi-Environment & Region Support
- Folder structure per environment
- Separate remote backend with customer-managed keys
- Hub-Spoke VNet topology with private endpoints
- Azure Firewall for egress filtering
- Cross-cluster networking and DNS resolution

### Network & Connectivity
- Private Endpoints for ACR, Key Vault, Storage
- NSGs, UDRs, private DNS zones
- Both internal and public ingress exposure
- Default deny policies with explicit allow rules
- Service endpoints for Azure services

---

## 3. STATE MANAGEMENT

- Remote backend using Azure Storage with customer-managed key encryption
- State locking with `azurerm` backend
- Versioned backups and promotion strategy
- Optional Terraform Cloud integration
- Workspace isolation per environment

---

## 4. IDENTITY & ACCESS MANAGEMENT

- Azure AD integration for AKS
- Workload Identity (native Azure implementation)
- Modular RBAC templates for:
  - Devs
  - Platform team
  - Automation bots
  - SRE team
- Service principal and secret rotation
- Customer-managed key access management

---

## 5. COST MANAGEMENT

- Resource tagging: environment, region, team, owner (UAE sovereign cloud compliance)
- Spot node pools for test workloads
- Scheduled scaling policies
- Centralized cost dashboards in Grafana
- GPU utilization optimization across clusters
- Cross-environment cost comparison

---

## 6. DEVOPS & GITOPS

### CI/CD Integration
- GitHub Actions with:
  - PR validation
  - Plan → Apply → Promote workflows
  - Image scanning with Trivy
  - Drift detection
  - Customer-managed key encryption for artifacts

### GitOps Structure (FluxCD)
- GitOps repo: `flux-config/clusters/<env-region>/` using FluxCD and Kustomize
- App Helm templates and Kustomize overlays
- Canary, blue-green, and rollback support
- FluxCD Kustomizations for base and environment-specific configurations
- Multi-cluster management from single repository

---

## 7. SECRET MANAGEMENT

- External Secrets Operator (ESO)
- Azure Key Vault integration with customer-managed keys
- Key Vault lifecycle rules
- Optional SOPS or SealedSecrets for Git
- Secret auditing scripts
- Workload Identity for secure access

---

## 8. AI/ML COMPONENTS

### GPU Support
- NVIDIA H100 and AMD with all operators
- GPU scheduling, tolerations, MIG config
- Node labeling and GPU plugin management
- GPU monitoring in centralized observability
- Cost optimization for GPU workloads

### AI/ML Tooling
- MLflow or Weights & Biases
- KServe, BentoML, vLLM for model serving
- Qdrant, Azure CosmosDB (Mongo) for vector storage
- Integration with centralized observability stack

### Data Management
- Azure Data Lake Gen2 integration
- Argo Workflows or K8s Jobs for batch
- PVCs for model artifacts
- Data versioning optional with DVC/Pachyderm
- Customer-managed key encryption for data

---

## 9. OBSERVABILITY & SECURITY

### Centralized Observability
- LGTM Stack (Loki, Grafana, Tempo, Mimir) in ops cluster
- Lightweight agents on workload clusters (OpenTelemetry, Prometheus Agent, Promtail)
- Multi-cluster dashboards:
  - Cluster overview and health
  - Environment comparison
  - Cross-cluster application performance
  - GPU monitoring across all clusters
- Cross-cluster alerting with proper context
- Single pane of glass for all environments

### Security
- Trivy container scanning
- Kyverno / OPA Gatekeeper
- Network policy enforcement
- Microsoft Defender for Containers
- Customer-managed key encryption for all data
- UAE sovereign cloud compliance
- Private endpoints for all services

---

## 10. IMPLEMENTATION STRATEGY

### Layer Separation
- Terraform → infra with customer-managed keys
- FluxCD with Kustomize → GitOps
- Helm/Kustomize → config
- GitHub Actions → pipelines

### Modularity
- Reusable Terraform modules
- Helm templates per app class
- Namespace-based multi-tenancy
- Customer-managed key modules

### Operational Procedures
- Kubeconfig scripts
- Terraform Makefile
- Disaster recovery runbooks
- Customer-managed key rotation procedures

---

## 11. COMPLIANCE & SECURITY

### UAE Sovereign Cloud Compliance
- Required tags on all resources
- Customer-managed key encryption for all data
- Private endpoints for Azure services
- Network security with default deny policies
- Audit logging and compliance reporting

### Customer-Managed Key Encryption
- Storage accounts (Terraform state, ACR, observability data)
- AKS managed disks
- Key Vault encryption
- ACR content encryption
- Regular key rotation and backup

### Multi-Cluster Security
- Workload Identity across clusters
- Cross-cluster network policies
- Centralized secret management
- Unified RBAC and access control
- Security scanning in CI/CD

---

## 12. NEXT STEPS

- ✅ Generate full starter repo (DONE)
- ✅ Define GitOps manifests (DONE)
- ✅ Deploy centralized observability stack (DONE)
- 🚧 Build Helm charts for AI/ML tools
- 🚧 Configure advanced CI pipelines
- 🚧 Implement GPU workload optimization
- 🚧 Advanced security hardening

---

## 13. SUCCESS METRICS

- **Security**: 100% customer-managed key encryption compliance
- **Observability**: <3s dashboard load times for multi-cluster views
- **Automation**: 100% infrastructure managed via GitOps
- **Compliance**: All resources tagged according to UAE sovereign cloud requirements
- **Performance**: <5s cross-cluster query response times
- **Cost**: GPU utilization optimization across all clusters
- **Reliability**: 99.9% uptime for centralized observability stack

