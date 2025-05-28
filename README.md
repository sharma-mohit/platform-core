# Platform Core

Platform Core is a comprehensive infrastructure-as-code solution for deploying and managing enterprise-grade Kubernetes platforms on Azure. It provides a secure, scalable, and maintainable foundation for running containerized applications with built-in support for both CPU and GPU workloads.

## Purpose

This project aims to:

1. **Standardize Infrastructure**: Provide a consistent, repeatable infrastructure setup across development, staging, and production environments.

2. **Enhance Security**: Implement security best practices including:
   - Private networking with service endpoints
   - Azure Key Vault integration
   - RBAC and network policies
   - Secure container registry access

3. **Support Modern Workloads**: Enable both traditional and AI/ML workloads with:
   - AKS cluster with system and user node pools
   - GPU node pool support
   - Azure Container Registry with geo-replication
   - Integrated monitoring and logging

4. **Simplify Operations**: Reduce operational complexity through:
   - Infrastructure as Code using Terraform
   - Modular, reusable components
   - Comprehensive documentation
   - Automated deployment processes

## Project Structure

```
platform-core/
├── terraform/           # Infrastructure as Code
│   ├── docs/           # Implementation guides
│   ├── modules/        # Reusable Terraform modules
│   ├── envs/          # Environment configurations
│   └── shared/        # Shared configurations
├── scripts/            # Helper scripts
└── docs/              # Project documentation
```

## Getting Started

### Prerequisites

1. **Azure Account and Permissions**:
   - Active Azure subscription
   - Owner or Contributor role
   - Azure CLI installed and configured

2. **Development Tools**:
   - Terraform >= 1.0.0
   - Git
   - kubectl
   - Azure CLI

3. **Knowledge Requirements**:
   - Basic understanding of Azure services
   - Familiarity with Kubernetes concepts
   - Experience with Terraform
   - Understanding of infrastructure-as-code principles

### Quick Start

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-org/platform-core.git
   cd platform-core
   ```

2. **Configure Azure**:
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

3. **Set Up Terraform Backend**:
   ```bash
   cd terraform/scripts
   ./setup-terraform-backend.sh
   ```

4. **Deploy Infrastructure**:
   - Follow the [Phase 1 Implementation Guide](terraform/docs/phase1-howto.md)
   - Start with the development environment
   - Review and customize variables as needed

5. **Verify Deployment**:
   ```bash
   # Get AKS credentials
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   
   # Verify cluster access
   kubectl get nodes
   ```

## Contributing

We welcome contributions to improve Platform Core! Here's how you can help:

### Development Process

1. **Clone**:
   - Clone the repository
   - Create a feature branch from `main`

2. **Development Guidelines**:
   - Follow the existing code style and structure
   - Write clear commit messages
   - Update documentation for any changes
   - Add tests where applicable

3. **Testing Requirements**:
   - Test changes in development environment
   - Verify all modules work together
   - Ensure backward compatibility
   - Check for security implications

4. **Pull Request Process**:
   - Create a detailed PR description
   - Link related issues
   - Request reviews from maintainers
   - Address review comments
   - Ensure CI checks pass

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Follow security best practices
- Maintain professional communication

### Documentation

- Keep documentation up to date
- Add comments for complex logic
- Update README files as needed
- Document breaking changes

## Support

- **Issues**: Report bugs and feature requests in the Gitlab issue tracker
- **Security**: Report security vulnerabilities privately to the team
