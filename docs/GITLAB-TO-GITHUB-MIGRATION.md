# 🔄 GitLab to GitHub Migration Guide

## Overview

This document provides a comprehensive guide for migrating the platform's GitOps infrastructure from GitLab to GitHub. The migration involves updating CI/CD pipelines, authentication mechanisms, and platform-specific configurations while preserving all Kubernetes manifests and infrastructure code.

---

## 📊 Migration Complexity Assessment

### ✅ **Zero Effort (Platform Agnostic)**
- Kubernetes manifests (YAML files)
- Helm charts and values
- Kustomize base configurations and overlays
- Terraform infrastructure code
- Docker images and container configurations

### 🔶 **Low Effort (30 minutes - 2 hours)**
- FluxCD GitRepository resource URLs
- Deploy key configuration
- Webhook endpoint updates
- Environment variable updates

### 🔶 **Medium Effort (2-6 hours)**
- CI/CD pipeline syntax conversion
- Authentication and secrets management
- API integration scripts
- Access token management

### 🔴 **High Effort (4-8 hours)**
- Documentation updates
- Troubleshooting guides
- Setup and operational procedures
- Training materials

---

## 🎯 Migration Timeline

| Phase | Duration | Components | Effort Level |
|-------|----------|------------|--------------|
| **Phase 1** | 30 minutes | FluxCD Configuration | Low |
| **Phase 2** | 2-4 hours | CI/CD Pipelines | Medium |
| **Phase 3** | 1-2 hours | Authentication Setup | Medium |
| **Phase 4** | 4-6 hours | Documentation Update | High |
| **Phase 5** | 1-2 hours | Testing & Validation | Medium |
| **Total** | **8-15 hours** | Complete Migration | Mixed |

---

## 🔧 Step-by-Step Migration Process

### Phase 1: FluxCD Configuration Updates

#### 1.1 Update GitRepository Resources
**Current GitLab Configuration:**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops
  namespace: flux-system
spec:
  interval: 1m
  url: https://gitlab.com/your-org/platform-core
  ref:
    branch: main
  secretRef:
    name: gitlab-deploy-key
```

**New GitHub Configuration:**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-org/platform-core
  ref:
    branch: main
  secretRef:
    name: github-deploy-key
```

#### 1.2 Update Deploy Key Secret
**Current GitLab Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-deploy-key
  namespace: flux-system
type: Opaque
data:
  identity: <base64-encoded-private-key>
  known_hosts: <base64-encoded-gitlab-host-key>
```

**New GitHub Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-deploy-key
  namespace: flux-system
type: Opaque
data:
  identity: <base64-encoded-private-key>
  known_hosts: <base64-encoded-github-host-key>
```

**GitHub known_hosts entry:**
```bash
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbZ...
```

### Phase 2: CI/CD Pipeline Migration

#### 2.1 GitLab CI/CD to GitHub Actions

**Current GitLab CI/CD (`.gitlab-ci.yml`):**
```yaml
stages:
  - validate
  - deploy

validate-manifests:
  stage: validate
  image: fluxcd/flux-cli:latest
  script:
    - flux diff kustomization infrastructure --path ./infrastructure/overlays/$ENVIRONMENT
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

deploy-infrastructure:
  stage: deploy
  image: fluxcd/flux-cli:latest
  script:
    - flux reconcile kustomization infrastructure --with-source
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  environment:
    name: $ENVIRONMENT
```

**New GitHub Actions (`.github/workflows/gitops.yml`):**
```yaml
name: GitOps Validation and Deployment

on:
  pull_request:
    branches: [main]
    paths: ['infrastructure/**', 'apps/**']
  push:
    branches: [main]
    paths: ['infrastructure/**', 'apps/**']

jobs:
  validate-manifests:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev-uaenorth, stg-uaenorth, prd-uaenorth]
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main
      
      - name: Validate manifests
        run: |
          flux diff kustomization infrastructure \
            --path ./infrastructure/overlays/${{ matrix.environment }}
        env:
          ENVIRONMENT: ${{ matrix.environment }}

  deploy-infrastructure:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: [validate-manifests]
    strategy:
      matrix:
        environment: [dev-uaenorth, stg-uaenorth, prd-uaenorth]
    environment: ${{ matrix.environment }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Get AKS credentials
        run: |
          az aks get-credentials \
            --resource-group rg-aks-${{ matrix.environment }}-uaenorth-001 \
            --name aks-platform-${{ matrix.environment }}-uaenorth-001
      
      - name: Reconcile infrastructure
        run: |
          flux reconcile kustomization infrastructure --with-source
        env:
          ENVIRONMENT: ${{ matrix.environment }}
```

