# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - YYYY-MM-DD

### Added
- **Comprehensive Implementation Guide**: Created consolidated `docs/IMPLEMENTATION-GUIDE.md` for complete platform deployment:
  - **All Phases Covered**: Step-by-step instructions for Phases 1-6 with clear objectives and expected outputs
  - **Verification Steps**: Comprehensive health checks and testing procedures for each phase
  - **Troubleshooting Section**: Common issues and solutions for all components
  - **Next Steps Guidance**: Immediate actions and future enhancements
  - **Consolidated Approach**: Combines best practices from all existing phase guides into single document
- **Documentation Index**: Created `docs/README.md` for improved documentation navigation:
  - **Use Case Navigation**: Quick links organized by user needs (new user, deployment, architecture, operations)
  - **Documentation Flow**: Visual diagram showing relationships between documents
  - **Finding Information**: Categorized search for specific topics
  - **Documentation Standards**: Guidelines for maintaining consistent documentation
  - **Help Resources**: Clear guidance on where to get help

### Fixed
- **Kubernetes Version Update** (`terraform/modules/aks/variables.tf`, `terraform/shared/common.tfvars`, `terraform/envs/*/terraform.tfvars`): Updated Kubernetes version from 1.30.4 to 1.34.1:
  - **Updated module default**: Changed default Kubernetes version in AKS module to 1.34.1
  - **Updated shared configuration**: Updated common.tfvars to use 1.34.1
  - **Updated environment configs**: Updated both dev and ops environment tfvars files
  - **Updated documentation**: Updated AKS module README to reflect new version
  - **Resolves LTS requirement error**: Version 1.30.4 required Long-Term Support (LTS) with Premium tier, 1.34.1 is available without LTS requirement
- **Disk Encryption Set Key Vault Access** (`terraform/modules/disk-encryption/main.tf`, `terraform/modules/disk-encryption/outputs.tf`): Fixed Key Vault access for disk encryption set to use RBAC instead of access policies:
  - **Replaced access policy with RBAC role assignment**: Changed from `azurerm_key_vault_access_policy` to `azurerm_role_assignment` with "Key Vault Crypto Service Encryption User" role
  - **RBAC compatibility**: Key Vault uses RBAC authorization (`enable_rbac_authorization = true`), so access policies don't work
  - **Updated outputs**: Changed output to reference role assignment ID instead of access policy ID
  - **Resolves KeyVaultAccessForbidden error**: Fixes disk encryption errors when creating AKS cluster with customer-managed keys
  - **Maintains dependency tracking**: Output still provides ID for dependency management in AKS module
- **Key Vault Network ACLs for Disk Encryption** (`terraform/modules/keyvault/main.tf`, `terraform/modules/keyvault/variables.tf`, `terraform/envs/dev-uaenorth/main.tf`): Fixed Key Vault network access for disk encryption set:
  - **Added AKS subnet to network ACLs**: Added `allowed_subnet_ids` variable to Key Vault module to allow additional subnets (e.g., AKS subnet) to access Key Vault
  - **Enabled disk encryption**: Added `enabled_for_disk_encryption = true` to Key Vault configuration (required for disk encryption sets)
  - **Network access for VMSS**: AKS node pools (VMSS) need network access to Key Vault for disk encryption operations
  - **Resolves VMSS creation failure**: Fixes "Unable to access key vault resource" error when creating AKS node pools with customer-managed key encryption
  - **Maintains security**: Network ACLs still restrict access to specified subnets while allowing disk encryption operations
- **Dev Environment Terraform Remote State Configuration** (`terraform/envs/dev-uaenorth/main.tf`): Fixed remote state data source configuration for ops environment:
  - **Corrected container name**: Changed from `"tfstate"` to `"tfstate-ops-uaenorth"` to match ops backend configuration
  - **Corrected state key**: Changed from `"ops-uaenorth.terraform.tfstate"` to `"platform-core-ops.tfstate"` to match ops backend configuration
  - **Commented out unused data source**: Since the observability-agent module is commented out, the remote state data source is also commented out with clear instructions for when to uncomment it
  - **Resolves ContainerNotFound error**: Fixes the 404 error when planning dev cluster before ops environment is initialized
  - **Enables independent deployment**: Dev cluster can now be planned/deployed without requiring ops environment to be initialized first
