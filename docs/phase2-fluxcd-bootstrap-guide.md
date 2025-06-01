# Phase 2: FluxCD - Initial Bootstrap Guide (GitHub)

This guide details the initial, one-time steps to bootstrap FluxCD on an Azure Kubernetes Service (AKS) cluster using SSH authentication with a GitHub monorepo.

**For the overall FluxCD GitOps architecture, refer to [./phase2-fluxcd-architecture.md](./phase2-fluxcd-architecture.md).**
**For ongoing operational guidance (managing components, applications, multiple clusters), refer to [./phase2-fluxcd-operational-guide.md](./phase2-fluxcd-operational-guide.md).**

## Prerequisites

1.  **Azure CLI Authenticated**: Ensure you are logged into Azure (`az login`) and have selected the correct subscription.
2.  **`kubectl` Installed and Configured**: `kubectl` must be configured for your target AKS cluster.
    ```bash
    # Example for platform-core-dev-aks
    az aks get-credentials --resource-group YOUR_AKS_RESOURCE_GROUP --name YOUR_AKS_CLUSTER_NAME --overwrite-existing
    # Replace YOUR_AKS_RESOURCE_GROUP and YOUR_AKS_CLUSTER_NAME with your actual values
    ```
3.  **FluxCD CLI Installed**: See [fluxcd.io/flux/installation/](https://fluxcd.io/flux/installation/).
4.  **Required Keys & GitHub Setup:**
    *   **A. GitHub Personal Access Token (PAT) (Optional for CLI, if not using other auth methods for bootstrap)**:
        *   **Purpose**: Can be used by the `flux bootstrap github` command-line tool to interact with the GitHub API (e.g., to create the repository if it doesn't exist, or to commit initial FluxCD synchronization manifests).
        *   **Usage**: If used, set as an environment variable `GITHUB_TOKEN`.
        *   **Scopes**: Needs `repo` scope. For fine-grained PATs, ensure it has content write access.
        *   **Security**: Store this token securely. It is **not** stored in the cluster after bootstrap if SSH keys are used for runtime.
    *   **B. Dedicated SSH Key Pair (for FluxCD Runtime Git Access)**:
        *   **Purpose**: Used by FluxCD components *running in the cluster* for ongoing, secure Git operations (pulling configurations) against your GitHub monorepo.
        *   **Components**: Standard SSH key pair (private and public key).
            *   **Private Key Path**: You will provide the path to this file (e.g., `~/.ssh/flux_github_deploy_key`) to the `flux bootstrap github` command via the `--private-key-file` argument. Bootstrap stores this key as a Kubernetes secret.
            *   **Public Key**: The content of the public key file (e.g., `~/.ssh/flux_github_deploy_key.pub`) must be added as a **Deploy Key** to your GitHub monorepository settings (Settings > Deploy keys > Add deploy key). Grant it read-only access unless Flux features requiring write access are planned (e.g. image update automation).
        *   **Generation**: If you don't have one, generate it: `ssh-keygen -t ed25519 -C "fluxcd-github-monorepo@YOUR_REPO_NAME" -f ~/.ssh/flux_github_deploy_key`. Avoid using a passphrase.

5.  **GitHub Monorepository**: A single, **private** GitHub repository (e.g., `YOUR_GITHUB_ORG/YOUR_REPO_NAME`) to store all FluxCD configurations. The `flux-config/` directory from your project will be the root of Flux's view within this repo.
    *   This repository must be accessible via SSH using the Deploy Key (public part of the SSH key pair from 4B).
    *   The `flux-config/` directory structure (as detailed in `phase2-fluxcd-architecture.md`, containing `bases/`, `clusters/`, etc.) should be committed and pushed to this repository **before** running bootstrap for any cluster targeting this repository.
    *   **For GitHub Enterprise Server**: You will need to use the `--hostname` flag with `flux bootstrap github` to specify your GitHub Enterprise Server hostname.

## Flux Configuration Monorepo - Initial Push to GitHub

Ensure your `flux-config/` directory (containing `bases/`, `clusters/`, the cluster-specific `flux-system/kustomizations.yaml` etc.) is pushed to your new GitHub monorepo.

```bash
# Navigate to your project root where flux-config is a subdirectory
# Example commands, adapt if your setup is different:

# If flux-config is not yet a git repository or not connected to your new GitHub monorepo:
# cd flux-config
# git init -b main
# git remote add origin git@github.com:YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
# git add .
# git commit -m "Initial FluxCD configuration structure for monorepo"
# git push -u origin main
# cd ..

# If platform-core is your main git repo and flux-config is part of it, ensure it's pushed to GitHub.
```
Replace `YOUR_GITHUB_ORG` and `YOUR_REPO_NAME` with your GitHub organization/username and repository name.

## Bootstrapping FluxCD (GitHub - SSH Authentication)

Once the `flux-config` structure is in your GitHub monorepo with the SSH Deploy Key configured, you can bootstrap FluxCD onto your target AKS cluster.

**Ensure your `kubectl` context is pointing to the target AKS cluster.**

```bash
# Optional: Set GitHub Personal Access Token (PAT for bootstrap CLI tool - repo scope)
# If your repository is private and you want flux CLI to create it or make initial commits.
# export GITHUB_TOKEN="<YOUR_GITHUB_PAT>"

# Required: Path to your FluxCD runtime SSH private key file
FLUX_SSH_PRIVATE_KEY_FILE="~/.ssh/flux_github_deploy_key" # Path from Prerequisite 4B

# Required: Your GitHub username/organization and repository name
GITHUB_OWNER="YOUR_GITHUB_ORG"
GITHUB_REPO="YOUR_REPO_NAME"

# Required: The specific cluster name as defined in your flux-config/clusters/ directory
# This is used to build the --path argument
YOUR_CLUSTER_CONFIG_NAME="platform-core-dev-aks" # Example: platform-core-dev-aks

# Optional: For GitHub Enterprise Server
# GITHUB_HOSTNAME="github.example.com"

flux bootstrap github \
  # --hostname="${GITHUB_HOSTNAME}" \ # Uncomment and set if using GitHub Enterprise Server
  --owner="${GITHUB_OWNER}" \
  --repository="${GITHUB_REPO}" \
  --branch=main \
  --path="./clusters/${YOUR_CLUSTER_CONFIG_NAME}/flux-system" \ # Path within flux-config, seen from root of YOUR_REPO_NAME
  --private-key-file="${FLUX_SSH_PRIVATE_KEY_FILE}" \
  --personal # Use if GITHUB_OWNER is your personal account; omit if it's an organization.
  # --token-auth # Uncomment if GITHUB_TOKEN is set and you want to use PAT for bootstrap CLI operations
```

**Explanation of Key Flags for `flux bootstrap github`:**
*   `GITHUB_TOKEN` (Environment Variable, Optional): A GitHub PAT (Prerequisite 4A). If provided and `--token-auth` is used, `flux bootstrap` can use it for API actions like creating the repo (if it doesn't exist) or committing Flux components. For runtime, Flux will use the SSH key.
*   `--private-key-file`: Path to the SSH private key (Prerequisite 4B) for FluxCD's runtime Git access via SSH. Flux stores this as a Kubernetes secret.
*   `--hostname`: (Optional) The hostname of your GitHub Enterprise Server instance.
*   `--owner`: Your GitHub username or organization name where the repository resides.
*   `--repository`: The name of your GitHub repository.
*   `--branch`: The default branch in your repository (e.g., `main`).
*   `--path`: The path within your GitHub repository where FluxCD will look for its own Kustomization (`kustomization.yaml`) and component manifests. This path should point to the `flux-system` directory for a specific cluster within your `flux-config` structure (e.g., `clusters/platform-core-dev-aks/flux-system`).
*   `--personal`: Set if the repository is under a personal GitHub account; omit if it's under an organization.
*   `--token-auth`: If `GITHUB_TOKEN` is set, this flag explicitly tells bootstrap to use token authentication for its API operations.

**What the Bootstrap Command Does (with SSH focus):**
1.  Installs FluxCD components into the `flux-system` namespace on your AKS cluster.
2.  Creates a Kubernetes secret in `flux-system` (default name `flux-system`) containing the SSH private key from `--private-key-file`.
3.  Creates a `GitRepository` resource in your cluster pointing to your GitHub monorepo (using an SSH URL: `ssh://git@github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git` or enterprise equivalent) and configured to use the SSH key secret for authentication.
4.  Creates a root `Kustomization` resource in your cluster that points to the `--path` specified.
5.  Commits FluxCD's own component manifests (`gotk-components.yaml`) and the sync configuration (`gotk-sync.yaml` containing the `GitRepository` and root `Kustomization`) to your GitHub repository at the specified `--path`. This commit is done using Git with credentials (either via local Git config, SSH agent, or PAT if `--token-auth` is used).

## Verifying the Installation

After the bootstrap command completes:

1.  **Check FluxCD components**:
    ```bash
    kubectl get pods -n flux-system --context YOUR_CLUSTER_CONTEXT_NAME
    ```
2.  **Check FluxCD Kustomizations and Git Source**:
    ```bash
    flux get kustomizations --all-namespaces --context YOUR_CLUSTER_CONTEXT_NAME
    flux get sources git --all-namespaces --context YOUR_CLUSTER_CONTEXT_NAME
    # The main GitRepository (e.g., flux-system) and Kustomization (e.g., flux-system)
    # should eventually show READY=True and a recent reconciled status.
    ```
3.  **Inspect the `GitRepository` resource** to confirm SSH usage:
    ```bash
    kubectl get gitrepository -n flux-system flux-system -o yaml --context YOUR_CLUSTER_CONTEXT_NAME
    # (Replace flux-system with the actual name of the GitRepository if different)
    ```
    Look for `spec.url` (should be an `ssh://git@github.com/...` URL) and `spec.secretRef` (pointing to the SSH key secret).

## Next Steps

Once bootstrapped, all further management of infrastructure components and applications is done by making changes to the YAML files within the `flux-config/` directory (which is part of your GitHub monorepo), as per the GitOps workflow detailed in the [FluxCD Operational Guide](./phase2-fluxcd-operational-guide.md). 