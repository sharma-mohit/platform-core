# FluxCD GitOps Operational Guide (GitHub)

This guide provides operational instructions for managing Kubernetes cluster configurations, infrastructure components, and applications using FluxCD with a single GitHub monorepository and SSH authentication, after the initial bootstrap has been completed.

**For the initial bootstrap procedure, refer to [./phase2-fluxcd-bootstrap-guide.md](./phase2-fluxcd-bootstrap-guide.md).**
**For the overall FluxCD architecture, refer to [./phase2-fluxcd-architecture.md](./phase2-fluxcd-architecture.md).**

## Table of Contents

- [Core Concepts Review](#core-concepts-review)
  - [GitHub Monorepo for Flux Configuration](#github-monorepo-for-flux-configuration)
  - [Kustomize Bases and Overlays](#kustomize-bases-and-overlays)
  - [FluxCD Controllers](#fluxcd-controllers)
  - [Authentication (SSH & PAT)](#authentication-ssh--pat)
- [Managing Cluster Configurations](#managing-cluster-configurations)
  - [Directory Structure (`flux-config/`)](#directory-structure-flux-config)
  - [Updating an Existing Component](#updating-an-existing-component)
  - [Adding a New Infrastructure Component](#adding-a-new-infrastructure-component)
  - [Adding a New Application](#adding-a-new-application)
- [Managing Multiple Clusters](#managing-multiple-clusters)
  - [Adding a New Cluster Environment](#adding-a-new-cluster-environment)
- [FluxCD CLI Common Commands](#fluxcd-cli-common-commands)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Security Best Practices](#security-best-practices)

## Core Concepts Review

### GitHub Monorepo for Flux Configuration
All FluxCD configurations for all environments and clusters are in the `flux-config/` directory within a single GitHub repository.
- **Source of Truth**: This repository is the single source of truth for the desired state of your Kubernetes clusters.
- **Git Workflow**: Changes are made via standard Git commits and pull requests (if your team uses them).

### Kustomize Bases and Overlays
- **`bases/`**: Contains generic, reusable Kustomize configurations for services (e.g., `bases/ingress-nginx/`, `bases/cert-manager/`). Each base typically includes a `helmrelease.yaml` and a `kustomization.yaml`.
- **`clusters/<cluster-name>/`**: Contains cluster-specific overlays that customize the bases. For example, `clusters/platform-core-dev-aks/infrastructure/components/ingress-nginx/kustomization.yaml` would point to `../../../../../../bases/ingress-nginx` and apply dev-specific patches or values.

### FluxCD Controllers
- **Source Controller**: Fetches manifests from the GitHub repository.
- **Kustomize Controller**: Applies Kustomize overlays and deploys the resulting manifests.
- **Helm Controller**: Manages Helm chart releases defined by `HelmRelease` objects.
- **Notification Controller**: Handles inbound events (e.g., GitHub webhooks) and outbound notifications.

### Authentication (SSH & PAT)
- **Runtime (SSH)**: Flux components in the cluster use an SSH key pair (private key in a K8s secret, public key as a GitHub Deploy Key) for ongoing Git operations. This is set up by the bootstrap process.
- **Initial Bootstrap (`flux bootstrap github` command)**: The CLI tool itself might use a GitHub Personal Access Token (PAT) for API interactions (if `--token-auth` is used) and to commit initial Flux files to the repository. This PAT is not used by Flux runtime if SSH is configured. Details in the [Bootstrap Guide](./phase2-fluxcd-bootstrap-guide.md).

## Managing Cluster Configurations

### Directory Structure (`flux-config/`)
(Refer to `docs/phase2-fluxcd-architecture.md` for a detailed diagram and explanation)

-   **`flux-config/`**
    -   **`bases/`**
        -   `<component-or-app-name>/` (e.g., `ingress-nginx/`, `my-app/`)
            -   `helmrelease.yaml` (if using Helm)
            -   `kustomization.yaml`
            -   Other raw Kubernetes manifests...
    -   **`clusters/`**
        -   `<cluster-name>/` (e.g., `platform-core-dev-aks/`)
            -   **`flux-system/`**: Managed by Flux bootstrap. Contains `gotk-*.yaml` and the root `kustomization.yaml` you manage for this cluster.
            -   **`infrastructure/`**: Kustomizations for infrastructure components.
                -   `namespaces/`
                -   `helm-repositories/`
                -   `components/` (overlays for base components)
                -   `cluster-issuers/`
                -   `kustomization.yaml` (groups all infra items for this cluster)
            -   **`apps/`**: Kustomizations for applications.
                -   `<app-name>/` (overlay for a base app)
                -   `kustomization.yaml` (groups all apps for this cluster)

### Updating an Existing Component
(e.g., Upgrading an NGINX Ingress controller version)

1.  **Modify Base Configuration (if applicable)**:
    *   Edit the HelmRelease in `flux-config/bases/ingress-nginx/helmrelease.yaml` to specify the new chart version.
    *   Update any default values if necessary.

2.  **Modify Overlay Configuration (if applicable)**:
    *   If your cluster-specific overlay in `flux-config/clusters/platform-core-dev-aks/infrastructure/components/ingress-nginx/` has version constraints or specific values that need adjustment for the new version, update them there.

3.  **Commit and Push Changes**: Commit all modified files to your GitHub monorepository and push to the `main` (or your target) branch.
    ```bash
    git add flux-config/bases/ingress-nginx/helmrelease.yaml
    # Potentially add overlay files if changed
    git commit -m "Upgrade ingress-nginx to version X.Y.Z"
    git push origin main
    ```

4.  **Monitor Reconciliation**: Flux will automatically detect the changes and apply them.
    ```bash
    flux get kustomizations --all-namespaces --watch
    flux get helmreleases -n ingress-nginx --watch
    # Check pod statuses in the relevant namespace (e.g., ingress-nginx)
    kubectl get pods -n ingress-nginx
    ```

### Adding a New Infrastructure Component
(e.g., Adding a new monitoring tool, `awesome-monitor`)

1.  **Create Base Configuration**:
    *   Create a new directory: `flux-config/bases/awesome-monitor/`
    *   Add its `helmrelease.yaml` (if using Helm) or raw Kubernetes manifests.
    *   Add a `kustomization.yaml` in `flux-config/bases/awesome-monitor/`:
        ```yaml
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        resources:
          - helmrelease.yaml # Or your other manifests
        # Potentially a namespace.yaml if it needs its own namespace
        ```

2.  **Create Cluster Overlay**:
    *   Create an overlay directory: `flux-config/clusters/platform-core-dev-aks/infrastructure/components/awesome-monitor/`
    *   Add a `kustomization.yaml` that points to the base and applies any cluster-specific patches or values:
        ```yaml
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        resources:
          - ../../../../../../bases/awesome-monitor # Path to the base
        # patchesStrategicMerge:
        #  - awesome-monitor-values-patch.yaml # If you need to override Helm values
        ```
    *   (Optional) Add `awesome-monitor-values-patch.yaml` if you need to provide cluster-specific Helm values.

3.  **Reference in Cluster's Infrastructure Kustomization**:
    *   Edit `flux-config/clusters/platform-core-dev-aks/infrastructure/components/kustomization.yaml`.
    *   Add `./awesome-monitor` to its `resources:` list.
    *   Ensure correct dependencies are set using `dependsOn` if `awesome-monitor` requires other components to be ready first.

4.  **Commit and Push Changes**: Commit all new/modified files to your GitHub monorepository.
    ```bash
    git add flux-config/bases/awesome-monitor/
    git add flux-config/clusters/platform-core-dev-aks/infrastructure/components/awesome-monitor/
    git add flux-config/clusters/platform-core-dev-aks/infrastructure/components/kustomization.yaml
    git commit -m "Add awesome-monitor component"
    git push origin main
    ```

5.  **Monitor Reconciliation**.

### Adding a New Application
Similar to adding an infrastructure component, but typically under the `flux-config/apps/` directory structure.

1.  **Create Base Application Configuration**: `flux-config/bases/my-cool-app/` (with its `helmrelease.yaml` or manifests, and `kustomization.yaml`).
2.  **Create Cluster Overlay for Application**: `flux-config/clusters/platform-core-dev-aks/apps/my-cool-app/kustomization.yaml` (pointing to the base and applying cluster-specific config).
3.  **Reference in Cluster's Apps Kustomization**: Edit `flux-config/clusters/platform-core-dev-aks/apps/kustomization.yaml` and add `./my-cool-app` to its `resources:` list.
4.  **Commit and Push**: Commit changes to GitHub.
5.  **Monitor Reconciliation**.

## Managing Multiple Clusters

Your `flux-config/` monorepo is designed to manage multiple clusters (e.g., dev, staging, prod) from the same repository.

### Adding a New Cluster Environment
(e.g., Setting up a new `platform-core-stg-aks` cluster)

1.  **Prerequisite**: The new AKS cluster (`platform-core-stg-aks`) must exist.

2.  **Create Cluster-Specific Configuration Directory**: Duplicate an existing cluster's configuration structure as a starting point.
    ```bash
    cp -r flux-config/clusters/platform-core-dev-aks/ flux-config/clusters/platform-core-stg-aks/
    ```

3.  **Customize for New Cluster**:
    *   **Remove Flux-managed files**: Delete `flux-config/clusters/platform-core-stg-aks/flux-system/gotk-*.yaml` files. These will be regenerated by the bootstrap process for the new cluster.
    *   **Adapt `kustomization.yaml`**: Modify `flux-config/clusters/platform-core-stg-aks/flux-system/kustomization.yaml` to ensure it references the correct paths within the *new* `platform-core-stg-aks` directory (e.g., `../infrastructure`, `../apps`).
    *   **Update Overlays**: Go through the files in `flux-config/clusters/platform-core-stg-aks/infrastructure/` and `flux-config/clusters/platform-core-stg-aks/apps/` and adjust any configurations (e.g., resource limits, hostnames, replica counts, Key Vault URLs) that are specific to the staging environment.

4.  **Push New Cluster Configuration Structure to GitHub**: Commit and push the new `flux-config/clusters/platform-core-stg-aks/` directory with its adapted configurations (excluding `gotk-*.yaml` files) to your GitHub monorepository.

5.  **Bootstrap FluxCD on the New Cluster**:
    *   Ensure `kubectl` is configured for the new `platform-core-stg-aks` cluster.
    *   Run the `flux bootstrap github ...` command as detailed in the [Bootstrap Guide](./phase2-fluxcd-bootstrap-guide.md).
    *   Use the same GitHub monorepo details (`--owner`, `--repository`), SSH private key file (`--private-key-file`).
    *   **Crucially, update the `--path` argument** to point to the new cluster's configuration: `--path=./clusters/platform-core-stg-aks/flux-system/` in your GitHub repository.

6.  **Monitor and Verify**: Check FluxCD components and Kustomizations on the new staging cluster. Ensure it reconciles successfully and deploys the staging-specific configurations.

## FluxCD CLI Common Commands
(Always specify `--context YOUR_CLUSTER_CONTEXT_NAME` if not your current default context)

-   `flux check`: Check prerequisites and Flux components.
-   `flux get kustomizations --all-namespaces`: List all Kustomizations and their status.
-   `flux get sources git --all-namespaces`: List GitRepository sources and their status.
-   `flux get helmreleases --all-namespaces`: List HelmReleases and their status.
-   `flux logs KUSTOMIZATION_NAME -n flux-system --kind=Kustomization`: View logs for a Kustomization.
-   `flux reconcile kustomization KUSTOMIZATION_NAME --with-source`: Force reconcile a Kustomization and its source.
-   `flux reconcile source git GITREPO_NAME`: Force reconcile a GitRepository.
-   `flux suspend kustomization KUSTOMIZATION_NAME`: Suspend reconciliation for a Kustomization.
-   `flux resume kustomization KUSTOMIZATION_NAME`: Resume reconciliation.

## Troubleshooting Common Issues

-   **ImagePullBackOff/ErrImagePull**: Check ACR permissions, Workload Identity setup (if used for ACR), image name/tag correctness.
-   **Kustomization Reconciliation Failure**: `flux get kustomizations`, `flux logs ...`. Check for YAML syntax errors, incorrect paths in Kustomizations, missing resources, or issues in the base/overlay manifests.
-   **HelmRelease Failure**: `flux get helmreleases`, `kubectl describe helmrelease ...`. Check Helm chart values, repository URL, chart version. Look at logs of `helm-controller`.
-   **GitRepository Fetch Failure**: `flux get sources git`. Check `spec.url` and `spec.secretRef` in the `GitRepository` CRD. Verify the SSH private key in the secret is correct and the public key is in GitHub with read access. Test SSH connectivity from a pod if needed.
-   **Webhook Issues (if configured)**: Check GitHub webhook delivery logs. Check `notification-controller` logs in `flux-system`.

## Security Best Practices

-   **Least Privilege**: The SSH Deploy Key used by Flux should have read-only access to the GitHub monorepo unless features like image update automation (which require write access) are used.
-   **GitHub PAT Security (for bootstrap CLI)**: If a PAT is used for the `flux bootstrap github` command, it should be stored securely, have minimum necessary scopes (e.g., `repo`), and ideally be short-lived or used in a controlled CI/CD environment for bootstrap.
-   **Kustomize Overlays for Secrets**: Do not commit raw secrets to Git. Use a secrets management solution like External Secrets Operator (ESO) to fetch secrets from Azure Key Vault. Your Kustomize overlays might define `ExternalSecret` resources.
-   **Network Policies**: Implement NetworkPolicies to restrict traffic between pods.
-   **Regular Audits**: Regularly review Flux configurations and RBAC permissions.
-   **Keep Flux Updated**: Stay current with FluxCD releases for security patches and new features. 