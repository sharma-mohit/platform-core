# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - YYYY-MM-DD

### Fixed
- **Critical Issues Resolution**: Fixed critical implementation issues in observability infrastructure
  - Added missing `location_short` variable to `ops-uaenorth` environment
  - Added missing `kubelet_identity_object_id` output to AKS module
  - Added Terraform state variables to both `dev-uaenorth` and `ops-uaenorth` environments
  - Populated empty kustomization files with placeholder content and documentation
  - Fixed cross-environment remote state data sharing configuration
  - Ensured all observability components have proper directory structure and documentation

### Added
- **Observability Infrastructure Implementation**: Created Terraform modules for centralized observability stack
  - Created `terraform/modules/observability-central` module for ops cluster components:
    - Storage accounts for Mimir, Loki, and Tempo
    - Storage containers for each component
    - Key Vault secrets for storage access keys
    - Grafana admin password generation
  - Created `terraform/modules/observability-agent` module for workload clusters:
    - Key Vault access policy for agent clusters
    - Integration with central observability components
  - Added `terraform/envs/ops-uaenorth/observability-central.tf` for central deployment
  - Added `terraform/envs/dev-uaenorth/observability-agent.tf` for agent deployment
  - Configured remote state data sharing between environments
  - Created directory structure in `flux-config/` for all observability components
- Kustomize with FluxCD to project documentation (`PRD.md`, `ROADMAP.md`, `platform-core-plan.md`) to reflect its use in the GitOps strategy.
- **Phase 2 Implementation Guide** (`docs/phase2-howto.md`) - Comprehensive guide for GitOps & Platform Bootstrap including:
  - FluxCD bootstrap strategy with Kustomize overlays
  - Core platform services (NGINX Ingress, cert-manager, External Secrets Operator)
  - Observability stack (Prometheus, Grafana, Loki, Tempo)
  - Step-by-step implementation instructions
  - Security considerations and troubleshooting guide
- **GitLab to GitHub Migration Guide** (`docs/GITLAB-TO-GITHUB-MIGRATION.md`) - Complete migration documentation including:
  - Step-by-step migration process with code examples
  - Effort assessment and timeline (8-15 hours total)
  - CI/CD pipeline conversion (GitLab CI/CD to GitHub Actions)
  - Authentication and secrets migration procedures
  - Rollback plan and emergency procedures
  - Testing and validation checklists
- **Week 1 Prerequisites Validation Script** (`scripts/validate-week1-prerequisites.sh`) - Automated validation for Phase 2 Week 1 prerequisites including:
  - CLI tools verification (FluxCD, kubectl, Azure CLI, kustomize)
  - Azure authentication and AKS cluster access validation
  - ACR and Key Vault connectivity checks
  - SSH keys and network connectivity verification
  - Environment readiness assessment
- **Documentation Organization** - Created `docs/` directory structure:
  - Moved all top-level documentation files to `docs/` directory
  - Moved `terraform/docs/phase1-howto.md` to `docs/phase1-howto.md`
  - Kept only `README.md` and `CHANGELOG.md` at project root
  - Updated README.md with proper references to documentation in `docs/`
  - Updated all file references and relative paths for moved documentation
- **Documentation Standardization** - Standardized naming and structure:
  - Renamed `PHASE2-PLAN.md` to `phase2-howto.md` for consistency with `phase1-howto.md`
  - Restructured Phase 2 content to match Phase 1 implementation guide format
  - Updated all references to use consistent naming convention
  - Aligned content structure with step-by-step implementation approach
- Initialized `flux-config` directory for FluxCD GitOps.
  - Created `flux-config/README.md`.
  - Created `flux-config/clusters/platform-core-dev-aks/namespaces/namespaces.yaml` with `dev-backend`, `dev-frontend`, `ingress-nginx`, `cert-manager` namespaces.
  - Created `flux-config/clusters/platform-core-dev-aks/sources/helm-repositories.yaml` for `ingress-nginx` and `jetstack` (cert-manager).
  - Created `flux-config/clusters/platform-core-dev-aks/helmreleases/ingress-nginx.yaml`.
  - Created `flux-config/clusters/platform-core-dev-aks/helmreleases/cert-manager.yaml`.
  - Created `flux-config/clusters/platform-core-dev-aks/infrastructure/letsencrypt-staging-issuer.yaml`.
  - Created `flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml` to manage namespaces, sources, Helm releases, and infrastructure.
- Created `terraform/docs/phase2-week1-fluxcd-setup.md` to guide FluxCD bootstrapping on AKS.

### Updated
- **Phase 2 Guide GitLab Integration** - Updated `docs/phase2-howto.md` to be GitLab-specific:
  - GitLab Deploy Keys configuration for FluxCD access
  - GitLab CI/CD pipeline integration for manifest validation
  - GitLab webhook configuration for automatic reconciliation
  - GitLab-specific troubleshooting and validation criteria
  - GitLab Runner connectivity requirements
- **README.md Quick Start Section** - Updated to reference phase-specific implementation guides:
  - Added Phase 1 and Phase 2 implementation steps
  - Referenced documentation in `docs/` directory
  - Added implementation guides section with direct links
  - Included FluxCD verification commands

