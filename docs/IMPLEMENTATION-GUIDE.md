# Platform Core - Complete Implementation Guide

This comprehensive guide walks you through deploying the complete Platform Core infrastructure across all phases, from initial setup to production-ready AI platform.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Phase 1: Core Infrastructure Foundation](#phase-1-core-infrastructure-foundation)
- [Phase 2: GitOps & Platform Bootstrap](#phase-2-gitops--platform-bootstrap)
- [Phase 3: Centralized Observability Stack](#phase-3-centralized-observability-stack)
- [Phase 4: GPU & AI Workload Readiness](#phase-4-gpu--ai-workload-readiness)
- [Phase 5: DevOps CI/CD & Automation](#phase-5-devops-cicd--automation)
- [Phase 6: AI Stack Enablement](#phase-6-ai-stack-enablement)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Prerequisites

### Required Tools
- **Azure CLI** >= 2.40.0
- **Terraform** >= 1.0.0
- **kubectl** >= 1.25.0
- **FluxCD CLI** >= 0.35.0
- **Git** >= 2.30.0

### Azure Requirements
- Active Azure subscription with Owner/Contributor permissions
- UAE North region access (for sovereign cloud compliance)
- Ability to create service principals and managed identities

### Knowledge Requirements
- Basic understanding of Azure services (AKS, ACR, Key Vault)
- Familiarity with Kubernetes concepts
- Experience with Terraform and GitOps principles
- Understanding of customer-managed key encryption

## Phase 1: Core Infrastructure Foundation

### Objective
Deploy base Azure infrastructure with customer-managed key encryption, including AKS clusters, networking, and supporting services.

### Step 1.1: Initial Setup

```bash
# Clone the repository
git clone https://github.com/your-org/platform-core.git
cd platform-core

# Configure Azure
az login
az account set --subscription <your-subscription-id>

# Verify subscription
az account show --query "{name:name, id:id, tenantId:tenantId}"
```

### Step 1.2: Setup Terraform Backend

```bash
# Run the automated backend setup script
./scripts/setup-terraform-backend.sh
```

This script creates:
- Shared resource group `rg-tfstate-platformcore-shared-uaen-001`
- Storage account with customer-managed key encryption
- Key Vault for encryption keys
- Separate containers for each environment's state

### Step 1.3: Deploy Development Environment

```bash
# Navigate to dev environment
cd terraform/envs/dev-uaenorth

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Create and select workspace
terraform workspace new dev
terraform workspace select dev

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

**Expected Output**:
- AKS cluster: `platform-core-dev-aks`
- Resource group: `rg-aks-dev-uaenorth-001`
- Azure Container Registry: `platformcoredevacr`
- Key Vault: `platform-core-dev-kv`
- Virtual Network with subnets and security groups

### Step 1.4: Deploy Operations Cluster

```bash
# Navigate to ops environment
cd ../ops-uaenorth

# Initialize Terraform
terraform init -backend-config=backend.hcl

# Create and select workspace
terraform workspace new ops
terraform workspace select ops

# Review and apply
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected Output**:
- AKS cluster: `platform-core-ops-aks`
- Resource group: `rg-aks-ops-uaenorth-001`
- Storage accounts for observability data
- Central Key Vault for observability secrets

### Step 1.5: Verify Infrastructure

```bash
# Verify AKS clusters
az aks list --resource-group rg-aks-dev-uaenorth-001 --output table
az aks list --resource-group rg-aks-ops-uaenorth-001 --output table

# Verify customer-managed key encryption
az storage account show --name platformcoretfstate --resource-group rg-tfstate-platformcore-shared-uaen-001 --query encryption

# Get cluster credentials
az aks get-credentials --resource-group rg-aks-dev-uaenorth-001 --name platform-core-dev-aks
az aks get-credentials --resource-group rg-aks-ops-uaenorth-001 --name platform-core-ops-aks

# Test cluster access
kubectl get nodes
```

## Phase 2: GitOps & Platform Bootstrap

### Objective
Enable GitOps workflows with FluxCD and deploy core platform services.

### Step 2.1: Prepare GitHub Repository

```bash
# Generate SSH key for FluxCD
ssh-keygen -t ed25519 -C "fluxcd-github@platform-core" -f ~/.ssh/flux_github_deploy_key

# Display public key to add to GitHub
cat ~/.ssh/flux_github_deploy_key.pub
```

**GitHub Setup**:
1. Go to your GitHub repository → Settings → Deploy keys
2. Click "Add deploy key"
3. Title: `fluxcd-readonly-access`
4. Key: Paste the public key content
5. **Uncheck** "Allow write access"
6. Click "Add key"

### Step 2.2: Bootstrap FluxCD on Dev Cluster

```bash
# Get dev cluster credentials
az aks get-credentials --resource-group rg-aks-dev-uaenorth-001 --name platform-core-dev-aks --overwrite-existing

# Bootstrap FluxCD
flux bootstrap github \
  --owner=YOUR_GITHUB_ORG \
  --repository=YOUR_REPO_NAME \
  --branch=main \
  --path="./clusters/platform-core-dev-aks/flux-system" \
  --private-key-file=~/.ssh/flux_github_deploy_key \
  --personal
```

### Step 2.3: Bootstrap FluxCD on Ops Cluster

```bash
# Get ops cluster credentials
az aks get-credentials --resource-group rg-aks-ops-uaenorth-001 --name platform-core-ops-aks --overwrite-existing

# Bootstrap FluxCD
flux bootstrap github \
  --owner=YOUR_GITHUB_ORG \
  --repository=YOUR_REPO_NAME \
  --branch=main \
  --path="./clusters/platform-core-ops-aks/flux-system" \
  --private-key-file=~/.ssh/flux_github_deploy_key \
  --personal
```

### Step 2.4: Verify FluxCD Installation

```bash
# Check FluxCD components
kubectl get pods -n flux-system

# Check FluxCD resources
flux get kustomizations --all-namespaces
flux get sources git --all-namespaces

# Verify FluxCD health
flux check
```

**Expected Output**:
- All FluxCD controllers running in `flux-system` namespace
- GitRepository source showing `Ready: True`
- Root Kustomization reconciling successfully

## Phase 3: Centralized Observability Stack

### Objective
Deploy centralized LGTM stack with multi-cluster monitoring and alerting.

### Step 3.1: Verify Observability Deployment

The observability components are automatically deployed via FluxCD. Monitor their deployment:

```bash
# Check ops cluster observability components
kubectl get pods -n observability-grafana
kubectl get pods -n observability-mimir
kubectl get pods -n observability-loki
kubectl get pods -n observability-tempo

# Check dev cluster agents
kubectl get pods -n observability-agent-prometheus
kubectl get pods -n observability-agent-promtail
```

### Step 3.2: Access Grafana Dashboard

```bash
# Get Grafana service IP
kubectl get svc -n observability-grafana grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Default credentials (configured in flux-config)
# Username: admin
# Password: Check the secret in ops cluster
kubectl get secret -n observability-grafana grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

### Step 3.3: Verify Multi-Cluster Data Flow

```bash
# Check Prometheus Agent logs for successful remote writes
kubectl logs -n observability-agent-prometheus -l app.kubernetes.io/name=prometheus -f

# Check Promtail logs for successful log forwarding
kubectl logs -n observability-agent-promtail -l app.kubernetes.io/name=promtail -f
```

**Expected Behavior**:
- Prometheus Agent shows successful remote writes to central Mimir
- Promtail shows successful log forwarding to central Loki
- Metrics and logs appear in central Grafana dashboards

## Phase 4: GPU & AI Workload Readiness

### Objective
Configure GPU support and prepare for AI/ML workloads.

### Step 4.1: Verify GPU Infrastructure

```bash
# Check for GPU nodes
kubectl get nodes --show-labels | grep nvidia.com/gpu

# Check GPU operator deployment
kubectl get pods -n gpu-operator-resources

# Verify GPU device plugin
kubectl get pods -n kube-system | grep nvidia-device-plugin
```

### Step 4.2: Test GPU Workload

```bash
# Apply test GPU job
kubectl apply -f examples/gpu-test-job.yaml

# Monitor GPU job
kubectl get pods -l job-name=gpu-test
kubectl logs -l job-name=gpu-test

# Check GPU utilization in Grafana
# Navigate to GPU Monitoring dashboard
```

### Step 4.3: Verify GPU Monitoring

```bash
# Check GPU metrics are being collected
kubectl exec -it -n observability-agent-prometheus deploy/prometheus-agent -- curl -s localhost:9090/api/v1/query?query=nvidia_gpu_utilization_gpu
```

## Phase 5: DevOps CI/CD & Automation

### Objective
Implement automated CI/CD pipelines with GitHub Actions.

### Step 5.1: Configure GitHub Secrets

In your GitHub repository → Settings → Secrets and variables → Actions:

**Required Secrets**:
- `AZURE_CREDENTIALS`: JSON output from `az ad sp create-for-rbac`
- `GITHUB_TOKEN`: GitHub Personal Access Token with `repo` scope
- `TF_VAR_subscription_id`: Your Azure subscription ID
- `TF_VAR_tenant_id`: Your Azure tenant ID

### Step 5.2: Test CI/CD Pipeline

```bash
# Create a test branch
git checkout -b test-cicd

# Make a small change to flux-config
echo "# Test change" >> flux-config/README.md

# Commit and push
git add flux-config/README.md
git commit -m "Test CI/CD pipeline"
git push origin test-cicd

# Create a Pull Request on GitHub
# Verify that GitHub Actions run successfully
```

### Step 5.3: Verify Automated Validation

Check that the following validations run automatically:
- Terraform format and validation
- Security scanning with Trivy
- FluxCD manifest validation
- Kubernetes resource validation

## Phase 6: AI Stack Enablement

### Objective
Deploy AI/ML tools and frameworks for model development and serving.

### Step 6.1: Deploy AI Tools

The AI tools are configured in `flux-config/` and deploy automatically via FluxCD:

```bash
# Check AI tools deployment
kubectl get pods -n ai-tools

# Verify MLflow deployment
kubectl get svc -n ai-tools mlflow

# Verify vLLM deployment
kubectl get pods -n ai-tools -l app=vllm

# Verify Qdrant deployment
kubectl get pods -n ai-tools -l app=qdrant
```

### Step 6.2: Access AI Tools

```bash
# Get MLflow URL
kubectl get svc -n ai-tools mlflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get vLLM API endpoint
kubectl get svc -n ai-tools vllm-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get Qdrant endpoint
kubectl get svc -n ai-tools qdrant -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Step 6.3: Test AI Stack Integration

```bash
# Test MLflow tracking
python examples/test_mlflow.py

# Test vLLM inference
curl -X POST http://<vllm-api-ip>:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "llama2-7b", "prompt": "Hello, world!", "max_tokens": 50}'

# Test Qdrant vector search
curl -X POST http://<qdrant-ip>:6333/collections/test/points/search \
  -H "Content-Type: application/json" \
  -d '{"vector": [0.1, 0.2, 0.3], "limit": 10}'
```

## Security Considerations

### IP Address Configuration
**Important**: Never hardcode IP addresses in your Terraform configuration. Use environment variables instead:

```bash
# Set your IP ranges as environment variables
export TF_VAR_allowed_ip_ranges='["YOUR_IP_ADDRESS/32", "ANOTHER_IP_ADDRESS/32"]'

# Or use a .env file (ensure it's in .gitignore)
echo 'TF_VAR_allowed_ip_ranges=["YOUR_IP_ADDRESS/32"]' >> .env
```

**To find your current IP address**:
```bash
# On Linux/macOS
curl -s ifconfig.me

# On Windows
curl -s ipinfo.io/ip
```

### Customer-Managed Key Encryption
All resources use customer-managed key encryption for UAE sovereign cloud compliance:
- Storage accounts
- Key Vault
- AKS managed disks
- ACR content

## Verification & Testing

### Comprehensive Health Check

```bash
# 1. Infrastructure Health
echo "=== Infrastructure Health ==="
az aks list --output table
az storage account list --resource-group rg-tfstate-platformcore-shared-uaen-001 --output table

# 2. Cluster Health
echo "=== Cluster Health ==="
kubectl get nodes --all-namespaces
kubectl get pods --all-namespaces | grep -v Running

# 3. FluxCD Health
echo "=== FluxCD Health ==="
flux get kustomizations --all-namespaces
flux get sources git --all-namespaces
flux check

# 4. Observability Health
echo "=== Observability Health ==="
kubectl get pods -n observability-grafana
kubectl get pods -n observability-mimir
kubectl get pods -n observability-loki
kubectl get pods -n observability-tempo

# 5. GPU Health
echo "=== GPU Health ==="
kubectl get nodes --show-labels | grep nvidia.com/gpu
kubectl get pods -n gpu-operator-resources

# 6. AI Tools Health
echo "=== AI Tools Health ==="
kubectl get pods -n ai-tools
```

### Performance Testing

```bash
# Test cross-cluster query performance
time kubectl exec -it -n observability-agent-prometheus deploy/prometheus-agent -- \
  curl -s "http://mimir.ops-uaenorth.internal:9009/api/v1/query?query=up{cluster=\"dev-uaenorth\"}"

# Test GPU workload performance
kubectl apply -f examples/gpu-benchmark.yaml
kubectl logs -f -l job-name=gpu-benchmark
```

## Troubleshooting

### Common Issues and Solutions

#### Terraform State Issues
```bash
# If you get state lock errors
terraform force-unlock <lock-id>

# If you need to recreate state
terraform init -reconfigure -backend-config=backend.hcl
```

#### FluxCD Sync Issues
```bash
# Check FluxCD logs
kubectl logs -n flux-system deployment/source-controller -f
kubectl logs -n flux-system deployment/kustomize-controller -f

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization flux-system --with-source
```

#### Observability Issues
```bash
# Check Prometheus Agent connectivity
kubectl exec -it -n observability-agent-prometheus deploy/prometheus-agent -- \
  curl -v http://mimir.ops-uaenorth.internal:9009/api/v1/query?query=up

# Check Promtail connectivity
kubectl exec -it -n observability-agent-promtail deploy/promtail -- \
  curl -v http://loki.ops-uaenorth.internal:3100/ready
```

#### GPU Issues
```bash
# Check GPU operator status
kubectl get gpuclusters -A
kubectl describe gpucluster -n gpu-operator-resources

# Check GPU device plugin
kubectl get pods -n kube-system | grep nvidia
kubectl logs -n kube-system nvidia-device-plugin-xxx
```

### Getting Help

1. **Check Logs**: Use the troubleshooting commands above
2. **Review Documentation**: Check the detailed guides in `docs/`
3. **GitHub Issues**: Report bugs and feature requests
4. **Community Support**: Join the platform team Slack channel

## Next Steps

### Immediate Actions
1. **Security Hardening**: Review and update security policies
2. **Monitoring Alerts**: Configure alerting rules in Grafana
3. **Backup Strategy**: Implement backup procedures for critical data
4. **Documentation**: Update team documentation with platform specifics

### Future Enhancements
1. **Multi-Region**: Extend to additional Azure regions
2. **Advanced AI Tools**: Deploy additional ML frameworks
3. **Cost Optimization**: Implement advanced cost management
4. **Compliance**: Add additional compliance frameworks

### Maintenance Tasks
1. **Regular Updates**: Keep Terraform modules and Helm charts updated
2. **Security Patches**: Regularly apply security updates
3. **Performance Tuning**: Monitor and optimize performance
4. **Capacity Planning**: Monitor resource usage and plan scaling

---

**Congratulations!** You now have a fully functional, enterprise-grade AI platform with centralized observability, GPU support, and complete GitOps automation. The platform is ready for production AI/ML workloads with full UAE sovereign cloud compliance. 