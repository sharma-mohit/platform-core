# 🔄 GitLab to GitHub Migration Guide

## Overview

This document provides a step-by-step guide for migrating the platform's GitOps infrastructure from a previous Git provider (e.g., GitLab) to GitHub. The migration involves updating CI/CD pipelines, authentication mechanisms, and platform-specific configurations while preserving all Kubernetes manifests and infrastructure code.

---

## 🔧 Step-by-Step Migration Process

**Prerequisites:**
*   Access to your Kubernetes cluster (`kubectl` configured).
*   `flux` CLI installed.
*   `git` CLI installed.
*   `ssh-keygen` utility (usually available by default).
*   `base64` utility.
*   Administrative access to your new GitHub repository (for deploy keys, webhooks, secrets).
*   Credentials for your cloud provider (e.g., Azure Service Principal for GitHub Actions).
*   Your complete codebase (including all branches and tags) from the old Git repository cloned locally.

**Placeholders used in this guide:**
*   `YOUR_GITHUB_ORG`: Your GitHub organization or username.
*   `YOUR_REPO_NAME`: Your new GitHub repository name.
*   `YOUR_CLUSTER_CONTEXT_NAME`: Your `kubectl` context name for the target cluster.
*   `YOUR_FLUX_NAMESPACE`: Typically `flux-system`.
*   `YOUR_BRANCH_NAME`: The default branch, usually `main` or `master`.
*   `YOUR_GITOPS_REPO_SECRET_NAME`: Name for the K8s secret holding deploy key, e.g., `github-deploy-key`.
*   `YOUR_PRIVATE_SSH_KEY_PATH`: Path to your private SSH key file, e.g., `./github-deploy-key`.
*   `YOUR_AZURE_SP_CREDENTIALS_JSON`: JSON output of Azure SP credentials for GitHub Actions.
*   `YOUR_AKS_RESOURCE_GROUP`: Azure Resource Group of your AKS cluster.
*   `YOUR_AKS_CLUSTER_NAME`: Name of your AKS cluster.
*   `YOUR_WEBHOOK_SECRET_K8S_NAME`: K8s secret name for webhook, e.g., `github-webhook-secret`.
*   `YOUR_WEBHOOK_RECEIVER_NAME`: Flux Receiver name, e.g., `github-webhook-receiver`.
*   `YOUR_FLUX_INGRESS_URL_OR_IP`: Publicly accessible URL/IP for your Flux notification controller.

### Phase 1: FluxCD Configuration Updates