### Changed
- Refactored `flux-config` directory structure for `platform-core-dev-aks` cluster:
  - Created dedicated `infrastructure` directory containing subdirectories for `namespaces`, `helm-repositories`, `helm-releases`, and `cluster-issuers`.
  - Moved existing namespace, Helm repository, Helm release (Nginx, Cert-Manager), and ClusterIssuer configurations to the new `infrastructure` subdirectories.
  - Created an `apps` directory (with a `.gitkeep` placeholder) for future application deployments.
  - Updated `flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml` to orchestrate synchronization of the new `infrastructure` and `apps` paths with correct dependencies.
  - Updated `flux-config/README.md` and `terraform/docs/phase2-week1-fluxcd-setup.md` to reflect the new structure and the updated `flux bootstrap` path.
- **Adopted Base and Overlays Pattern for FluxCD Configuration**:
  - Created `flux-config/bases/` directory for common service definitions (ingress-nginx, cert-manager).
    - Each base service (e.g., `flux-config/bases/ingress-nginx/`) contains its `helmrelease.yaml` and a `kustomization.yaml`.
  - Refactored `flux-config/clusters/platform-core-dev-aks/infrastructure/` to use overlays:
    - Created `components/` subdirectory (e.g., `flux-config/clusters/platform-core-dev-aks/infrastructure/components/ingress-nginx/kustomization.yaml`) to point to bases and apply cluster-specific patches.
    - Removed old HelmReleases from `flux-config/clusters/platform-core-dev-aks/infrastructure/helm-releases/`.
  - Updated `flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml`:
    - Renamed `infra-helm-releases` Kustomization to `infra-components` and updated its path.
    - Ensured correct dependencies and removed obsolete Kustomization entries from previous structure.
  - Updated `flux-config/README.md` and `terraform/docs/phase2-week1-fluxcd-setup.md` to detail the new base and overlays structure and management workflow.
- Created `flux-config/flux-howto.md` as the central operational guide for managing the FluxCD setup (cluster configuration, application deployment, base/overlays pattern, troubleshooting).
- Streamlined `terraform/docs/phase2-week1-fluxcd-setup.md` to focus on initial FluxCD bootstrapping and link to `flux-config/flux-howto.md` for ongoing operational details.
- Updated `flux-config/README.md` to primarily reference `flux-config/flux-howto.md` for detailed usage.
- Refactored `ClusterIssuer` management to follow base/overlay pattern:
  - Moved `letsencrypt-staging-issuer.yaml` to `flux-config/bases/cluster-issuers/letsencrypt-staging/`.
  - Created corresponding overlay Kustomization in `flux-config/clusters/platform-core-dev-aks/infrastructure/cluster-issuers/letsencrypt-staging/`.
  - Updated `flux-config/clusters/platform-core-dev-aks/infrastructure/cluster-issuers/kustomization.yaml` to use the new overlay structure.
  - Updated `flux-config/flux-howto.md` to reflect this change.
- Migrated the entire code system from GitLab to GitHub. This includes:
  - Updated FluxCD configurations to use GitHub as the source repository (e.g., `GitRepository` resources, bootstrap commands).
  - Modified CI/CD pipelines from GitLab CI to GitHub Actions.
  - Updated authentication mechanisms (e.g., deploy keys, secrets) for GitHub.
  - Revised documentation (`flux-config/README.md`, `docs/GITLAB-TO-GITHUB-MIGRATION.md`, and other relevant files) to reflect GitHub usage, commands, and links.

### Fixed
- Corrected resource group scoping in `terraform/modules/*/main.tf` to use module-specific resource groups patterns instead of a shared variable.
- Enabled OIDC Issuer and Workload Identity on AKS cluster (`terraform/modules/aks/main.tf`) for Azure AD Workload Identity integration.

## [Week 3] - 2024-12-19

### Added
- **Week 3 Observability Stack Plan**: Created comprehensive deployment plan for full observability stack
  - LGTM stack (Loki, Grafana, Tempo, Mimir) + Prometheus integration
  - OpenTelemetry collector configuration for metrics, logs, and traces
  - 5-phase implementation strategy over 10 days
  - Azure Blob Storage backend configuration for all components
  - Pre-built dashboards for infrastructure, applications, and GPU monitoring
  - Advanced alerting rules for Kubernetes and GPU workloads
  - Security considerations and RBAC configurations
  - Performance testing and validation strategies

### Components Planned
- **Metrics**: Prometheus (short-term) + Mimir (long-term storage)
- **Logging**: Loki with Promtail collection agents
- **Tracing**: Tempo for distributed tracing
- **Visualization**: Grafana with multi-data source integration
- **Collection**: OpenTelemetry Operator with Gateway and Agent modes
- **Storage**: Azure Blob Storage for all persistent data

### Documentation
- `docs/WEEK3-OBSERVABILITY-PLAN.md`: Complete 10-day implementation plan
- Architecture diagrams and component breakdown
- Directory structure for Terraform modules and FluxCD manifests
- Configuration examples and YAML templates
