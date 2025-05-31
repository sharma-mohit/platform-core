# Phase 2 - Week 1: FluxCD Bootstrap on AKS (SSH Authentication)

This guide details the initial one-time steps to bootstrap FluxCD on the `platform-core-dev-aks` Azure Kubernetes Service (AKS) cluster using SSH authentication. FluxCD will manage your Kubernetes cluster's configuration and application deployments declaratively from a single GitLab monorepository.

**For ongoing operational guidance on managing your cluster, infrastructure components, and applications with FluxCD, please refer to the comprehensive guide located at `flux-config/flux-howto.md` in this repository.**

## Prerequisites

1.  **Azure CLI Authenticated**: Ensure you are logged into Azure (`az login`) and have selected the correct subscription.
2.  **kubectl Installed and Configured**: `kubectl` must be configured for your `platform-core-dev-aks` cluster.
    ```bash
    az aks get-credentials --resource-group rg-aks-dev-uaenorth-001 --name platform-core-dev-aks --overwrite-existing
    ```
3.  **FluxCD CLI Installed**: See [fluxcd.io/flux/installation/](https://fluxcd.io/flux/installation/).
4.  **SSH Key Pair for FluxCD**: You will need a dedicated SSH key pair.
    *   **Generate the SSH Key Pair**: If you don't have one, generate it using `ssh-keygen -t ed25519 -C "fluxcd-gitlab-platform-core" -f ~/.ssh/flux_gitlab_platform_core_deploy_key`. Avoid using a passphrase for this key if you intend to use `--private-key-file` directly with the bootstrap command, or ensure your SSH agent can provide the key without interaction.
    *   **Public Key**: The content of the public key (e.g., `~/.ssh/flux_gitlab_platform_core_deploy_key.pub`) must be added as a **Deploy Key** to your GitLab `flux-config` monorepository. Grant it read-only access if possible, as Flux only needs to pull configurations.
    *   **Private Key**: You will need the path to the private key file (e.g., `~/.ssh/flux_gitlab_platform_core_deploy_key`) for the bootstrap command.
5.  **GitLab Monorepository**: A single, private GitLab repository (e.g., `platform-core-flux-config`) to store all FluxCD configurations (for dev, stg, prd, etc.). This repository should be accessible via SSH using the deploy key configured above. The `flux-config` directory in *this* project (`platform-core`) should be the root of that GitLab monorepository.

## Flux Configuration Directory Structure Overview

The `flux-config` directory in this project is structured to use a "base and overlays" pattern within the monorepo. Detailed explanations are in `flux-config/flux-howto.md`.

```
flux-config/  (This entire directory is the root of your GitLab monorepo)
├── README.md
├── flux-howto.md
├── bases/ 
│   └── ...
└── clusters/
    ├── platform-core-dev-aks/  # Overlays for the dev cluster
    │   ├── flux-system/          # FluxCD's own files & main Kustomization for this cluster
    │   │   └── kustomizations.yaml
    │   ├── infrastructure/
    │   └── apps/
    ├── platform-core-stg-aks/  # Future staging cluster overlays
    │   └── ...
    └── platform-core-prd-aks/  # Future production cluster overlays
        └── ...
```

**Important**: Before bootstrapping any cluster, ensure the entire `flux-config` directory structure (including `bases/`, `clusters/`, and all necessary YAML files and Kustomizations) is committed and pushed to your GitLab monorepository.

```bash
# From the root of the platform-core project
cd flux-config
# Ensure it's a Git repo, add remote for your GitLab monorepo, commit, and push.
# Example (if not already done):
# git init -b main
# git remote add origin git@gitlab.com:<YOUR_GITLAB_USERNAME_OR_GROUP>/<YOUR_FLUX_MONOREPO_NAME>.git
# git add .
# git commit -m "Initial FluxCD configuration structure for monorepo"
# git push -u origin main
cd ..
```
Replace `<YOUR_GITLAB_USERNAME_OR_GROUP>` and `<YOUR_FLUX_MONOREPO_NAME>`.

## Bootstrapping FluxCD (SSH Authentication)

Once the `flux-config` monorepository is set up in GitLab with the SSH deploy key, you can bootstrap FluxCD onto your `platform-core-dev-aks` cluster. This command installs Flux components and configures them to synchronize with your GitLab repository using SSH.

**Ensure your `kubectl` context is pointing to `platform-core-dev-aks`**.

```bash
# Replace with the actual path to your FluxCD private key file
FLUX_PRIVATE_KEY_FILE="~/.ssh/flux_gitlab_platform_core_deploy_key"

# Replace with your GitLab username/group and repository name
GITLAB_OWNER="<YOUR_GITLAB_USERNAME_OR_GROUP>"
GITLAB_REPO="<YOUR_FLUX_MONOREPO_NAME>"

flux bootstrap gitlab \
  --owner="${GITLAB_OWNER}" \
  --repository="${GITLAB_REPO}" \
  --branch=main \
  --path=./clusters/platform-core-dev-aks/flux-system \
  --private-key-file="${FLUX_PRIVATE_KEY_FILE}" \
  --personal # Use if the repository is under your personal namespace; omit for group repositories
```

**Explanation of Flags for SSH:**
*   `--owner`: Your GitLab username or group name that owns the repository.
*   `--repository`: The name of your GitLab monorepository (e.g., `platform-core-flux-config`). Flux will construct the SSH URL (e.g., `ssh://git@gitlab.com/${GITLAB_OWNER}/${GITLAB_REPO}.git`).
*   `--private-key-file`: Path to the private SSH key that corresponds to the deploy key configured in GitLab. Flux will use this to create a Kubernetes secret.
*   `--branch`: The Git branch FluxCD should monitor (e.g., `main`).
*   `--path`: The directory within the monorepository that FluxCD should synchronize for this specific cluster (e.g., `./clusters/platform-core-dev-aks/flux-system`).
*   `--personal`: Include if the repository is in your personal GitLab namespace. Omit if it's a group repository.

This command will:
1.  Install FluxCD components into the `flux-system` namespace on your AKS cluster.
2.  Create a Kubernetes secret in `flux-system` containing the provided SSH private key.
3.  Create a `GitRepository` resource in your cluster pointing to your GitLab monorepository (using an SSH URL) and configured to use the SSH key secret for authentication.
4.  Create a root `Kustomization` resource in your cluster that points to the `--path` specified.
5.  Commit FluxCD's own component manifests and the Kustomization that syncs the specified path to your GitLab repository at that path.

## Verifying the Installation

After the bootstrap command completes:

1.  **Check FluxCD components**:
    ```bash
    kubectl get pods -n flux-system
    ```
2.  **Check FluxCD Kustomizations and Git Source**:
    ```bash
    flux get kustomizations -n flux-system
    flux get source git flux-system -n flux-system
    ```
    The `cluster-config` Kustomization (and others it depends on) should eventually show `READY=True`.
3.  **Inspect the GitRepository resource** to confirm SSH usage:
    ```bash
    kubectl get gitrepositories -n flux-system flux-system -o yaml
    ```
    Look for the `spec.url` (should be an `ssh://` or `git@` URL) and `spec.secretRef` (pointing to the SSH key secret).

## Next Steps for Cluster Management

All further management of infrastructure and applications should be done by making changes to the YAML files within the `flux-config` monorepository, as per the GitOps workflow.

**Refer to `flux-config/flux-howto.md` for detailed instructions.** 