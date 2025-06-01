# 🗺️ Platform Core Roadmap

This roadmap outlines the phased development of a secure, modular, cloud-native AI platform built on Azure Kubernetes Service (AKS), optimized for self-hosted LLMs (e.g., LLaMA), multi-agent systems (RAG, RAT, MCP), and enterprise applications.

---

## ✅ Current Context (As Confirmed)

- Environments: `dev-uaenorth`, `stg-uaenorth`, `prd-uaenorth`
- Ingress: Public + Internal
- TLS: Custom Certs via Cloudflare Origin Certs
- Secrets: Azure Key Vault
- GPUs: NVIDIA H100 and AMD (all supported operators/configs)
- GitOps: FluxCD
- Goal: Fully automated infrastructure-as-code platform with GitLab integration and no manual setup

---

## 🚧 Phase 1: Core Infrastructure (Completed)

### Objectives
- Deploy base AKS clusters in all environments
- Setup hub-spoke network with firewall
- Configure remote Terraform state + locking
- Setup ACR, Azure Key Vault, Storage

### Deliverables
- Terraform modules (aks, acr, network, keyvault, firewall, gitops)
- Backend and environment-specific configs
- Public + internal ingress setup
- Azure Firewall rules + NSGs

### Outcome
- Secure and scalable Kubernetes foundation

---

## 🚧 Phase 2: GitOps & Platform Bootstrap (Current Focus)

### Objectives
- Deploy GitOps controller (FluxCD)
- Bootstrap observability stack (Prometheus, Grafana, Loki, Tempo)
- Setup ingress controller, cert-manager
- Enable external-secrets integration with Azure Key Vault

### Deliverables
- FluxCD manifests and Kustomize configurations for sync
- Helm charts for core services
- TLS using custom Cloudflare origin certs
- Secrets operator setup with initial sync

### Goal
- Fully automated infrastructure-as-code platform with GitHub integration and no manual setup for core services

---

## 🚧 Phase 3: GPU & AI Workload Readiness

### Objectives
- Deploy NVIDIA and AMD GPU operators
- Setup GPU node pools with MIG configuration
- Configure GPU scheduling rules and monitoring
- Validate vLLM and model-serving pods

### Deliverables
- GPU operator Helm charts
- Node pool Terraform configs with taints/labels
- Example model-serving setup (vLLM or KServe)

---

## 🚧 Phase 4: DevOps, CI/CD & Automation

### Objectives
- Integrate GitHub Actions workflows for Terraform and Kubernetes
- Implement advanced security scanning (SAST, DAST, SCA)
- Develop GitHub Actions workflow templates (plan, apply, promote)
- Automate common operational tasks

### Deliverables
- GitLab pipeline templates (plan, apply, promote)
- SOPS/SealedSecrets (optional dev use)
- RBAC templates for developer, ops, and bot roles
- Documentation and Makefile for infra automation

### Outcome
- Streamlined, secure, and automated software delivery lifecycle

---

## 🚧 Phase 5: AI Stack Enablement

### Objectives
- Setup experiment tracking (MLflow, W&B)
- Deploy vector database (Qdrant, Cosmos Mongo)
- Integrate RAG/MCP pipelines
- Add persistent storage for models

### Deliverables
- AI tool Helm/Kustomize manifests
- Data lake connector templates
- App examples using agent orchestration

---

## 🚧 Phase 6: Monitoring, Security, and Cost Controls

### Objectives
- Custom dashboards for AI metrics and GPU
- Image vulnerability scanning and alerts
- Cost dashboards by namespace/project
- Security hardening (network policies, Kyverno, Defender)

### Deliverables
- Grafana dashboards
- Trivy scanning pipeline jobs
- Compliance policy definitions
- Alerting rules and runbooks

---

## 🚀 Future Plans (Optional)

- Multi-cloud enablement with abstracted modules
- Self-serve developer portals for app scaffolds
- ChatOps integrations for deployments
- Fallback to open-source LLMs with auto-switching

---

## 📝 Maintenance & Versioning

- Version platform modules per release
- Maintain compatibility docs per AKS version
- Schedule rotation checks and drift detection monthly
- Maintain a roadmap changelog in GitOps repo
