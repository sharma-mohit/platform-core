# Phase 2: GitOps & Platform Bootstrap (GitHub)

This guide outlines the steps for setting up GitOps with FluxCD and bootstrapping core platform services on an existing AKS cluster. This phase assumes Phase 1 (core Azure infrastructure) is complete.

**This document now assumes GitHub is your Git provider.**

## Table of Contents

- [Prerequisites](#prerequisites)
- [GitOps Setup with FluxCD](#gitops-setup-with-fluxcd)
  - [1. Prepare GitHub Repository & Deploy Keys](#1-prepare-github-repository--deploy-keys)
  - [2. Bootstrap FluxCD on AKS](#2-bootstrap-fluxcd-on-aks)
  - [3. Verify FluxCD Installation](#3-verify-fluxcd-installation)
- [Core Platform Services Deployment](#core-platform-services-deployment)
  - [1. Ingress Controller (NGINX)](#1-ingress-controller-nginx)
  - [2. Certificate Management (cert-manager)](#2-certificate-management-cert-manager)
  - [3. External Secrets Operator (ESO)](#3-external-secrets-operator-eso)
- [Observability Stack (Optional)](#observability-stack-optional)
  - [Prometheus, Grafana, Loki, Tempo]
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Prerequisites

1.  **Phase 1 Completed**: AKS cluster, ACR, Key Vault, and networking are deployed and functional.
2.  **Azure CLI & `kubectl` Access**: Configured for your Azure subscription and AKS cluster.
3.  **FluxCD CLI Installed**: ([Install Guide](https://fluxcd.io/flux/installation/))
4.  **GitHub Repository**: A private GitHub repository created for GitOps manifests (e.g., `platform-core-flux-config`). The `flux-config/` directory structure should be pushed here.
5.  **GitHub Deploy Keys**: An SSH key pair generated. The public key added as a read-only Deploy Key to the GitHub repository, and the private key available for the Flux bootstrap command.
6.  **GitHub Actions (Optional but Recommended)**: Familiarity with setting up GitHub Actions for CI/CD (e.g., manifest validation).
7.  **`kustomize` CLI Installed**: For local testing of Kustomize overlays.

## GitOps Setup with FluxCD (GitHub)

### 1. Prepare GitHub Repository & Deploy Keys

1.  **Create SSH Key Pair** (if not already done):
    ```bash
    ssh-keygen -t ed25519 -C "fluxcd-github@YOUR_REPO_NAME" -f ~/.ssh/flux_github_deploy_key
    # Avoid using a passphrase for this key if used by Flux directly.
    ```
2.  **Add Deploy Key to GitHub**:
    *   Go to your GitHub Repository (e.g., `YOUR_GITHUB_ORG/YOUR_REPO_NAME`) → Settings → Deploy keys → Add deploy key.
    *   **Title**: `fluxcd-readonly-access` (or similar).
    *   **Key**: Paste the content of `~/.ssh/flux_github_deploy_key.pub`.
    *   **Allow write access**: Leave unchecked (Flux typically only needs read access).
    *   Click "Add key".

3.  **Ensure `flux-config/` is Pushed to GitHub**: Your `flux-config/` directory, containing `bases/`, `clusters/` (with your specific cluster configuration like `clusters/platform-core-dev-aks/flux-system/kustomization.yaml`), should be committed and pushed to the main branch of your GitHub repository.

### 2. Bootstrap FluxCD on AKS

Use the `flux bootstrap github` command. Ensure `kubectl` is pointing to your target AKS cluster.

```bash
# Required: Path to your FluxCD runtime SSH private key file
FLUX_SSH_PRIVATE_KEY_FILE="~/.ssh/flux_github_deploy_key"

# Required: Your GitHub username/organization and repository name
GITHUB_OWNER="YOUR_GITHUB_ORG"
GITHUB_REPO="YOUR_REPO_NAME" # e.g., platform-core-flux-config

# Required: Cluster configuration path within the repo
CLUSTER_PATH_IN_REPO="./clusters/platform-core-dev-aks/flux-system" # Adjust to your cluster

# Optional: GitHub Personal Access Token (PAT with 'repo' scope if needed by CLI for repo creation/initial commit)
# export GITHUB_TOKEN="<YOUR_GITHUB_PAT>"

flux bootstrap github \
  --owner="${GITHUB_OWNER}" \
  --repository="${GITHUB_REPO}" \
  --branch=main \
  --path="${CLUSTER_PATH_IN_REPO}" \
  --private-key-file="${FLUX_SSH_PRIVATE_KEY_FILE}" \
  --personal # Use if GITHUB_OWNER is your personal GitHub account, omit for an organization
  # --token-auth # Uncomment if GITHUB_TOKEN is set and PAT should be used by CLI
```
This command installs Flux components on your cluster and configures them to sync with the specified path in your GitHub repository using the SSH key.

### 3. Verify FluxCD Installation

```bash
kubectl get pods -n flux-system
flux check
flux get kustomizations --all-namespaces
flux get sources git --all-namespaces
```
Look for all components running and resources reconciled successfully.

## Core Platform Services Deployment

Once FluxCD is syncing with your `flux-config` repository on GitHub, platform services defined within your Kustomize overlays (e.g., under `flux-config/clusters/YOUR_CLUSTER_NAME/infrastructure/components/`) will be deployed.

Refer to `docs/phase2-fluxcd-architecture.md` and `docs/phase2-fluxcd-operational-guide.md` for details on the structure and how to manage these components.

### 1. Ingress Controller (NGINX)
   - Defined as a HelmRelease in your `flux-config` repository (e.g., `flux-config/bases/ingress-nginx/helmrelease.yaml` and overlaid in `flux-config/clusters/YOUR_CLUSTER_NAME/infrastructure/components/ingress-nginx/`).
   - Verify: `kubectl get pods -n ingress-nginx`

### 2. Certificate Management (cert-manager)
   - Deployed via HelmRelease (e.g., `flux-config/bases/cert-manager/`)
   - ClusterIssuers (e.g., Let's Encrypt) applied via Kustomization (e.g., `flux-config/clusters/YOUR_CLUSTER_NAME/infrastructure/cluster-issuers/`).
   - Verify: `kubectl get pods -n cert-manager`, `kubectl get clusterissuers`

### 3. External Secrets Operator (ESO)
   - Deployed via HelmRelease.
   - Enables syncing secrets from Azure Key Vault into Kubernetes secrets.
   - Verify: `kubectl get pods -n external-secrets`

## Observability Stack (Optional)

Deployment of Prometheus, Grafana, Loki, Tempo, etc., follows the same GitOps pattern: define them as HelmReleases/Kustomizations in your `flux-config` GitHub repository under the appropriate paths.

## Troubleshooting

Common issues during this phase:

1.  **FluxCD Sync Errors**:
    *   `flux get kustomizations --all-namespaces`: Check status and error messages.
    *   `flux logs KUSTOMIZATION_NAME -n flux-system --kind=Kustomization`: Get detailed logs.
    *   Verify paths in `GitRepository` and `Kustomization` resources are correct for your GitHub repo structure.
    *   Check GitHub Deploy Key permissions and that the correct public key is in GitHub and private key in the `flux-system` secret.

2.  **GitHub Integration Issues**:
    *   Verify GitHub Deploy Key has read access to the repository.
    *   If using webhooks (configured as per `docs/GITLAB-TO-GITHUB-MIGRATION.md` or `docs/phase2-fluxcd-operational-guide.md`), check webhook delivery status in GitHub repository settings.

3.  **HelmRelease Failures**:
    *   `flux get helmreleases --all-namespaces`: Check status.
    *   `kubectl describe helmrelease HR_NAME -n NAMESPACE`: For more details.
    *   Check Helm chart values and repository URLs.

4.  **ImagePullBackOff Errors**: Usually due to ACR pull permissions if not using workload identity properly or if AKS identity doesn't have `AcrPull` on the target ACR.

## Next Steps

- Proceed to application deployments using the GitOps workflow.
- Implement CI/CD pipelines (GitHub Actions) for validating and auto-merging changes to your `flux-config` repository.
- Review and enhance security configurations (NetworkPolicies, PodSecurityPolicies/Standards, etc.). 