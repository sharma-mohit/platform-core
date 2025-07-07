# Phase 1: Terraform Azure Infrastructure - Architecture

This document outlines the architecture and design principles for provisioning the Azure infrastructure using Terraform for the AI Platform, including sovereign cloud compliance and customer-managed key encryption.

## Table of Contents

- [Overall Design Principles](#overall-design-principles)
- [Directory Structure](#directory-structure)
- [Environment Strategy](#environment-strategy)
  - [Shared Resources](#shared-resources)
  - [Environment-Specific Resources](#environment-specific-resources)
- [Terraform Backend](#terraform-backend)
- [Resource Naming Conventions](#resource-naming-conventions)
- [Core Infrastructure Components](#core-infrastructure-components)
  - [Resource Groups](#resource-groups)
  - [Networking](#networking)
    - [Virtual Network (VNet)](#virtual-network-vnet)
    - [Subnets](#subnets)
    - [Network Security Groups (NSGs)](#network-security-groups-nsgs)
  - [Azure Kubernetes Service (AKS)](#azure-kubernetes-service-aks)
    - [Node Pools (System and User)](#node-pools-system-and-user)
    - [CNI Networking](#cni-networking)
    - [Integration with ACR and Key Vault](#integration-with-acr-and-key-vault)
    - [Managed Identity](#managed-identity)
    - [Disk Encryption with Customer-Managed Keys](#disk-encryption-with-customer-managed-keys)
  - [Azure Container Registry (ACR)](#azure-container-registry-acr)
  - [Azure Key Vault (AKV)](#azure-key-vault-akv)
  - [Log Analytics Workspace](#log-analytics-workspace)
- [Sovereign Cloud Compliance](#sovereign-cloud-compliance)
- [Customer-Managed Key Encryption](#customer-managed-key-encryption)
- [Terraform Modules](#terraform-modules)
  - [Module Design](#module-design)
  - [Standard Module Files](#standard-module-files)
- [Security Considerations](#security-considerations)

## Overall Design Principles

- **Modularity**: Infrastructure is broken down into reusable Terraform modules (e.g., `network`, `aks`, `acr`, `keyvault`).
- **Scalability**: Designed to support multiple environments (dev, staging, production) with clear separation.
- **Idempotency**: Terraform configurations can be applied multiple times with the same result.
- **Security**: Emphasis on secure defaults, use of Managed Identities, customer-managed key encryption, and integration with Azure Key Vault for secrets.
- **Sovereign Compliance**: Adherence to UAE sovereign cloud policies including customer-managed key encryption and required resource tags.
- **Cost-Effectiveness**: Configurable resource SKUs and counts to manage costs per environment.

## Directory Structure

The Terraform configuration is organized as follows:

```
terraform/
├── modules/                  # Reusable Terraform modules
│   ├── aks/
│   ├── acr/
│   ├── keyvault/
│   ├── network/
│   ├── disk-encryption/      # Customer-managed key encryption
│   └── ...                   # Other common modules
├── envs/                     # Environment-specific configurations
│   ├── <environment_name>/   # e.g., dev-uaenorth
│   │   ├── main.tf           # Root module for the environment
│   │   ├── variables.tf      # Environment-specific variable declarations
│   │   ├── terraform.tfvars  # Environment-specific variable values
│   │   └── backend.hcl       # Backend configuration for this environment
│   └── ...
├── shared/                   # Shared configurations and variable definitions
│   ├── variables.tf          # Common variable definitions across all environments
│   ├── common.tfvars         # Common variable values (defaults)
│   └── backend.tf            # Backend configuration (template, actual values in envs/)
└── scripts/                  # Utility scripts (e.g., backend setup)
    ├── setup-terraform-backend.sh
    └── setup-ops-terraform-backend.sh
```

## Environment Strategy

Each environment (e.g., `dev-uaenorth`, `stg-uaecentral`, `prd-uaenorth`) will have its own dedicated set of resources, managed by its own Terraform state file.

### Shared Resources

- **Terraform State Storage Account**: A single Azure Storage Account (potentially with separate containers per environment) is used to store Terraform state files. This storage account is created manually or via a separate, one-time Terraform setup.
- **Azure Container Registry (ACR)**: While each environment might have dedicated repositories or tags, a single ACR instance can be shared across non-production environments to save costs, with stricter separation for production. The current setup provisions one ACR per environment defined by the root module.
- **Global Services**: Services like Azure Active Directory are inherently shared.

### Environment-Specific Resources

Each environment defined under `terraform/envs/` will provision:
- Its own Resource Group(s).
- Its own Virtual Network (VNet) and subnets.
- Its own AKS cluster.
- Its own Azure Key Vault.
- Its own Log Analytics Workspace.
- Its own customer-managed encryption keys.

## Terraform Backend

- **Type**: Azure Storage (`azurerm` backend).
- **Configuration**:
  - Defined in `terraform/shared/backend.tf` (as a template).
  - Actual values (storage account name, container name, key for state file) are provided per environment in `terraform/envs/<environment_name>/backend.hcl`.
- **State Locking**: Native Azure Blob Storage locking is utilized.
- **Customer-Managed Key Encryption**: State storage accounts use customer-managed keys for encryption compliance.

## Resource Naming Conventions

Resources are named consistently using a pattern:
`<resource_type_abbreviation>-<project_name>-<environment>-<region_abbreviation>-<instance_number>`
Example: `rg-platformcore-dev-uaen-001`, `aks-platformcore-dev-uaen-001`

The modules internally construct these names based on input variables like `project`, `environment`, and `location`.

## Core Infrastructure Components

### Resource Groups
- A primary resource group is created per environment to hold most of the environment's resources (e.g., `rg-aks-<env>-<loc>-001`).
- A separate resource group is used for the Terraform state backend (e.g., `rg-tfstate-<env>-001`).
- Required sovereign cloud tags are applied to all resource groups.

### Networking

#### Virtual Network (VNet)
- A dedicated VNet is provisioned for each environment.
- Address space is configurable per environment.
- Network policies are enabled for enhanced security.

#### Subnets
- Multiple subnets are created within each VNet, typically for:
  - AKS nodes (`aks-subnet`)
  - Other services as needed (e.g., Application Gateway, databases)
- Subnet address prefixes are configurable.
- Service endpoints are enabled for Azure services.

#### Network Security Groups (NSGs)
- NSGs are applied to subnets to control inbound and outbound traffic.
- AKS typically manages its own NSG rules on its subnet or node resource group.
- Default deny rules with explicit allow rules for required traffic.

### Azure Kubernetes Service (AKS)

- **Provisioning**: Managed by the `aks` module.
- **Kubernetes Version**: Configurable, defaults to a recent stable version.
- **Networking**: Azure CNI is used for pod networking, allowing pods to get IP addresses from the VNet.
- **RBAC**: Azure AD integration for Kubernetes RBAC is enabled.
- **Workload Identity**: Enabled for secure pod-to-Azure service authentication.

#### Node Pools (System and User)
- **System Node Pool**: Dedicated to running critical system pods (e.g., CoreDNS, tunnelfront).
- **User Node Pool**: For running application workloads. Configurable for CPU or GPU optimized VMs. Auto-scaling is supported.
- VM sizes and counts are configurable per environment and node pool type.
- **GPU Node Pools**: Support for NVIDIA H100 and AMD GPUs with proper node labeling and taints.

#### Integration with ACR and Key Vault
- AKS is granted pull access to the environment's ACR.
- AKS integrates with Azure Key Vault using the Azure Key Vault Provider for Secrets Store CSI Driver, allowing pods to mount secrets from AKV.
- Workload Identity is used for secure authentication between AKS and Azure services.

#### Managed Identity
- AKS uses a system-assigned or user-assigned Managed Identity for its operations and interactions with other Azure services (e.g., ACR, AKV, Azure Monitor).

#### Disk Encryption with Customer-Managed Keys
- **Disk Encryption Set**: A dedicated Disk Encryption Set is created for each environment.
- **Customer-Managed Key**: Uses a customer-managed key stored in Azure Key Vault for encrypting managed disks.
- **Key Vault Integration**: The Disk Encryption Set is configured to use a customer-managed key from the environment's Key Vault.
- **Compliance**: Ensures compliance with sovereign cloud requirements for customer-managed key encryption.

### Azure Container Registry (ACR)
- **Provisioning**: Managed by the `acr` module.
- **SKU**: Configurable (e.g., Basic, Standard, Premium).
- **Access**: Integrated with AKS for image pulls.
- **Network Security**: Private endpoints and network rules for secure access.
- **Customer-Managed Key Encryption**: ACR content is encrypted using customer-managed keys.

### Azure Key Vault (AKV)
- **Provisioning**: Managed by the `keyvault` module.
- **SKU**: Configurable.
- **Access Policies**: Configured to allow access for AKS (via its Managed Identity) and potentially other services or users/groups.
- **Secrets**: Stores sensitive information like API keys, connection strings, and certificates.
- **Customer-Managed Key Encryption**: Key Vault itself uses customer-managed keys for encryption.
- **Network Security**: Private endpoints and network rules for secure access.

### Log Analytics Workspace
- Used for collecting logs and metrics from AKS (Container Insights) and other Azure resources.
- Provisioned per environment to segregate monitoring data.
- Customer-managed key encryption for workspace data.

## Sovereign Cloud Compliance

### Required Resource Tags
All resources must include the following tags to comply with UAE sovereign cloud policies:
- `createdBy`: Identifies the creation method (e.g., "Terraform")
- `environment`: Environment identifier (dev, stg, prd)
- `project`: Project identifier
- `region`: Azure region
- `costCenter`: Cost allocation center
- `owner`: Resource owner or team

### Customer-Managed Key Requirements
- **Storage Accounts**: All storage accounts must use customer-managed keys for encryption.
- **Key Vault**: Key Vault must use customer-managed keys for encryption.
- **AKS**: Managed disks must be encrypted with customer-managed keys.
- **ACR**: Container registry content must be encrypted with customer-managed keys.

### Network Security
- **Private Endpoints**: All Azure services must use private endpoints where available.
- **Network Rules**: Explicit network rules to deny public access and allow only required traffic.
- **Service Endpoints**: Enabled for Azure services to improve security and performance.

## Customer-Managed Key Encryption

### Architecture Overview
The customer-managed key encryption is implemented using a hierarchical approach:

1. **Key Vault**: Stores the customer-managed keys used for encryption
2. **Disk Encryption Set**: References the customer-managed key for AKS disk encryption
3. **Storage Account**: Uses customer-managed keys for blob and file encryption
4. **ACR**: Uses customer-managed keys for container image encryption

### Implementation Details

#### Key Vault Setup
- Customer-managed key is created in Key Vault
- Key has appropriate permissions for encryption/decryption operations
- Key rotation policies are configured

#### Disk Encryption Set
- Created per environment
- References the customer-managed key from Key Vault
- Applied to AKS node pools for managed disk encryption

#### Storage Account Encryption
- Storage account is configured with customer-managed key encryption
- Key URI points to the customer-managed key in Key Vault
- User-assigned managed identity is used for key access

#### ACR Encryption
- Container registry is configured with customer-managed key encryption
- Key URI points to the customer-managed key in Key Vault
- User-assigned managed identity is used for key access

### Security Considerations
- **Key Access**: Only authorized managed identities can access the customer-managed keys
- **Key Rotation**: Regular key rotation policies are implemented
- **Audit Logging**: All key operations are logged for compliance
- **Backup**: Key backup and recovery procedures are in place

## Terraform Modules

### Module Design
- Each module in `terraform/modules/` is responsible for a specific set of resources (e.g., `network` module handles VNet, subnets).
- Modules are designed to be reusable across different environments.
- Inputs and outputs are clearly defined.
- Customer-managed key encryption is integrated into relevant modules.

### Standard Module Files
- `main.tf`: Contains the resource definitions.
- `variables.tf`: Defines input variables for the module.
- `outputs.tf`: Defines outputs from the module.
- `README.md`: Documents the module's purpose, inputs, outputs, and usage.

### New Modules
- **`disk-encryption/`**: Handles customer-managed key encryption for AKS managed disks
- **`firewall/`**: Manages Azure Firewall for egress traffic control
- **`gitops/`**: Manages GitOps-related resources

## Security Considerations

- **Least Privilege**: Managed Identities are used to grant Azure resources only the necessary permissions.
- **Network Security**: NSGs and private endpoints (where applicable) are used to restrict network access.
- **Secrets Management**: Azure Key Vault is central to managing secrets securely.
- **Customer-Managed Keys**: All encryption uses customer-managed keys for compliance and control.
- **Monitoring and Auditing**: Azure Monitor and Log Analytics provide capabilities for monitoring and auditing.
- **Provider Configuration**: `skip_provider_registration = true` is used in the `azurerm` provider block to avoid issues in environments with restricted permissions for provider registration. This assumes providers are already registered in the subscription.
- **Regular Updates**: Kubernetes versions, provider versions, and module sources should be regularly reviewed and updated.
- **Sovereign Compliance**: All resources comply with UAE sovereign cloud policies including required tags and encryption requirements. 