#### 1.1. Prepare Your GitHub Repository
1.  Create a new **private** repository on GitHub: `https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME`.
2.  Clone your existing GitLab repository locally (if you haven't already):
    ```bash
    git clone --mirror git@gitlab.com:OLD_ORG/OLD_REPO.git old-repo-mirror
    cd old-repo-mirror
    ```
3.  Set the new GitHub remote:
    ```bash
    git remote set-url origin https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
    # Or for SSH:
    # git remote set-url origin git@github.com:YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
    ```
4.  Push all branches and tags to GitHub:
    ```bash
    git push --mirror
    cd ..
    rm -rf old-repo-mirror # Clean up mirror clone
    ```
5.  Clone your new GitHub repository to a fresh working directory.
    ```bash
    git clone git@github.com:YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
    cd YOUR_REPO_NAME
    ```

#### 1.2. Update FluxCD `GitRepository` Resource
Create or update your FluxCD `GitRepository` manifest file (e.g., `flux-gitrepository.yaml`) with the new GitHub repository details.

**Example `GitRepository` manifest (`flux-gitrepository.yaml`):**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2 # Check for the latest stable API version
kind: GitRepository
metadata:
  name: platform-core-gitops # Or your desired name
  namespace: YOUR_FLUX_NAMESPACE # Typically flux-system
spec:
  interval: 1m
  url: ssh://git@github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git # SSH URL for GitHub
  ref:
    branch: YOUR_BRANCH_NAME # e.g., main
  secretRef:
    name: YOUR_GITOPS_REPO_SECRET_NAME # e.g., github-deploy-key
  # For GitHub Enterprise or self-hosted, you might need:
  # ssh:
  #   caFile: <path-to-ca-bundle-if-using-custom-ca>
  #   known_hosts: <your-github-enterprise-known-hosts-entry>
```
**Apply the manifest to your cluster:**
```bash
kubectl apply -f flux-gitrepository.yaml --context YOUR_CLUSTER_CONTEXT_NAME
```

#### 1.3. Create GitHub Deploy Key and Kubernetes Secret

1.  **Generate a new SSH key pair:**
    ```bash
    ssh-keygen -t ed25519 -C "fluxcd-github-deploy@YOUR_REPO_NAME" -f YOUR_PRIVATE_SSH_KEY_PATH # e.g., ./github-deploy-key
    # Do not set a passphrase for this key.
    ```
    This creates `YOUR_PRIVATE_SSH_KEY_PATH` (private key) and `YOUR_PRIVATE_SSH_KEY_PATH.pub` (public key).

2.  **Add the public key to your GitHub repository:**
    *   Go to `https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME/settings/keys`.
    *   Click "Add deploy key".
    *   **Title**: `fluxcd-readonly` (or similar).
    *   **Key**: Paste the content of `YOUR_PRIVATE_SSH_KEY_PATH.pub`.
    *   **Allow write access**: Leave this unchecked (FluxCD typically only needs read access).
    *   Click "Add key".

3.  **Get GitHub's SSH known hosts entry:**
    ```bash
    ssh-keyscan github.com > github_known_hosts
    # Review github_known_hosts to ensure it looks correct, then get its base64 encoded value:
    # For Linux:
    KNOWN_HOSTS_B64=$(cat github_known_hosts | base64 -w0)
    # For macOS:
    # KNOWN_HOSTS_B64=$(cat github_known_hosts | base64)
    echo "Base64 encoded known_hosts: $KNOWN_HOSTS_B64"
    rm github_known_hosts # Clean up
    ```

4.  **Create the Kubernetes secret for FluxCD:**
    This secret will store the private SSH key and GitHub's known hosts.
    ```bash
    kubectl create secret generic YOUR_GITOPS_REPO_SECRET_NAME \
      --namespace=YOUR_FLUX_NAMESPACE \
      --from-file=identity=YOUR_PRIVATE_SSH_KEY_PATH \
      --from-file=known_hosts=<(echo "$KNOWN_HOSTS_B64" | base64 -d) \
      --dry-run=client -o yaml | kubectl apply -f - --context YOUR_CLUSTER_CONTEXT_NAME
    ```
    *Ensure `YOUR_GITOPS_REPO_SECRET_NAME` matches `spec.secretRef.name` in your `GitRepository` manifest.*
    *Replace `YOUR_PRIVATE_SSH_KEY_PATH` with the actual path to your private key (e.g., `./github-deploy-key`).*

### Phase 2: CI/CD Pipeline Migration (Example: GitHub Actions)

This section provides an example of a GitHub Actions workflow. You will need to translate your existing CI/CD logic from GitLab CI (or other systems) to GitHub Actions.

**Create `.github/workflows/gitops-cd.yml` in your repository:**
```yaml
name: GitOps CD Workflow

on:
  pull_request:
    branches: [ YOUR_BRANCH_NAME ] # e.g., main
    paths: # Adjust paths to trigger workflow only on relevant changes
      - 'flux-config/**'
      - 'terraform/**'
  push:
    branches: [ YOUR_BRANCH_NAME ] # e.g., main
    paths:
      - 'flux-config/**'
      - 'terraform/**'

jobs:
  validate-code: # Example job for PRs
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Add steps for linting, manifest validation (e.g., kubeval, kustomize build)
      # Example: Validate Kustomization for Flux
      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main # Ensures flux CLI is available

      - name: Validate Flux Kustomization (example)
        # This command assumes your Flux Kustomizations are in a certain path.
        # Adjust the path to your cluster's main Kustomization.
        # You might need KUBECONFIG if diffing against a live cluster (not recommended for PR validation)
        run: |
          flux diff kustomization flux-system --path ./flux-config/clusters/YOUR_CLUSTER_NAME/flux-system --context YOUR_CLUSTER_CONTEXT_NAME
          # Replace YOUR_CLUSTER_NAME with the actual name (e.g., platform-core-dev-aks)

  deploy-changes: # Example job for pushes to main (post-merge)
    if: github.event_name == 'push' && github.ref == 'refs/heads/YOUR_BRANCH_NAME'
    runs-on: ubuntu-latest
    # needs: [validate-code] # Optional: ensure validation job passes first

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Example: For Azure deployments
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }} # Store your Azure SP JSON credentials as a GitHub secret

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Get AKS credentials (example)
        run: |
          az aks get-credentials \
            --resource-group YOUR_AKS_RESOURCE_GROUP \
            --name YOUR_AKS_CLUSTER_NAME
        env:
          AZURE_CREDENTIALS: ${{ secrets.AZURE_CREDENTIALS }}

      # Flux typically handles reconciliation automatically based on GitRepository updates.
      # However, you might want to explicitly trigger a reconciliation or perform other actions.
      - name: Trigger Flux Reconcile (Optional - if needed beyond Git polling)
        uses: fluxcd/flux2/action@main
        with:
          # Example: Reconcile a specific Kustomization. Flux polls automatically, so this is often not needed.
          # command: reconcile kustomization flux-system --with-source --namespace YOUR_FLUX_NAMESPACE
          # Ensure flux CLI is configured to talk to your cluster (KUBECONFIG)
          # Note: Direct reconciliation via CI might conflict with Flux's own Git polling.
          # It's often better to let Flux pick up changes from Git automatically.
          command: |
            echo "Flux will reconcile automatically from Git. Triggering an explicit sync if necessary."
            flux reconcile source git platform-core-gitops --namespace YOUR_FLUX_NAMESPACE # Replace platform-core-gitops if name is different
            flux reconcile kustomization flux-system --namespace YOUR_FLUX_NAMESPACE --with-source # Example, adjust to your main kustomization
