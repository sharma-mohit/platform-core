# Phase 2: FluxCD - Initial Bootstrap Guide

This guide details the initial, one-time steps to bootstrap FluxCD on an Azure Kubernetes Service (AKS) cluster using SSH authentication with a GitLab monorepo.

**For the overall FluxCD GitOps architecture, refer to [./phase2-fluxcd-architecture.md](./phase2-fluxcd-architecture.md).**
**For ongoing operational guidance (managing components, applications, multiple clusters), refer to [./phase2-fluxcd-operational-guide.md](./phase2-fluxcd-operational-guide.md).**

## Prerequisites

1.  **Azure CLI Authenticated**: Ensure you are logged into Azure (`az login`) and have selected the correct subscription.
2.  **`kubectl` Installed and Configured**: `kubectl` must be configured for your target AKS cluster.
    ```bash
    # Example for platform-core-dev-aks
    az aks get-credentials --resource-group rg-aks-dev-uaenorth-001 --name platform-core-dev-aks --overwrite-existing
    ```
3.  **FluxCD CLI Installed**: See [fluxcd.io/flux/installation/](https://fluxcd.io/flux/installation/).
4.  **Required Keys & Tokens (Clarification):**
    *   **A. GitLab Personal Access Token (PAT)**:
        *   **Purpose**: Required *only* for the `flux bootstrap gitlab` command-line tool to interact with the GitLab API during initial setup.
        *   **Usage**: The CLI uses this to verify repository access, and to commit initial FluxCD synchronization manifests back to your GitLab repository.
        *   **Scopes**: Needs `api`, `read_repository`, and `write_repository` scopes.
        *   **Security**: Store this token securely (e.g., as an environment variable `GITLAB_TOKEN`). It is **not** stored in the cluster and **not** used by Flux components for ongoing operations.
    *   **B. Dedicated SSH Key Pair (for FluxCD Runtime)**:
        *   **Purpose**: Used by FluxCD components *running in the cluster* for ongoing, secure Git operations (pulling configurations) against your GitLab monorepo.
        *   **Components**: This is a standard SSH key pair consisting of a private key and a public key.
            *   **Private Key**: You will provide the *path* to this file (e.g., `~/.ssh/flux_gitlab_platform_core_deploy_key`) to the `flux bootstrap` command via the `--private-key-file` argument. The bootstrap process will store this key as a Kubernetes secret in the `flux-system` namespace.
            *   **Public Key**: The content of the public key file (e.g., `~/.ssh/flux_gitlab_platform_core_deploy_key.pub`) must be added as a **Deploy Key** to your GitLab monorepository settings. Grant it read-only access if possible.
        *   **Generation**: If you don't have one, generate it: `ssh-keygen -t ed25519 -C "fluxcd-gitlab-monorepo" -f ~/.ssh/flux_gitlab_monorepo_deploy_key`. Avoid using a passphrase for this key if `--private-key-file` is used directly, or ensure an agent can provide it.

5.  **GitLab Monorepository**: A single, private GitLab repository (e.g., `platform-core-flux-config`) to store all FluxCD configurations (root of this repo is the `flux-config/` directory).
    *   This repository must be accessible via SSH using the Deploy Key (public part of the SSH key pair from 4B) configured above.
    *   The `flux-config/` directory structure (as detailed in `phase2-fluxcd-architecture.md`) should be committed and pushed to this repository **before** running bootstrap for any cluster.
    *   **For Enterprise/Self-Hosted GitLab**: If you are using a self-hosted GitLab instance, you will need its API URL (for `--hostname`) and SSH access URL (for `--ssh-hostname`) for the bootstrap command.

## Flux Configuration Monorepo - Initial Push

Ensure your `flux-config/` directory (containing `bases/`, `clusters/`, the cluster-specific `flux-system/kustomizations.yaml` etc.) is pushed to your GitLab monorepo.

```bash
# From the root of the platform-core project
cd flux-config
# Ensure it's a Git repo, add remote for your GitLab monorepo, commit, and push.
# Example (if not already done, replace placeholders):
# git init -b main
# git remote add origin git@<YOUR_GITLAB_SSH_HOSTNAME>:<YOUR_GITLAB_USERNAME_OR_GROUP>/<YOUR_FLUX_MONOREPO_NAME>.git
# git add .
# git commit -m "Initial FluxCD configuration structure for monorepo"
# git push -u origin main
cd ..
```
Replace `<YOUR_GITLAB_SSH_HOSTNAME>` (e.g., `gitlab.com` or `gitlab.example.com`), `<YOUR_GITLAB_USERNAME_OR_GROUP>`, and `<YOUR_FLUX_MONOREPO_NAME>`.

## Bootstrapping FluxCD (SSH Authentication)

Once the `flux-config` monorepository is set up in GitLab with the SSH Deploy Key (public key from 4B), and you have your GitLab PAT (from 4A), you can bootstrap FluxCD onto your target AKS cluster.

**Ensure your `kubectl` context is pointing to the target AKS cluster and the `GITLAB_TOKEN` environment variable is set.**

```bash
# Required: Set your GitLab Personal Access Token (PAT for bootstrap CLI tool)
export GITLAB_TOKEN="<YOUR_GITLAB_PAT>"

# Required: Path to your FluxCD runtime SSH private key file
FLUX_SSH_PRIVATE_KEY_FILE="~/.ssh/flux_gitlab_monorepo_deploy_key"

# Required: Your GitLab username/group and repository name
GITLAB_OWNER="<YOUR_GITLAB_USERNAME_OR_GROUP>"
GITLAB_REPO="<YOUR_FLUX_MONOREPO_NAME>"

# Optional: For self-hosted/enterprise GitLab instances
# GITLAB_API_HOSTNAME="gitlab.example.com" # Your GitLab API hostname (for PAT auth by CLI)
# GITLAB_SSH_HOSTNAME="gitlab.example.com" # Your GitLab SSH hostname (for runtime SSH access by Flux)

flux bootstrap gitlab \
  # --hostname="${GITLAB_API_HOSTNAME}" \ # Uncomment and set if using self-hosted GitLab API
  # --ssh-hostname="${GITLAB_SSH_HOSTNAME}" \ # Uncomment and set if SSH hostname differs or for self-hosted
  --owner="${GITLAB_OWNER}" \
  --repository="${GITLAB_REPO}" \
  --branch=main \
  --path=./clusters/<YOUR_CLUSTER_NAME>/flux-system \ # e.g., ./clusters/platform-core-dev-aks/flux-system
  --private-key-file="${FLUX_SSH_PRIVATE_KEY_FILE}" \
  --personal # Use if the repository is under your personal namespace; omit for group repositories
```

**Explanation of Key Flags:**
*   `GITLAB_TOKEN` (Environment Variable): The GitLab PAT (Prerequisite 4A) used by the `flux bootstrap` CLI tool for GitLab API interactions.
*   `--private-key-file`: Path to the SSH private key (Prerequisite 4B) for FluxCD's runtime Git access. Flux stores this as a Kubernetes secret.
*   `--hostname`: (Optional) The API hostname of your self-hosted GitLab instance for the bootstrap CLI.
*   `--ssh-hostname`: (Optional) The hostname for SSH Git URLs used by Flux runtime. Defaults to `--hostname` or `gitlab.com`.
*   `--owner`, `--repository`, `--branch`, `--path`, `--personal`: Standard Flux bootstrap flags defining the target repository and path for synchronization.

**What the Bootstrap Command Does:**
1.  Uses the `GITLAB_TOKEN` to interact with the GitLab API.
2.  Installs FluxCD components into the `flux-system` namespace on your AKS cluster.
3.  Creates a Kubernetes secret in `flux-system` (default name `flux-system`) containing the SSH private key from `--private-key-file`.
4.  Creates a `GitRepository` resource in your cluster pointing to your GitLab monorepo (using an SSH URL derived from `--ssh-hostname` or `--hostname`) and configured to use the SSH key secret for authentication.
5.  Creates a root `Kustomization` resource in your cluster that points to the `--path` specified (e.g., `clusters/<YOUR_CLUSTER_NAME>/flux-system`).
6.  Commits FluxCD's own component manifests (`gotk-components.yaml`) and the sync configuration (`gotk-sync.yaml` containing the `GitRepository` and root `Kustomization`) to your GitLab repository at the specified `--path`, using the `GITLAB_TOKEN` for this one-time commit.

## Verifying the Installation

After the bootstrap command completes:

1.  **Check FluxCD components**:
    ```bash
    kubectl get pods -n flux-system
    ```
2.  **Check FluxCD Kustomizations and Git Source**:
    ```bash
    flux get kustomizations -n flux-system
    flux get source git -n flux-system flux-system # Name of GitRepository is typically flux-system
    ```
    The main Kustomization (e.g., `flux-system` which syncs the specified `--path`) should eventually show `READY=True`.
3.  **Inspect the GitRepository resource** to confirm SSH usage:
    ```bash
    kubectl get gitrepository -n flux-system flux-system -o yaml
    ```
    Look for `spec.url` (should be an `ssh://` or `git@` URL) and `spec.secretRef` (pointing to the SSH key secret).

## Next Steps

Once bootstrapped, all further management of infrastructure components and applications is done by making changes to the YAML files within the `flux-config` monorepository, as per the GitOps workflow detailed in the [FluxCD Operational Guide](./phase2-fluxcd-operational-guide.md). 