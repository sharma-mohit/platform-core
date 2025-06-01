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
- CI/CD pipeline syntax conversion (GitLab CI to GitHub Actions)
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
| **Phase 2** | 2-4 hours | CI/CD Pipelines (GitHub Actions setup) | Medium |
| **Phase 3** | 1-2 hours | Authentication Setup (GitHub Deploy Keys) | Medium |
| **Phase 4** | 4-6 hours | Documentation Update | High |
| **Phase 5** | 1-2 hours | Testing & Validation | Medium |
| **Total** | **8-15 hours** | Complete Migration | Mixed |

---

## 🔧 Step-by-Step Migration Process

### Phase 1: FluxCD Configuration Updates

#### 1.1 Update GitRepository Resources
**Old GitLab Configuration Example (for reference):**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops
  namespace: flux-system
spec:
  interval: 1m
  url: https://gitlab.com/your-org/platform-core # Old GitLab URL
  ref:
    branch: main
  secretRef:
    name: gitlab-deploy-key # Old secret name
```

**New GitHub Configuration:**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops # Or your preferred name
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-github-org/your-repo-name # New GitHub URL
  ref:
    branch: main # Or your default branch
  secretRef:
    name: github-deploy-key # New secret name for GitHub deploy key
```

#### 1.2 Update Deploy Key Secret
**Old GitLab Secret Example (for reference):**
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
  name: github-deploy-key # Ensure this matches GitRepository.spec.secretRef.name
  namespace: flux-system
type: Opaque
data:
  identity: <base64-encoded-private-ssh-key-for-github>
  known_hosts: <base64-encoded-github-host-key> # (e.g., github.com ssh-rsa AAAAB3NzaC1yc2E...)
```

**To get GitHub's known_hosts entry:**
```bash
ssh-keyscan github.com
# Copy the relevant RSA or ED25519 key line, then base64 encode it.
# Example: echo "github.com ssh-rsa AAAAB3NzaC1yc2E..." | base64
```

### Phase 2: CI/CD Pipeline Migration (GitLab CI to GitHub Actions)

This section assumes you are moving from GitLab CI to GitHub Actions. The example below shows a typical GitHub Actions workflow.

**GitHub Actions (`.github/workflows/gitops.yml`):**
```yaml
name: GitOps CD Workflow

on:
  pull_request:
    branches: [main] # Or your protected branches
    paths:
      - 'flux-config/**' # Adjust paths as needed
  push:
    branches: [main] # Or your protected branches
    paths:
      - 'flux-config/**' # Adjust paths as needed

jobs:
  validate-manifests:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    #strategy: # Optional: if you have multiple envs to validate against
    #  matrix:
    #    environment: [dev, stg, prd] # Example environments
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main

      - name: Validate Kustomization
        run: |
          # Example for a single cluster, adjust path as needed
          flux diff kustomization flux-system --path ./flux-config/clusters/platform-core-dev-aks/flux-system
          # If using overlays for multiple environments:
          # flux diff kustomization flux-system --path ./flux-config/clusters/${{ matrix.environment }}/flux-system
        # env:
          # KUBECONFIG_FILE: ${{ secrets.KUBECONFIG_DEV }} # If diffing against a live cluster

  deploy-changes:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main' # Or your deployment branch
    runs-on: ubuntu-latest
    needs: [validate-manifests] # Optional: ensure validation passes first on PRs to main
    #strategy: # Optional: if you have multiple envs to deploy to based on paths/logic
    #  matrix:
    #    environment: [dev, stg, prd]
    # environment: ${{ matrix.environment }} # For GitHub Environments
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3 # Example for Azure, adjust for your cloud

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_DEV }} # Use appropriate secret per environment

      - name: Get AKS credentials
        run: |
          # Adjust for your AKS naming and resource group
          az aks get-credentials \\
            --resource-group rg-aks-dev-uaenorth-001 \\
            --name aks-platform-dev-uaenorth-001
        # env:
          # CLUSTER_NAME: aks-platform-${{ matrix.environment }}-uaenorth-001
          # RESOURCE_GROUP: rg-aks-${{ matrix.environment }}-uaenorth-001

      - name: Reconcile Flux Kustomization(s)
        run: |
          # Reconcile the main Kustomization that points to your cluster's config
          flux reconcile kustomization flux-system --with-source
          # Or specific Kustomizations if needed
          # flux reconcile kustomization apps --namespace my-app-ns --with-source