```
**Note on GitHub Actions Secrets:**
*   Go to your GitHub repository → Settings → Secrets and variables → Actions.
*   Add `AZURE_CREDENTIALS` (or similar) with the JSON credentials of an Azure Service Principal that has permissions to your AKS cluster and other Azure resources managed by Terraform/Flux.

### Phase 3: Authentication and Secrets Migration (CI/CD Related)

This phase focuses on secrets needed by your CI/CD system (GitHub Actions). FluxCD's own authentication to GitHub was set up in Phase 1.

#### 3.1. Configure GitHub Secrets for CI/CD
As shown in the GitHub Actions example:
1.  In your GitHub repository, go to `Settings` > `Secrets and variables` > `Actions`.
2.  Click `New repository secret`.
3.  Add secrets required by your workflows. For example:
    *   `AZURE_CREDENTIALS`: JSON object for Azure Service Principal.
        ```json
        {
          "clientId": "YOUR_SERVICE_PRINCIPAL_APP_ID",
          "clientSecret": "YOUR_SERVICE_PRINCIPAL_PASSWORD",
          "subscriptionId": "YOUR_AZURE_SUBSCRIPTION_ID",
          "tenantId": "YOUR_AZURE_TENANT_ID"
        }
        ```
    *   Any other tokens or keys your CI/CD jobs need (e.g., SonarQube token, Docker Hub credentials).

#### 3.2. Service Principal Permissions (Example for Azure)
Ensure the Azure Service Principal used in `AZURE_CREDENTIALS` has sufficient permissions.
1.  **Create or Identify Service Principal:**
    If you need to create one:
    ```bash
    az ad sp create-for-rbac --name "YourGitHubActionsSP" --role "Contributor" --scopes "/subscriptions/YOUR_AZURE_SUBSCRIPTION_ID" --sdk-auth
    ```
    *(The output is the JSON for `AZURE_CREDENTIALS`. Restrict roles/scopes as much as possible).*

2.  **Assign AKS Cluster Access (if not covered by broad role like Contributor):**
    Get your Service Principal's Object ID (or App ID for some role assignments):
    ```bash
    # Using App ID (clientId from AZURE_CREDENTIALS)
    SERVICE_PRINCIPAL_APP_ID="YOUR_SERVICE_PRINCIPAL_APP_ID"
    # Or get ObjectID if needed:
    # SERVICE_PRINCIPAL_OBJECT_ID=$(az ad sp show --id "${SERVICE_PRINCIPAL_APP_ID}" --query "id" -o tsv)

    AKS_RESOURCE_ID=$(az aks show -g YOUR_AKS_RESOURCE_GROUP -n YOUR_AKS_CLUSTER_NAME --query "id" -o tsv)

    # Assign a role like "Azure Kubernetes Service Cluster User Role" or "Azure Kubernetes Service RBAC Cluster Admin"
    az role assignment create \
      --assignee "$SERVICE_PRINCIPAL_APP_ID" \
      --role "Azure Kubernetes Service Cluster User Role" \
      --scope "$AKS_RESOURCE_ID"
    ```

### Phase 4: Webhook Configuration (GitHub to FluxCD)

This enables FluxCD to reconcile more quickly upon pushes to GitHub, rather than waiting for its polling interval.

#### 4.1. Create/Update FluxCD `Receiver` Manifest
Create a `Receiver` manifest (e.g., `flux-receiver.yaml`):
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3 # Check for latest stable API
kind: Receiver
metadata:
  name: YOUR_WEBHOOK_RECEIVER_NAME # e.g., github-webhook-receiver
  namespace: YOUR_FLUX_NAMESPACE   # Typically flux-system
spec:
  type: github
  events:
    - "ping"
    - "push"
  secretRef:
    name: YOUR_WEBHOOK_SECRET_K8S_NAME # e.g., github-webhook-secret
  resources:
    - kind: GitRepository
      name: platform-core-gitops # Must match the name of your GitRepository resource
```
**Apply the manifest:**
```bash
kubectl apply -f flux-receiver.yaml --context YOUR_CLUSTER_CONTEXT_NAME
```