- **Terraform Backend Resource Group Standardization**: Aligned all environments to use shared resource group approach as intended in architecture:
  - **Updated `scripts/setup-terraform-backend.sh`**: Modified to create shared resource group `rg-tfstate-platformcore-shared-uaen-001` instead of individual resource groups
  - **Updated backend configurations**: Both `dev-uaenorth` and `ops-uaenorth` environments now use the shared resource group
  - **Container separation**: Each environment uses separate containers (`tfstate-dev-uaenorth`, `tfstate-ops-uaenorth`) within the shared storage account
  - **Removed ops-specific script**: Deleted `scripts/setup-ops-terraform-backend.sh` as it's no longer needed with shared approach
  - **Updated terraform.tfvars**: Both environments now reference the shared resource group name
  - **Architecture compliance**: Aligns with documented shared resources approach in `docs/phase1-terraform-architecture.md`
  - **Cost optimization**: Reduces resource group overhead while maintaining environment isolation through separate containers

### Updated
- **Documentation Architecture Updates**: Updated all architectural documentation to reflect latest infrastructure changes:
  - **Customer-Managed Key Encryption**: Added comprehensive documentation for customer-managed key encryption across all Azure resources
    - Updated `docs/phase1-terraform-architecture.md` with customer-managed key architecture and implementation details
    - Added sovereign cloud compliance section with required tags and encryption requirements
    - Documented disk encryption set configuration for AKS managed disks
    - Added storage account and ACR encryption with customer-managed keys
  - **Sovereign Cloud Compliance**: Enhanced documentation for UAE sovereign cloud compliance
    - Required resource tags (createdBy, environment, project, region, costCenter, owner)
    - Private endpoints for all Azure services
    - Network security with default deny policies
    - Service endpoints for Azure services
    - Audit logging and compliance reporting
  - **Centralized Multi-Cluster Observability**: Updated documentation to reflect completed observability implementation
    - Centralized LGTM stack (Loki, Grafana, Tempo, Mimir) in ops cluster
    - Lightweight agents on workload clusters (OpenTelemetry, Prometheus Agent, Promtail)
    - Multi-cluster dashboards and cross-cluster alerting
    - Single pane of glass for all environments
  - **Updated Implementation Guides**: Enhanced all how-to guides with latest architecture
    - `docs/phase1-terraform-execution-guide.md`: Added customer-managed key setup and verification
    - `docs/phase1-howto.md`: Updated with sovereign compliance and encryption requirements
    - `docs/PRD.md`: Updated to reflect centralized observability and compliance requirements
    - `docs/ROADMAP.md`: Updated phases to include completed observability implementation
    - `docs/platform-core-plan.md`: Added compliance and security sections
  - **New Modules Documentation**: Added documentation for new Terraform modules
    - `disk-encryption/`: Customer-managed key encryption for AKS managed disks
    - `firewall/`: Azure Firewall for egress traffic control
    - `observability-central/`: Centralized observability stack components
    - `observability-agent/`: Lightweight collection agents for workload clusters

### Fixed
- **Dev Environment Sovereign Policy Compliance** (`terraform/envs/dev-uaenorth/terraform.tfvars`) - Aligned dev environment with ops environment for UAE Cloud Sovereign Policies:
  - Added missing `Sovereignty = "Confidential"` tag to dev environment tags
  - Fixed project name consistency from `platform-core-v2` to `platform-core` to match ops environment
  - Corrected Terraform state configuration to use proper dev environment storage account and resource group
  - Ensures both dev and ops environments comply with sovereign policy requirements
  - Maintains consistency in resource naming and tagging across all environments
- **Dev Environment State File Naming** (`terraform/envs/dev-uaenorth/backend.hcl`) - Updated state file name to match ops environment format:
  - Changed state file key from `dev.terraform.tfstate` to `platform-core-dev.tfstate`
  - Aligns with ops environment naming convention (`platform-core-ops.tfstate`)
  - Ensures consistent state file naming across all environments
  - Maintains clear environment identification in state file names