```
*Ensure your GitHub Actions have the necessary permissions to access secrets (like `AZURE_CREDENTIALS_DEV`) and potentially to assume roles if you're using OIDC.*

### Phase 3: Authentication and Secrets Migration

#### 3.1 GitHub Deploy Keys Setup
1.  **Generate a new SSH key pair** (if you don't have one for GitHub):
    ```bash
    ssh-keygen -t ed25519 -C "fluxcd-github-deploy-key" -f github-deploy-key
    ```
    This creates `github-deploy-key` (private key) and `github-deploy-key.pub` (public key).

2.  **Add public key to GitHub repository:**
    *   Go to your GitHub repository → Settings → Deploy keys → Add deploy key.
    *   Give it a title (e.g., "fluxcd").
    *   Paste the content of `github-deploy-key.pub`.
    *   **Do not check "Allow write access"** if FluxCD only needs to read the repository. FluxCD generally requires read-only access to the manifests repository. Write access is typically only needed if Flux is configured to commit changes back to Git (e.g., image updates), which is a more advanced setup.

3.  **Create/Update the Kubernetes secret for FluxCD:**
    Use the private key (`github-deploy-key`) and the GitHub known hosts entry.
    ```bash
    kubectl create secret generic github-deploy-key \\
      --from-file=identity=./path/to/your/github-deploy-key \\
      --from-literal=known_hosts="$(ssh-keyscan github.com 2>/dev/null | grep \'ssh-rsa\' | head -n1)" \\
      --namespace=flux-system --dry-run=client -o yaml | kubectl apply -f -
    # Ensure the secret name 'github-deploy-key' matches what's in your GitRepository resource.
    # Replace ./path/to/your/github-deploy-key with the actual path to your private key.
    # You might want to refine the ssh-keyscan to be more specific if multiple key types are present.
    ```

#### 3.2 GitHub Secrets Configuration for CI/CD (GitHub Actions)
Store necessary secrets in your GitHub repository settings: Repository → Settings → Secrets and variables → Actions.
**Required GitHub Repository Secrets (Examples):**
```
# For Azure Login in GitHub Actions
AZURE_CREDENTIALS_DEV='{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'
AZURE_CREDENTIALS_STG='{...}'
AZURE_CREDENTIALS_PRD='{...}'

# If Kustomize diffs or other operations need cluster access during PR validation:
# KUBECONFIG_DEV: base64 encoded kubeconfig for dev
# KUBECONFIG_STG: base64 encoded kubeconfig for stg

# Optional: Personal Access Token (PAT) if needed for specific GitHub API operations NOT covered by GITHUB_TOKEN
# GITHUB_PAT: <your-github-pat-with-required-scopes>
```
*The `GITHUB_TOKEN` is automatically available to GitHub Actions and has permissions scoped to the repository.*

#### 3.3 Service Principal Permissions (Example for Azure)
If your CI/CD (GitHub Actions) interacts with your cloud provider (e.g., Azure to get AKS credentials), ensure the Service Principal used by `azure/login@v1` has the necessary permissions.
Example: Assigning "Azure Kubernetes Service Cluster User Role" (or Admin, if needed by `kubectl` commands).
```bash
# Example: Get your Service Principal's Object ID (if using workload identity federation) or App ID
# $SERVICE_PRINCIPAL_ID = $(az ad sp list --display-name "your-sp-name" --query "[0].id" -o tsv)
# $AKS_RESOURCE_ID = $(az aks show -g MyResourceGroup -n MyAKSCluster --query "id" -o tsv)