#### 4.2. Create Kubernetes Secret for Webhook
This secret is shared between GitHub and FluxCD's `Receiver`.
```bash
# Generate a random string for the webhook secret
WEBHOOK_SHARED_SECRET=$(head -c 32 /dev/urandom | base64 -w0 | sed 's/[^a-zA-Z0-9]//g' | cut -c1-32)
echo "Generated Webhook Shared Secret: $WEBHOOK_SHARED_SECRET" # Keep this value

kubectl create secret generic YOUR_WEBHOOK_SECRET_K8S_NAME \
  --namespace=YOUR_FLUX_NAMESPACE \
  --from-literal=token="$WEBHOOK_SHARED_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f - --context YOUR_CLUSTER_CONTEXT_NAME
```

#### 4.3. Configure Webhook in GitHub Repository
1.  **Expose Flux Notification Controller & Get URL:**
    The Flux notification controller needs to be reachable from GitHub. This usually involves setting up an Ingress for `svc/notification-controller` in the `YOUR_FLUX_NAMESPACE`.
    Once exposed, the typical webhook URL path is `/hook/YOUR_WEBHOOK_RECEIVER_NAME`.
    Example: `https://YOUR_FLUX_INGRESS_URL_OR_IP/hook/YOUR_WEBHOOK_RECEIVER_NAME`

    You can also get the expected path using `flux`:
    ```bash
    flux get webhook YOUR_WEBHOOK_RECEIVER_NAME --namespace YOUR_FLUX_NAMESPACE
    # This command shows the endpoint path, e.g. /hook/blahblah
    ```

