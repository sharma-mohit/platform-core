# 📘 Product Requirements Document (PRD): Modular AI Platform on Azure

## 1. Overview

This document defines the requirements for a secure, scalable, modular AI platform designed to develop and operate advanced AI products, including LLMs, agents, and enterprise applications. The platform is cloud-native, built on Azure, and entirely managed as code, including infrastructure, CI/CD, and GitOps workflows.

---

## 2. Objectives

- Support end-to-end AI product development (LLM, RAG, RAT, MCP, agents)
- Self-host LLMs like LLaMA on GPU-based Kubernetes clusters
- Use open-source components where possible
- Build full-stack AI apps, not just chatbots
- Provide enterprise-grade security, observability, and automation
- Ensure repeatable and auditable deployment workflows

---

## 3. Scope

### Included

- Multi-environment AKS deployments (`dev-uaenorth`, `stg-uaenorth`, `prd-uaenorth`)
- Infrastructure-as-code using Terraform
- GitOps integration with FluxCD and Kustomize
- GPU scheduling, monitoring, and workload optimization
- Secret management via Azure Key Vault
- TLS using custom certificates via Cloudflare
- AI tooling integration (model serving, vector DBs, experiment tracking)

### Excluded

- Managed model APIs (e.g., OpenAI)
- On-prem deployment
- Non-Azure cloud support (initial phase only)

---

## 4. Functional Requirements

### Infrastructure
- Provision AKS clusters with GPU and CPU node pools
- Configure hub-spoke network topology
- Deploy private endpoints for ACR, Key Vault, Storage
- Expose services via public and internal NGINX ingress
- Apply infrastructure RBAC and cost tagging

### GitOps
- Bootstrap FluxCD for continuous delivery
- Sync application manifests from Git using FluxCD and Kustomize
- Manage Helm releases and Kustomize overlays via GitOps
- Support for app rollback and promotion

### CI/CD
- Automate test, build, and deploy with GitHub Actions
- Run vulnerability scans (Trivy)
- Validate Terraform changes before merge
- Promote applications across environments

### GPU/AI Enablement
- Install and configure NVIDIA and AMD GPU operators
- Label and schedule GPU workloads with taints/affinities
- Deploy model serving frameworks (vLLM, KServe)
- Integrate MLflow or W&B for experiment tracking

### Secrets and Security
- Sync secrets from Azure Key Vault with ESO
- Audit and rotate service principals and secrets
- Apply Kyverno or OPA policies for runtime security
- Scan container images in CI

### Observability
- Deploy Prometheus, Grafana, Loki, Tempo
- Create custom dashboards for model and GPU performance
- Configure alerting for anomalies or drift
- Track resource and cost usage per namespace

---

## 5. Non-Functional Requirements

- High availability for critical platform components
- Modular and versioned Terraform modules
- Extensible architecture for future multi-cloud use
- Configurable through Git only (no manual operations)

---

## 6. User Roles

- **Platform Engineer**: Manages infrastructure, GitOps, observability
- **ML Engineer**: Deploys and tests models, uses GPU workloads
- **App Developer**: Builds UIs and APIs consuming AI services
- **Security & Compliance**: Audits secrets, enforces policy
- **DevOps Engineer**: Manages CI/CD and GitHub integrations

---

## 7. Milestones

- Phase 1: Core Infrastructure – AKS, ACR, Networking
- Phase 2: GitOps & Secrets – FluxCD, ESO, Key Vault
- Phase 3: GPU & Model Serving – vLLM, GPU plugins
- Phase 4: DevOps CI/CD – GitHub Actions workflows, automation
- Phase 5: AI Tools – MLflow, Qdrant, Data Lake
- Phase 6: Observability & Security – Dashboards, Scanning

---

## 8. Success Criteria

- All environments deployed fully via code
- LLM workloads successfully deployed on GPU nodes
- FluxCD fully manages all infrastructure workloads
- CI/CD runs for every commit with test and security checks
- GPU workloads monitored and optimized
- Secrets are never exposed in plaintext or stored in code

## Key Features

- AKS cluster (system/user node pools)
- Azure CNI networking
- Azure Policy integration
- Microsoft Defender for Containers
- Azure Key Vault integration
- Log Analytics integration
- Auto-scaling for node pools
- RBAC enabled
- GitOps with FluxCD (GitHub)
- Automated CI/CD with GitHub Actions

## User Stories

### DevOps Engineer

- **As a DevOps Engineer, I want to:**
  - Manage infrastructure as code using Terraform
  - Automate test, build, and deploy with GitHub Actions
  - Monitor platform health and performance
  - Implement GitOps for Kubernetes deployments
  - Secure the platform with Azure security services

## Implementation Phases

- Phase 1: Core Azure Infrastructure – AKS, ACR, Key Vault
- Phase 2: GitOps & Platform Bootstrap – FluxCD, NGINX, cert-manager
- Phase 3: Observability & Logging – Prometheus, Grafana, Loki
- Phase 4: DevOps CI/CD – GitHub Actions workflows, automation
- Phase 5: GPU Workloads & Advanced Services – GPU nodes, AI/ML tools

## Success Metrics