az role assignment create \\
  --assignee $SERVICE_PRINCIPAL_ID \\
  --role "Azure Kubernetes Service Cluster User Role" \\
  --scope $AKS_RESOURCE_ID
```

### Phase 4: Webhook Configuration (GitHub)

#### 4.1 Update FluxCD Webhook Receiver
**Old GitLab Webhook Example (for reference):**
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Receiver
metadata:
  name: gitlab-webhook
spec:
  type: gitlab
  # ...
```

**New GitHub Webhook Configuration:**
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2 # Use v1beta2 or later for notification.toolkit.fluxcd.io
kind: Receiver
metadata:
  name: github-webhook-receiver # Or your preferred name
  namespace: flux-system
spec:
  type: github # Change type to github
  events: # Specify events, 'push' is common
    - "ping"
    - "push"
  secretRef:
    name: github-webhook-secret # Secret containing the webhook shared secret
  resources:
    - kind: GitRepository
      name: platform-core-gitops # Name of your GitRepository resource
```

#### 4.2 Create Webhook Secret
Create a secret that will be shared between GitHub and the FluxCD receiver.
```bash
# Generate a random string for the secret
WEBHOOK_SECRET=$(head -c 12 /dev/urandom | shasum -a 256 | cut -d \  -f1)
echo $WEBHOOK_SECRET

kubectl -n flux-system create secret generic github-webhook-secret --from-literal=token=$WEBHOOK_SECRET
```

#### 4.3 GitHub Webhook Setup in Repository Settings
1.  **Get the FluxCD Receiver URL:**
    This depends on how your notification-controller is exposed. If it's port-forwarded or has an Ingress:
    ```bash
    # If using port-forward (for testing only)
    # kubectl -n flux-system port-forward svc/notification-controller 8080:80
    # URL would be http://localhost:8080/hook/sha256sum-of-your-token

    # For an Ingress, it would be something like:
    # https://your.ingress.host/github-webhook-receiver-path (path depends on Ingress config)
    # The command from the docs to construct the URL:
    flux get webhook github-webhook-receiver --namespace flux-system
    ```
    Check the FluxCD documentation for the exact format of the webhook URL. It's typically `/hook/<receiver-name>`.

2.  **Configure in GitHub Repository:**
    *   Go to your GitHub repository → Settings → Webhooks → Add webhook.
    *   **Payload URL**: The URL for your FluxCD notification-controller's receiver (e.g., `https://<your-flux-ingress>/<receiver-path>`).
    *   **Content type**: `application/json`.
    *   **Secret**: Paste the `$WEBHOOK_SECRET` value you created.
    *   **Which events would you like to trigger this webhook?**: Select "Just the push event" or customize as needed (e.g., "Let me select individual events" and choose Pushes).
    *   Ensure "Active" is checked.
    *   Click "Add webhook". You can then check the "Recent Deliveries" tab for that webhook in GitHub to see if test pings (like the initial one) are successful (200 OK).

### Phase 5: Scripts and Automation Updates

#### 5.1 Update API Integration Scripts
If you have any scripts that interact with the Git provider's API:
**Old GitLab API calls (example):**
```bash
# curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \\
# "https://gitlab.com/api/v4/projects/$PROJECT_ID/repository/files/..."
```

**New GitHub API equivalent:**
```bash
# curl -H "Authorization: token $GITHUB_PAT" \\ # Or use GITHUB_TOKEN if in GitHub Actions
# -H "Accept: application/vnd.github.v3+json" \\
# "https://api.github.com/repos/$OWNER/$REPO/contents/..."
```

#### 5.2 Update Repository URLs in Scripts and Local Configurations
Search your codebase and local developer configurations for any hardcoded GitLab URLs and update them to the new GitHub repository URLs.
```bash
# Example: Find and replace repository URLs in various files
# git grep -l 'gitlab.com/your-org' | xargs sed -i 's|gitlab.com/your-org|github.com/your-github-org|g'
# Be careful with automated replacements; review changes.
```
This also applies to local `git remote` configurations for all developers.
```bash
git remote set-url origin https://github.com/your-github-org/your-repo-name.git
# or for SSH:
# git remote set-url origin git@github.com:your-github-org/your-repo-name.git
```

