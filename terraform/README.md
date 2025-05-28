# Platform Core Terraform Configuration

This directory contains the Terraform configuration for the Platform Core infrastructure. The infrastructure is organized into modules and environments following infrastructure-as-code best practices.

## Directory Structure

```
terraform/
├── docs/             # Documentation for each phase
│   └── phase1-howto.md  # Phase 1 implementation guide
├── modules/         # Reusable Terraform modules
│   ├── aks/        # Azure Kubernetes Service module
│   ├── acr/        # Azure Container Registry module
│   ├── network/    # Network infrastructure module
│   ├── keyvault/   # Azure Key Vault module
│   ├── firewall/   # Azure Firewall module
│   └── gitops/     # GitOps configuration module
├── envs/           # Environment-specific configurations
│   ├── dev-uaenorth/ # Development environment
│   ├── stg-uaenorth/ # Staging environment
│   └── prd-uaenorth/ # Production environment
└── shared/         # Shared configuration and variables
```

## Implementation Phases

The infrastructure implementation is divided into phases, each with its own documentation:

1. [Phase 1](docs/phase1-howto.md) - Core Infrastructure
   - Network infrastructure
   - AKS cluster
   - Azure Container Registry
   - Key Vault
   - Basic security setup

2. Phase 2 - Coming Soon
   - Additional security features
   - Monitoring and logging
   - Backup and disaster recovery

3. Phase 3 - Coming Soon
   - GitOps configuration
   - CI/CD pipeline infrastructure
   - Additional services

## Prerequisites

1. Azure CLI installed and configured
2. Terraform >= 1.0.0
3. Azure subscription with appropriate permissions
4. Azure Storage Account for Terraform state

## Getting Started

1. Configure Azure credentials:
   ```bash
   az login
   az account set --subscription <subscription-id>
   ```

2. Follow the [Phase 1 Implementation Guide](docs/phase1-howto.md) for detailed setup instructions.

## Module Documentation

Each module has its own documentation in its respective directory:

- [Network Module](modules/network/README.md)
- [AKS Module](modules/aks/README.md)
- [ACR Module](modules/acr/README.md)
- [Key Vault Module](modules/keyvault/README.md)

## Contributing

1. Create a new branch for changes
2. Update documentation
3. Test changes in dev environment
4. Submit PR for review
5. Apply changes to staging/production after approval 