#### 2.2 Environment-Specific Workflows
Create separate workflow files for different environments if needed:

```yaml
# .github/workflows/deploy-dev.yml
name: Deploy to Development
on:
  push:
    branches: [main]
    paths: ['infrastructure/overlays/dev-uaenorth/**']

# .github/workflows/deploy-staging.yml  
name: Deploy to Staging
on:
  push:
    branches: [main]
    paths: ['infrastructure/overlays/stg-uaenorth/**']

# .github/workflows/deploy-production.yml
name: Deploy to Production
on:
  push:
    branches: [main]
    paths: ['infrastructure/overlays/prd-uaenorth/**']
```

### Phase 3: Authentication and Secrets Migration

#### 3.1 GitHub Deploy Keys Setup
1. **Generate new SSH key pair:**
```bash
ssh-keygen -t ed25519 -C "fluxcd-deploy-key" -f github-deploy-key
```

2. **Add public key to GitHub repository:**
   - Go to Repository Settings → Deploy keys
   - Add new deploy key with read access
   - Paste public key content

3. **Update Kubernetes secret:**
```bash
kubectl create secret generic github-deploy-key \
  --from-file=identity=github-deploy-key \
  --from-literal=known_hosts="github.com ssh-rsa AAAAB3NzaC1yc2E..." \
  --namespace=flux-system
```

#### 3.2 GitHub Secrets Configuration
**Required GitHub Repository Secrets:**
```bash
# Azure Service Principal for AKS access
AZURE_CREDENTIALS='{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'

# Environment-specific secrets
DEV_KUBECONFIG=<base64-encoded-kubeconfig>
STG_KUBECONFIG=<base64-encoded-kubeconfig>
PRD_KUBECONFIG=<base64-encoded-kubeconfig>

# Optional: Personal Access Token for API operations
GITHUB_TOKEN=<github-personal-access-token>
```

#### 3.3 Service Principal Permissions
Ensure Azure Service Principal has required permissions:
```bash
# Assign AKS cluster admin role
az role assignment create \
  --assignee $SERVICE_PRINCIPAL_ID \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope $AKS_RESOURCE_ID
```

### Phase 4: Webhook Configuration

#### 4.1 Update FluxCD Webhook Receiver
**Current GitLab webhook configuration:**
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Receiver
metadata:
  name: gitlab-webhook
spec:
  type: gitlab
  secretRef:
    name: webhook-token
  resources:
    - kind: GitRepository
      name: platform-core-gitops
```

**New GitHub webhook configuration:**
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Receiver
metadata:
  name: github-webhook
spec:
  type: github
  secretRef:
    name: webhook-token
  resources:
    - kind: GitRepository
      name: platform-core-gitops
```

#### 4.2 GitHub Webhook Setup
1. **Get webhook URL:**
```bash
kubectl get receiver github-webhook -o jsonpath='{.status.url}'
```

2. **Configure in GitHub:**
   - Go to Repository Settings → Webhooks
   - Add webhook with FluxCD receiver URL
   - Set content type to `application/json`
   - Select "Just the push event"

### Phase 5: Scripts and Automation Updates

#### 5.1 Update API Integration Scripts
**GitLab API calls:**
```bash
# Current GitLab API usage
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/..."
```

**GitHub API equivalent:**
```bash
# New GitHub API usage
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/contents/..."
```

#### 5.2 Update Repository URLs in Scripts
```bash
# Find and replace repository URLs
find . -type f -name "*.sh" -o -name "*.yml" -o -name "*.yaml" | \
  xargs sed -i 's|gitlab\.com/your-org|github.com/your-org|g'
```

---

## 🧪 Testing and Validation

### Pre-Migration Checklist
- [ ] Backup current GitLab repository
- [ ] Export all GitLab CI/CD variables and secrets
- [ ] Document current webhook configurations
- [ ] Create GitHub repository with same structure
- [ ] Test GitHub Actions in a separate branch

### Migration Validation Steps

#### 1. FluxCD Connectivity Test
```bash
# Test GitRepository resource
kubectl get gitrepository platform-core-gitops -n flux-system
kubectl describe gitrepository platform-core-gitops -n flux-system

# Check sync status
flux get sources git
```