---

## 🧪 Testing and Validation

### Pre-Migration Checklist
- [ ] Backup current GitLab repository (clone with all branches/tags).
- [ ] Export/document all GitLab CI/CD variables and secrets.
- [ ] Document current GitLab webhook configurations and FluxCD `Receiver` resources.
- [ ] Create the new GitHub repository.
- [ ] Push all code (branches, tags) from the GitLab backup to the new GitHub repository.
- [ ] Plan a maintenance window if downtime is expected or for critical systems.

### Migration Validation Steps

#### 1. FluxCD Connectivity Test to GitHub
Deploy the updated `GitRepository` resource pointing to GitHub and the new `github-deploy-key` secret.
```bash
# Apply the updated GitRepository manifest
kubectl apply -f your-gitrepository-github.yaml

# Check status
kubectl get gitrepository -n flux-system platform-core-gitops -o wide
flux get sources git -n flux-system
# Look for 'Fetched revision: main@<commit-sha>' and a recent 'Last fetch' time.
```

#### 2. CI/CD Pipeline Test (GitHub Actions)
```bash
# Create a test PR with a small, non-critical change in a path covered by your workflow triggers.
git checkout -b test-github-actions
# Make a small change, e.g., edit a Kustomization or add a comment
git commit -am "Test GitHub Actions PR validation"
git push origin test-github-actions
# Open a Pull Request in GitHub.
# Verify the 'validate-manifests' job (or equivalent) runs and passes.

# Merge the PR (or push directly to 'main' if that's your trigger for deployment).
# Verify the 'deploy-changes' job (or equivalent) runs and successfully reconciles Flux.
```

#### 3. Webhook Functionality Test (GitHub to FluxCD)
After configuring the webhook in GitHub and the `Receiver` in FluxCD:
1.  Make a push to a branch monitored by your `GitRepository` resource.
2.  Check GitHub: Repository Settings → Webhooks → Select your webhook → Recent Deliveries. Look for a 200 OK status.
3.  Check FluxCD notification-controller logs:
    ```bash
    kubectl logs -n flux-system deployment/notification-controller -f --tail=100
    # Look for messages indicating it received and processed the event.
    ```
4.  Check FluxCD source-controller logs to see if it attempts to fetch due to the webhook:
    ```bash
    kubectl logs -n flux-system deployment/source-controller -f --tail=100
    ```
    (It might already be polling frequently, but webhooks should trigger a more immediate check).

#### 4. End-to-End Deployment Test
Make a meaningful (but safe) change to a manifest via a Git commit to the GitHub repository.
Verify that:
1.  Webhook triggers (or polling picks up the change).
2.  FluxCD `GitRepository` source updates.
3.  Relevant FluxCD `Kustomization` reconciles.
4.  The change is reflected in the cluster (`kubectl get <resource> -o yaml`, etc.).
    ```bash
    flux get kustomizations -n flux-system --watch
    ```

### Post-Migration Validation
- [ ] All environments (dev, stg, prd) sync successfully from the GitHub repository.
- [ ] GitHub Actions (CI/CD) run correctly for Pull Requests and pushes to relevant branches.
- [ ] GitHub webhooks reliably trigger FluxCD reconciliations.
- [ ] GitHub Deploy Keys for FluxCD have the correct (minimal) access.
- [ ] All necessary secrets are securely configured in GitHub Actions secrets and Kubernetes (for FluxCD).
- [ ] All relevant documentation is updated to reflect GitHub.
- [ ] Team members are informed and understand the new workflow with GitHub.

---

## 🚨 Rollback Plan

If critical issues arise, you might need to revert FluxCD to pull from the old GitLab repository.

