# Phase 1: Terraform Azure Infrastructure - Architecture

This document outlines the architecture and design principles for provisioning the Azure infrastructure using Terraform for the AI Platform.

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
  - [Azure Container Registry (ACR)](#azure-container-registry-acr)
  - [Azure Key Vault (AKV)](#azure-key-vault-akv)
  - [Log Analytics Workspace](#log-analytics-workspace)
- [Terraform Modules](#terraform-modules)
  - [Module Design](#module-design)
  - [Standard Module Files](#standard-module-files)
- [Security Considerations](#security-considerations)

## Overall Design Principles

- **Modularity**: Infrastructure is broken down into reusable Terraform modules (e.g., `network`, `aks`, `acr`, `keyvault`).
- **Scalability**: Designed to support multiple environments (dev, staging, production) with clear separation.
- **Idempotency**: Terraform configurations can be applied multiple times with the same result.
- **Security**: Emphasis on secure defaults, use of Managed Identities, and integration with Azure Key Vault for secrets.
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
    └── setup-terraform-backend.sh
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

## Terraform Backend

- **Type**: Azure Storage (`azurerm` backend).
- **Configuration**:
  - Defined in `terraform/shared/backend.tf` (as a template).
  - Actual values (storage account name, container name, key for state file) are provided per environment in `terraform/envs/<environment_name>/backend.hcl`.
- **State Locking**: Native Azure Blob Storage locking is utilized.

## Resource Naming Conventions

Resources are named consistently using a pattern:
`<resource_type_abbreviation>-<project_name>-<environment>-<region_abbreviation>-<instance_number>`
Example: `rg-platformcore-dev-uaen-001`, `aks-platformcore-dev-uaen-001`

The modules internally construct these names based on input variables like `project`, `environment`, and `location`.

## Core Infrastructure Components

### Resource Groups
- A primary resource group is created per environment to hold most of the environment's resources (e.g., `rg-aks-<env>-<loc>-001`).
- A separate resource group is used for the Terraform state backend (e.g., `rg-tfstate-<env>-001`).

### Networking

#### Virtual Network (VNet)
- A dedicated VNet is provisioned for each environment.
- Address space is configurable per environment.

#### Subnets
- Multiple subnets are created within each VNet, typically for:
  - AKS nodes (`aks-subnet`)
  - Other services as needed (e.g., Application Gateway, databases)
- Subnet address prefixes are configurable.

#### Network Security Groups (NSGs)
- NSGs are applied to subnets to control inbound and outbound traffic.
- AKS typically manages its own NSG rules on its subnet or node resource group.

### Azure Kubernetes Service (AKS)

- **Provisioning**: Managed by the `aks` module.
- **Kubernetes Version**: Configurable, defaults to a recent stable version.
- **Networking**: Azure CNI is used for pod networking, allowing pods to get IP addresses from the VNet.
- **RBAC**: Azure AD integration for Kubernetes RBAC is enabled.

#### Node Pools (System and User)
- **System Node Pool**: Dedicated to running critical system pods (e.g., CoreDNS, tunnelfront).
- **User Node Pool**: For running application workloads. Configurable for CPU or GPU optimized VMs. Auto-scaling is supported.
- VM sizes and counts are configurable per environment and node pool type.

#### Integration with ACR and Key Vault
- AKS is granted pull access to the environment's ACR.
- AKS integrates with Azure Key Vault using the Azure Key Vault Provider for Secrets Store CSI Driver, allowing pods to mount secrets from AKV.

#### Managed Identity
- AKS uses a system-assigned or user-assigned Managed Identity for its operations and interactions with other Azure services (e.g., ACR, AKV, Azure Monitor).

### Azure Container Registry (ACR)
- **Provisioning**: Managed by the `acr` module.
- **SKU**: Configurable (e.g., Basic, Standard, Premium).
- **Access**: Integrated with AKS for image pulls.

### Azure Key Vault (AKV)
- **Provisioning**: Managed by the `keyvault` module.
- **SKU**: Configurable.
- **Access Policies**: Configured to allow access for AKS (via its Managed Identity) and potentially other services or users/groups.
- **Secrets**: Stores sensitive information like API keys, connection strings, and certificates.

### Log Analytics Workspace
- Used for collecting logs and metrics from AKS (Container Insights) and other Azure resources.
- Provisioned per environment to segregate monitoring data.

## Terraform Modules

### Module Design
- Each module in `terraform/modules/` is responsible for a specific set of resources (e.g., `network` module handles VNet, subnets).
- Modules are designed to be reusable across different environments.
- Inputs and outputs are clearly defined.

### Standard Module Files
- `main.tf`: Contains the resource definitions.
- `variables.tf`: Defines input variables for the module.
- `outputs.tf`: Defines outputs from the module.
- `README.md`: Documents the module's purpose, inputs, outputs, and usage.

## Security Considerations

- **Least Privilege**: Managed Identities are used to grant Azure resources only the necessary permissions.
- **Network Security**: NSGs and private endpoints (where applicable) are used to restrict network access.
- **Secrets Management**: Azure Key Vault is central to managing secrets securely.
- **Monitoring and Auditing**: Azure Monitor and Log Analytics provide capabilities for monitoring and auditing.
- **Provider Configuration**: `skip_provider_registration = true` is used in the `azurerm` provider block to avoid issues in environments with restricted permissions for provider registration. This assumes providers are already registered in the subscription.
- **Regular Updates**: Kubernetes versions, provider versions, and module sources should be regularly reviewed and updated. 