#### 2. CI/CD Pipeline Test
```bash
# Create test PR to validate GitHub Actions
git checkout -b test-migration
echo "# Test migration" >> README.md
git commit -am "Test GitHub Actions"
git push origin test-migration
# Create PR and verify actions run
```

#### 3. Webhook Functionality Test
```bash
# Test webhook delivery
kubectl logs -n flux-system deployment/notification-controller
```

#### 4. End-to-End Deployment Test
```bash
# Make a small change and verify deployment
kubectl get kustomizations -n flux-system
flux reconcile kustomization infrastructure
```

### Post-Migration Validation
- [ ] All environments sync successfully from GitHub
- [ ] GitHub Actions run on pull requests
- [ ] Webhooks trigger FluxCD reconciliation
- [ ] Deploy keys have appropriate access
- [ ] All secrets are properly configured
- [ ] Documentation is updated

---

## 🚨 Rollback Plan

### Emergency Rollback Steps
1. **Revert GitRepository resource:**
```bash
kubectl patch gitrepository platform-core-gitops -n flux-system \
  --type='merge' -p='{"spec":{"url":"https://gitlab.com/your-org/platform-core"}}'
```

2. **Restore GitLab deploy key secret:**
```bash
kubectl apply -f backup/gitlab-deploy-key-secret.yaml
```

3. **Update webhook receiver:**
```bash
kubectl apply -f backup/gitlab-webhook-receiver.yaml
```

### Rollback Validation
- [ ] FluxCD syncs from GitLab repository
- [ ] GitLab CI/CD pipelines function
- [ ] GitLab webhooks work correctly
- [ ] All environments are stable

---

## 📚 Documentation Updates Required

### Files to Update
- [ ] `README.md` - Update repository URLs and setup instructions
- [ ] `docs/phase2-howto.md` - Replace GitLab references with GitHub
- [ ] `docs/phase1-howto.md` - Update CI/CD references
- [ ] All module READMEs - Update example repository URLs
- [ ] Troubleshooting guides - Add GitHub-specific issues

### New Documentation to Create
- [ ] `docs/github-setup.md` - GitHub-specific setup guide
- [ ] `docs/github-troubleshooting.md` - GitHub-specific issues
- [ ] `docs/github-actions-guide.md` - CI/CD pipeline documentation

---

## 💡 Best Practices for Future Migrations

### 1. Platform-Agnostic Design Patterns
```yaml
# Use environment variables for platform-specific values
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops
spec:
  url: ${GIT_REPOSITORY_URL}
  secretRef:
    name: ${GIT_SECRET_NAME}
```

### 2. Modular CI/CD Structure
```
scripts/
├── common/
│   ├── validate-manifests.sh
│   ├── deploy-infrastructure.sh
│   └── test-connectivity.sh
├── gitlab/
│   └── .gitlab-ci.yml
└── github/
    └── workflows/
```

### 3. Abstract Authentication Layer
```bash
# Platform-agnostic authentication script
case $GIT_PLATFORM in
  "gitlab")
    export GIT_TOKEN=$GITLAB_TOKEN
    export API_BASE="https://gitlab.com/api/v4"
    ;;
  "github")
    export GIT_TOKEN=$GITHUB_TOKEN
    export API_BASE="https://api.github.com"
    ;;
esac
```

---

## 📞 Support and Resources

### Migration Support Contacts
- Platform Team: platform-team@company.com
- DevOps Team: devops@company.com
- Security Team: security@company.com

### Useful Resources
- [FluxCD GitHub Integration](https://fluxcd.io/docs/guides/github/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Deploy Keys Guide](https://docs.github.com/en/developers/overview/managing-deploy-keys)
- [Azure Service Principal Setup](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)

---

## 📝 Migration Checklist

### Pre-Migration
- [ ] Create GitHub repository
- [ ] Generate new deploy keys
- [ ] Setup GitHub Actions workflows
- [ ] Configure GitHub secrets
- [ ] Test in development environment

### During Migration
- [ ] Update FluxCD GitRepository resources
- [ ] Replace deploy key secrets
- [ ] Update webhook receivers
- [ ] Validate connectivity
- [ ] Test CI/CD pipelines

### Post-Migration
- [ ] Update all documentation
- [ ] Train team on GitHub workflows
- [ ] Monitor for issues
- [ ] Cleanup GitLab resources
- [ ] Update disaster recovery procedures

**Estimated Total Migration Time: 8-15 hours**
**Recommended Migration Window: During maintenance hours**
**Rollback Time: 30 minutes** 