2.  **Add Webhook in GitHub:**
    *   Go to `https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME/settings/hooks`.
    *   Click "Add webhook".
    *   **Payload URL**: Enter the full URL from the previous step (e.g., `https://YOUR_FLUX_INGRESS_URL_OR_IP/hook/YOUR_WEBHOOK_RECEIVER_NAME`).
    *   **Content type**: `application/json`.
    *   **Secret**: Paste the `$WEBHOOK_SHARED_SECRET` value you generated.
    *   **Which events would you like to trigger this webhook?**: Select "Just the push event". You can also add "Pings" for testing.
    *   Ensure "Active" is checked.
    *   Click "Add webhook".
    *   Check the "Recent Deliveries" tab for the webhook in GitHub. A green checkmark indicates a successful delivery (e.g., for the initial Ping event).

### Phase 5: Scripts and Automation Updates

#### 5.1. Update API Integration Scripts
If you have custom scripts interacting with GitLab APIs, update them for GitHub APIs.
**Old GitLab API call example:**
```bash
# curl --header "PRIVATE-TOKEN: YOUR_GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/YOUR_PROJECT_ID/..."
```
**New GitHub API call example:**
```bash
# curl --header "Authorization: token YOUR_GITHUB_PAT" \
#      --header "Accept: application/vnd.github.v3+json" \
#      "https://api.github.com/repos/YOUR_GITHUB_ORG/YOUR_REPO_NAME/..."
```

#### 5.2. Update Local Git Remotes & Repository URLs in Code/Docs
1.  **For all developers, update local Git remotes:**
    In their local clones of the repository:
    ```bash
    # For HTTPS:
    # git remote set-url origin https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
    # For SSH:
    git remote set-url origin git@github.com:YOUR_GITHUB_ORG/YOUR_REPO_NAME.git

    git fetch origin
    git branch -u origin/YOUR_BRANCH_NAME YOUR_BRANCH_NAME # To track the new upstream
    ```

2.  **Search and replace old Git provider URLs in your codebase and documentation:**
    Use tools like `grep` and `sed`, or your IDE's search/replace functionality.
    **Caution: Review changes carefully before committing.**
    Example search (does not modify):
    ```bash
    git grep 'gitlab.com/OLD_ORG'
    ```

---

## 🧪 Testing and Validation

### 1. FluxCD Source Connectivity (GitHub)
```bash
# Check GitRepository status (ensure it reconciled successfully after secret update)
kubectl get gitrepository -n YOUR_FLUX_NAMESPACE platform-core-gitops -o wide --context YOUR_CLUSTER_CONTEXT_NAME
flux get sources git -n YOUR_FLUX_NAMESPACE --context YOUR_CLUSTER_CONTEXT_NAME
# Expected: 'Fetched revision: YOUR_BRANCH_NAME@<commit-sha>' and a recent 'Last fetch' time.
```

### 2. CI/CD Pipeline Execution (GitHub Actions)
1.  **Pull Request Workflow:**
    *   Create a new branch: `git checkout -b test-gh-actions-pr`
    *   Make a small, non-critical change in a path covered by your PR workflow trigger (e.g., add a comment in a file within `flux-config/`).
    *   Commit and push: `git add . && git commit -m "Test GitHub Actions PR" && git push origin test-gh-actions-pr`
    *   Open a Pull Request on GitHub.
    *   Verify the `validate-code` (or similar) job in your GitHub Actions workflow runs and passes.
2.  **Push/Merge Workflow:**
    *   Merge the test Pull Request into `YOUR_BRANCH_NAME`.
    *   Verify the `deploy-changes` (or similar) job in your GitHub Actions workflow runs.
    *   Check if any intended actions (e.g., `flux reconcile` if you added it, notifications) occurred.