### Emergency Rollback Steps (FluxCD pointing back to GitLab)
1.  **Revert `GitRepository` resource:**
    Apply the manifest for your `GitRepository` that points to the GitLab URL and uses the `gitlab-deploy-key` secret.
    ```bash
    # Example: kubectl apply -f old-gitlab-gitrepository.yaml
    # Or patch existing:
    kubectl patch gitrepository platform-core-gitops -n flux-system \\
      --type='json' -p='[{"op": "replace", "path": "/spec/url", "value":"https://gitlab.com/your-org/platform-core"},{"op": "replace", "path": "/spec/secretRef/name", "value":"gitlab-deploy-key"}]'
    ```

2.  **Ensure GitLab deploy key secret is active:**
    If you deleted or changed it, reapply the Kubernetes secret for the GitLab deploy key.
    ```bash
    # kubectl apply -f backup/gitlab-deploy-key-secret.yaml
    ```

3.  **Revert webhook `Receiver` (if changed):**
    Apply the manifest for your FluxCD `Receiver` that is configured for GitLab.
    ```bash
    # kubectl apply -f backup/gitlab-webhook-receiver.yaml
    ```
    And ensure webhooks are re-enabled/pointed correctly in GitLab settings if they were disabled.

4.  **Pause or Disable GitHub Actions Workflows** to prevent them from running.
5.  **Re-enable GitLab CI/CD pipelines** if they were disabled.

### Rollback Validation
- [ ] FluxCD successfully syncs from the GitLab repository.
- [ ] GitLab CI/CD pipelines (if re-enabled) function as before.
- [ ] GitLab webhooks (if re-enabled) work correctly.
- [ ] All environments are stable and reflect the state from the GitLab repository.

---

## 📚 Documentation Updates Required

### Files to Update (Examples - adjust to your project structure)
- [ ] **Project `README.md`**: Update repository URLs, setup instructions, contribution guidelines.
- [ ] **`docs/phase2-fluxcd-operational-guide.md`**: Replace all GitLab-specific instructions, commands, and examples with GitHub equivalents.
- [ ] **`docs/phase2-fluxcd-bootstrap-guide.md`**: Update `flux bootstrap` commands and any GitLab-specific setup steps.
- [ ] **`docs/phase1-terraform-execution-guide.md`**: Update any CI/CD references or repository links.
- [ ] **Terraform Module READMEs** (e.g., `terraform/modules/aks/README.md`): Update any example repository URLs or CI/CD mentions.
- [ ] **Troubleshooting guides**: Add GitHub-specific issues and solutions.
- [ ] **`flux-config/README.md`**: Update bootstrap commands and repo references.

### New Documentation to Create (Consider if needed)
- [ ] `docs/github-actions-ci-cd.md`: Detailed guide on the new GitHub Actions CI/CD pipelines.
- [ ] `docs/github-repository-setup.md`: Specifics on setting up GitHub (branch protections, deploy keys, webhooks for this project).

---

## 💡 Best Practices for Future-Proofing

### 1. Platform-Agnostic Design Patterns in FluxCD
Where possible, use variables or indirection for platform-specific values, though FluxCD CRDs are inherently tied to Git URLs. The main benefit here is in scripts or external tooling.
```yaml
# FluxCD GitRepository example - URL is usually explicit
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: platform-core-gitops
spec:
  url: https://github.com/your-org/platform-core # This is platform-specific
  secretRef:
    name: git-deploy-key # Could be a generic name, with the secret content being platform-specific
```

### 2. Modular CI/CD Structure
Keep CI/CD pipeline definitions (`.github/workflows/`) separate from actual scripts they call.
```
.github/
  workflows/
    ci.yml
    cd.yml
scripts/
  ci/
    validate-manifests.sh
    run-tests.sh
  cd/
    deploy-to-env.sh
    notify.sh
```
The `.yml` files in `.github/workflows/` would call these scripts. This makes scripts more reusable if you ever switch CI systems again (though GitHub Actions is quite common).