### Added
- **Terraform Workspace Integration** (`docs/phase3-howto.md`) - Updated Phase 3 guide to use Terraform workspaces for environment isolation:
  - Added workspace creation and selection steps for both `ops` and `dev` environments
  - Documented workspace benefits: state isolation, resource separation, simplified management, environment safety
  - Enhanced troubleshooting section with workspace-specific issues and solutions
  - Updated step numbering to accommodate new workspace management steps
  - Ensures proper state isolation between environments while using same backend configuration

### Fixed
- **Resource Naming Corrections** (`docs/phase3-howto.md`) - Fixed incorrect resource names in verification commands:
  - Corrected AKS cluster name from `aks-platform-core-ops-uaen-001` to `platform-core-ops-aks`
  - Updated resource group reference from `rg-aks-ops-uaen-001` to `rg-aks-ops-uaenorth-001`
  - Fixed Key Vault name from `kv-platform-core-ops-uaen-001` to `platform-core-ops-kv`
  - Ensures commands match actual Terraform resource naming conventions
- **Ops Cluster Backend Setup Script** (`scripts/setup-ops-terraform-backend.sh`) - Automated script for creating Terraform state storage for the ops cluster:
  - Creates dedicated resource group `rg-tfstate-ops-001`
  - Provisions storage account `platformcoretfstateops` with security best practices
  - Enables versioning and soft delete for state recovery
  - Creates `tfstate` container for ops cluster state
  - Provides clear output with next steps for Terraform initialization
- **Enhanced Phase 3 Implementation Guide** (`docs/phase3-howto.md`) - Updated with complete ops cluster deployment process:
  - Added Step 1: Terraform state setup for ops cluster with automated script option
  - Detailed infrastructure deployment steps with verification
  - Enhanced troubleshooting section with specific issues
  - Improved step numbering and organization
  - Added verification commands for all deployment stages

### Fixed
- **UAE Cloud Sovereign Policy Compliance**: Fixed storage account creation to comply with customer-managed key (CMK) encryption requirements:
  - Updated `scripts/setup-ops-terraform-backend.sh` to create Key Vault and configure storage account with CMK encryption
  - Updated `docs/phase3-howto.md` manual setup instructions to include Key Vault creation and CMK configuration
  - Added proper RBAC role assignments for Key Vault access
  - Ensures compliance with UAE Cloud Sovereign Policies (G42_19_StorageAccount_CMKEnable)
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

### Removed
- **Redundant Ops Cluster Guide** (`docs/ops-cluster-deployment-guide.md`) - Removed to eliminate confusion and maintain single source of truth in `docs/phase3-howto.md`

## [Unreleased]

### Added
- **Week 3 Observability Implementation**: Complete implementation of missing observability components for dev and ops clusters
  - OpenTelemetry Collector deployment for workload clusters
  - Multi-cluster Grafana dashboards with actual content
  - AlertManager configuration with multi-cluster alerting
  - Cross-cluster networking and DNS resolution
  - Complete workload cluster agent deployment
  - Multi-tenant data sources for Grafana
  - Environment-aware alert rules
  - RBAC and security configurations

### Changed
- Enhanced Grafana configuration with multi-tenant data sources
- Updated Prometheus agent configuration for proper cluster identification
- Improved Promtail configuration for cross-cluster log forwarding

### Fixed
- Empty dashboard JSON files now contain actual dashboard definitions
- Missing OpenTelemetry collector configurations implemented
- AlertManager placeholder replaced with actual implementation
- Cross-cluster connectivity issues resolved

### Security
- **CRITICAL**: Removed hardcoded IP addresses from Terraform configuration
  - Replaced hardcoded IPs in Key Vault firewall rules with environment variables
  - Added `allowed_ip_ranges` variable to both dev and ops environments
  - Updated documentation with proper IP configuration instructions
  - This prevents exposure of real IP addresses in version control

### Documentation
- Added security considerations section to Implementation Guide
- Added instructions for proper IP address configuration using environment variables

## [2024-01-XX] - Documentation Consolidation