### 3. Webhook Functionality (GitHub to FluxCD)
1.  Make a new commit and push it to `YOUR_BRANCH_NAME` in your GitHub repository.
2.  **Check GitHub:** Go to Repository Settings → Webhooks → Select your webhook → Recent Deliveries. Look for a 200 OK status for the push event.
3.  **Check FluxCD notification-controller logs:**
    ```bash
    kubectl logs -n YOUR_FLUX_NAMESPACE deployment/notification-controller -f --tail=100 --context YOUR_CLUSTER_CONTEXT_NAME
    # Look for messages indicating it received and processed the event for YOUR_WEBHOOK_RECEIVER_NAME.
    ```
4.  **Check FluxCD source-controller logs:**
    ```bash
    kubectl logs -n YOUR_FLUX_NAMESPACE deployment/source-controller -f --tail=100 --context YOUR_CLUSTER_CONTEXT_NAME
    # Look for messages indicating it's fetching new revisions from github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.
    ```

### 4. End-to-End Deployment Test
1.  Make a safe, observable change to a Kubernetes manifest managed by Flux (e.g., change a ConfigMap value, update an image tag to a new valid version).
2.  Commit and push the change to `YOUR_BRANCH_NAME` on GitHub.
3.  Verify:
    *   Webhook triggers (or polling picks up the change quickly).
    *   FluxCD `GitRepository` source updates: `flux get sources git -n YOUR_FLUX_NAMESPACE --context YOUR_CLUSTER_CONTEXT_NAME`
    *   Relevant FluxCD `Kustomization` reconciles: `flux get kustomizations -n YOUR_FLUX_NAMESPACE --watch --context YOUR_CLUSTER_CONTEXT_NAME`
    *   The change is reflected in the cluster (e.g., `kubectl describe configmap ...`, `kubectl get deployment ... -o yaml`).

---

## 🚨 Rollback Plan

If critical issues arise, revert FluxCD to pull from the old Git repository.

### Emergency Rollback Steps
1.  **Revert FluxCD `GitRepository` Resource:**
    Apply the manifest for your `GitRepository` that points to the old GitLab URL and uses the old GitLab deploy key secret.
    Example:
    ```bash
    # If you have the old manifest file (e.g., old-gitlab-gitrepository.yaml):
    # kubectl apply -f old-gitlab-gitrepository.yaml --context YOUR_CLUSTER_CONTEXT_NAME

    # Or patch the existing one (ensure you have the correct old URL and secret name):
    kubectl patch gitrepository platform-core-gitops -n YOUR_FLUX_NAMESPACE \
      --context YOUR_CLUSTER_CONTEXT_NAME \
      --type='json' -p='[{"op": "replace", "path": "/spec/url", "value":"OLD_GITLAB_SSH_URL"}, {"op": "replace", "path": "/spec/secretRef/name", "value":"OLD_GITLAB_DEPLOY_SECRET_NAME"}]'
    ```

2.  **Ensure Old GitLab Deploy Key Secret is Active:**
    If you deleted or changed it, reapply the Kubernetes secret for the GitLab deploy key.
    ```bash
    # kubectl apply -f backup/gitlab-deploy-key-secret.yaml --context YOUR_CLUSTER_CONTEXT_NAME
    ```

3.  **Revert FluxCD `Receiver` (if changed for GitHub):**
    Delete the GitHub `Receiver` and reapply the manifest for your FluxCD `Receiver` that was configured for GitLab.
    ```bash
    # kubectl delete -f flux-receiver.yaml --context YOUR_CLUSTER_CONTEXT_NAME
    # kubectl apply -f backup/gitlab-webhook-receiver.yaml --context YOUR_CLUSTER_CONTEXT_NAME
    ```
    Also, ensure webhooks are re-enabled/correctly pointed in GitLab settings if they were disabled.

4.  **Pause or Disable GitHub Actions Workflows.**
5.  **Re-enable old CI/CD pipelines** (e.g., GitLab CI/CD) if they were disabled.