### 3. Abstract Authentication in Scripts
If you have scripts that need to interact with Git provider APIs outside of built-in CI/CD mechanisms:
```bash
# Example script snippet
if [[ "$GIT_PROVIDER" == "github" ]]; then
  API_TOKEN="$GITHUB_TOKEN_FOR_SCRIPT"
  API_BASE_URL="https://api.github.com"
  # GitHub specific commands
elif [[ "$GIT_PROVIDER" == "gitlab" ]]; then # For historical reference or other projects
  API_TOKEN="$GITLAB_TOKEN_FOR_SCRIPT"
  API_BASE_URL="https://gitlab.com/api/v4"
  # GitLab specific commands
fi
# Generic curl using $API_TOKEN and $API_BASE_URL
```

---

## 📞 Support and Resources

### Internal Support Contacts (Update with your team's contacts)
- Platform Team: `platform-team@example.com`
- DevOps Team: `devops@example.com`
- Security Team: `security@example.com`

### Useful Resources
- [FluxCD Documentation](https://fluxcd.io/flux/)
- [FluxCD with GitHub](https://fluxcd.io/flux/guides/repository-structure/#github)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Managing Deploy Keys (GitHub)](https://docs.github.com/en/developers/overview/managing-deploy-keys)
- [Creating Webhooks (GitHub)](https://docs.github.com/en/webhooks/creating-webhooks)
- [Azure Login Action for GitHub](https://github.com/Azure/login)

---

## 📝 Migration Checklist (GitHub Focused)

### Pre-Migration
- [ ] New GitHub repository created and code pushed (all branches/tags).
- [ ] Generate new SSH deploy key pair for FluxCD <> GitHub.
- [ ] Add public deploy key to GitHub repository (read-only unless Flux needs write).
- [ ] Plan GitHub Actions workflows (`.github/workflows/*.yml`).
- [ ] Configure required secrets in GitHub Actions settings (e.g., `AZURE_CREDENTIALS_XXX`).
- [ ] Test GitHub Actions workflows in a feature branch / PR if possible.
- [ ] Prepare Kubernetes manifests for FluxCD:
    - `GitRepository` pointing to GitHub URL and new secret name.
    - `Secret` for the GitHub deploy key (private key + known_hosts).
    - `Receiver` for GitHub webhooks (if using webhook notifications).
    - `Secret` for the GitHub webhook shared secret.

### During Migration (Maintenance Window if needed)
1.  **Apply to Kubernetes:**
    - [ ] `Secret` for GitHub deploy key.
    - [ ] Updated `GitRepository` CRD pointing to GitHub.
    - [ ] (If using webhooks) `Secret` for GitHub webhook.
    - [ ] (If using webhooks) `Receiver` CRD for GitHub webhooks.
2.  **Configure in GitHub:**
    - [ ] (If using webhooks) Setup webhook in GitHub repository settings pointing to FluxCD receiver URL, using the shared secret.
3.  **Verify FluxCD:**
    - [ ] Check `flux get sources git -n flux-system` shows successful fetch from GitHub.
    - [ ] Check `flux get kustomizations -n flux-system` are reconciling.
4.  **Test GitHub Actions:**
    - [ ] Trigger a PR workflow: Create a PR, check validation steps.
    - [ ] Trigger a push workflow: Merge PR to main (or push to deployment branch), check deployment steps.
5.  **Monitor:**
    - [ ] Monitor FluxCD controller logs.
    - [ ] Monitor application health.

### Post-Migration
- [ ] Update all relevant project documentation (READMEs, how-to guides, etc.) to reflect GitHub.
- [ ] Communicate changes and new workflows to the team.
- [ ] Decommission old GitLab CI/CD pipelines and webhooks.
- [ ] (Optional, after a stability period) Archive or remove the old GitLab repository if no longer needed for reference.
- [ ] Update disaster recovery plans to include GitHub specific steps.

**Estimated Total Migration Time: 8-15 hours**
**Recommended Migration Window: During maintenance hours if impacting production components.**
**Rollback Time Estimate: ~30 minutes - 1 hour (to reconfigure Flux to point to GitLab and revert CI).** 