### Rollback Validation
*   FluxCD successfully syncs from the old GitLab repository.
*   Old CI/CD pipelines (if re-enabled) function as before.
*   Old webhooks (if re-enabled) work correctly.
*   All environments are stable and reflect the state from the old GitLab repository.

---

## 📚 Documentation Updates Required

### Files to Update
(Adjust this list based on your project structure)
*   **Project `README.md`**: Update repository URLs, setup instructions, contribution guidelines.
*   **`docs/phase2-fluxcd-operational-guide.md`**: Replace all old Git provider instructions with GitHub equivalents.
*   **`docs/phase2-fluxcd-bootstrap-guide.md`**: Update `flux bootstrap github` commands and any old setup steps.
*   **`docs/phase1-terraform-execution-guide.md`**: Update any CI/CD references or repository links.
*   **Terraform Module READMEs** (e.g., `terraform/modules/aks/README.md`): Update any example repository URLs or CI/CD mentions.
*   **Troubleshooting guides**: Add GitHub-specific issues and solutions.
*   **`flux-config/README.md`**: Update bootstrap commands and repo references to `flux bootstrap github`.

### New Documentation to Create (Consider if needed)
*   `docs/github-actions-ci-cd.md`: Detailed guide on the new GitHub Actions CI/CD pipelines.
*   `docs/github-repository-setup.md`: Specifics on setting up GitHub for this project (branch protections, advanced deploy key usage, webhook details).

---

## 💡 Best Practices for Future-Proofing (Git Provider Agnostic where possible)

### 1. Modular CI/CD Structure
Keep CI/CD pipeline definitions (e.g., `.github/workflows/`) separate from actual scripts they call.
```
.github/
  workflows/        # GitHub Actions specific
    ci-cd.yml
scripts/
  common/           # Reusable scripts
    validate-manifests.sh
    deploy-app.sh
```
The `.yml` files in `.github/workflows/` would call scripts from `scripts/common/`. This makes the core logic more portable.

### 2. Abstract Authentication in Scripts (if custom scripts are used)
If you have custom scripts that interact with Git provider APIs outside of built-in CI/CD mechanisms:
```bash
# Example script snippet
GIT_PROVIDER="github" # or make this an environment variable

if [[ "$GIT_PROVIDER" == "github" ]]; then
  API_TOKEN="$YOUR_GITHUB_PAT_FOR_SCRIPT" # From GitHub Actions secrets or env
  API_BASE_URL="https://api.github.com"
  # GitHub specific API calls
elif [[ "$GIT_PROVIDER" == "gitlab" ]]; then # For reference
  API_TOKEN="$YOUR_GITLAB_PAT_FOR_SCRIPT"
  API_BASE_URL="https://gitlab.com/api/v4"
  # GitLab specific API calls
fi
# Generic curl using $API_TOKEN and $API_BASE_URL
```

---

## 📞 Support and Resources

### Internal Support Contacts
(Update with your team's actual contacts or channels)
*   Platform Team: `#platform-support` or `your-platform-team@example.com`
*   DevOps Team: `#devops-support` or `your-devops-team@example.com`

### Useful Resources
*   [FluxCD Documentation](https://fluxcd.io/flux/)
*   [FluxCD with GitHub (Repository Structure)](https://fluxcd.io/flux/guides/repository-structure/#github)
*   [GitHub Actions Documentation](https://docs.github.com/en/actions)
*   [Managing Deploy Keys (GitHub)](https://docs.github.com/en/developers/overview/managing-deploy-keys)
*   [Creating Webhooks (GitHub)](https://docs.github.com/en/webhooks/creating-webhooks)
*   [Azure Login Action for GitHub](https://github.com/Azure/login)

---

## 📝 Migration Checklist (GitHub Focused)

### Pre-Migration
- [ ] New GitHub repository created (`YOUR_GITHUB_ORG/YOUR_REPO_NAME`).
- [ ] All code, branches, and tags pushed from old repository to the new GitHub repository.
- [ ] New SSH deploy key pair generated (`YOUR_PRIVATE_SSH_KEY_PATH` and its `.pub` counterpart).
- [ ] Public deploy key added to GitHub repository (read-only unless Flux needs write access).
- [ ] Plan for GitHub Actions workflows (e.g., `.github/workflows/gitops-cd.yml` created/updated in your local clone).
- [ ] Required secrets for GitHub Actions (e.g., `AZURE_CREDENTIALS`) identified and ready to be configured in GitHub settings.
- [ ] Kubernetes manifest for FluxCD `GitRepository` (pointing to GitHub URL and new secret name) prepared.
- [ ] Kubernetes manifest for FluxCD deploy key `Secret` (with private key + known_hosts) prepared.
- [ ] (If using webhook notifications) Kubernetes manifest for FluxCD `Receiver` (for GitHub) prepared.
- [ ] (If using webhook notifications) Kubernetes `Secret` for the GitHub webhook shared secret prepared.

### During Migration (Execute these steps, ideally during a maintenance window if impacting production)
1.  **Apply to Kubernetes (using `kubectl apply -f <manifest-file> --context YOUR_CLUSTER_CONTEXT_NAME`):**
    - [ ] `Secret` for GitHub deploy key (e.g., `YOUR_GITOPS_REPO_SECRET_NAME`).
    - [ ] Updated `GitRepository` CRD pointing to GitHub.
    - [ ] (If using webhooks) `Secret` for GitHub webhook (e.g., `YOUR_WEBHOOK_SECRET_K8S_NAME`).
    - [ ] (If using webhooks) `Receiver` CRD for GitHub webhooks (e.g., `YOUR_WEBHOOK_RECEIVER_NAME`).
2.  **Configure in GitHub Repository Settings:**
    - [ ] (If using webhooks) Setup webhook in `Settings` > `Webhooks`, pointing to FluxCD receiver URL, using the shared secret. Test delivery.
    - [ ] Configure GitHub Actions secrets in `Settings` > `Secrets and variables` > `Actions` (e.g., `AZURE_CREDENTIALS`).
3.  **Verify FluxCD Synchronization:**
    - [ ] Check `flux get sources git -n YOUR_FLUX_NAMESPACE` shows successful fetch from GitHub.
    - [ ] Check `flux get kustomizations -n YOUR_FLUX_NAMESPACE` status; ensure they are reconciling or ready.
4.  **Test GitHub Actions CI/CD:**
    - [ ] Trigger a Pull Request workflow: Create a test PR, check validation steps run.
    - [ ] Trigger a push workflow: Merge PR to `YOUR_BRANCH_NAME` (or push directly), check deployment/notification steps run.
5.  **Full End-to-End Test:**
    - [ ] Make a small, verifiable change to a manifest, push to GitHub.
    - [ ] Confirm change is deployed to the cluster and functioning as expected.
6.  **Update Local Environments:**
    - [ ] All developers update their local git remotes to point to the new GitHub repository.

### Post-Migration
- [ ] Update all relevant project documentation (READMEs, how-to guides, architectural diagrams, etc.) to reflect GitHub usage, URLs, and CI/CD processes.
- [ ] Communicate changes and new workflows clearly to all team members.
- [ ] Decommission old CI/CD pipelines (e.g., in GitLab).
- [ ] Decommission old webhooks (e.g., in GitLab).
- [ ] (After a stability period and confirmation) Archive or remove the old GitLab repository if it's no longer needed for reference.
- [ ] Update any disaster recovery plans or procedures to include GitHub specific steps and repository locations.

**Estimated Total Migration Time: 8-15 hours**
**Recommended Migration Window: During maintenance hours if impacting production components.**
**Rollback Time Estimate: ~30 minutes - 1 hour (to reconfigure Flux to point to GitLab and revert CI).** 