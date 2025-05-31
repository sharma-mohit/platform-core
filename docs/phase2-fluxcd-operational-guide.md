# Phase 2: FluxCD - Operational Guide

This guide provides comprehensive instructions for managing your Kubernetes clusters, infrastructure components, and applications using FluxCD with a single GitLab monorepository and SSH authentication, after the initial bootstrap has been completed.

**For the overall FluxCD GitOps architecture, refer to [./phase2-fluxcd-architecture.md](./phase2-fluxcd-architecture.md).**
**For the initial, one-time bootstrap of FluxCD onto a new cluster, refer to [./phase2-fluxcd-bootstrap-guide.md](./phase2-fluxcd-bootstrap-guide.md).**

## Table of Contents

- [Core Concepts Review](#core-concepts-review)
  - [GitOps with FluxCD](#gitops-with-fluxcd)
  - [Monorepo for Flux Configuration](#monorepo-for-flux-configuration)
  - [Base and Overlays Pattern (Kustomize)](#base-and-overlays-pattern-kustomize)
- [Git Repository Structure (`flux-config/`) Review](#git-repository-structure-flux-config-review)
- [Flux Git Authentication (SSH & Bootstrap PAT) Review](#flux-git-authentication-ssh--bootstrap-pat-review)
- [Managing Kubernetes Resources](#managing-kubernetes-resources)
  - [Namespaces](#namespaces)
  - [Helm Repositories](#helm-repositories)
  - [Helm Releases (Infrastructure & Applications)](#helm-releases-infrastructure--applications)
  - [ClusterIssuers (cert-manager)](#clusterissuers-cert-manager)
- [Workflow: Adding a New Application](#workflow-adding-a-new-application)
- [Workflow: Updating an Existing Application/Component](#workflow-updating-an-existing-applicationcomponent)
- [Workflow: Adding a New Cluster (Post-Initial Setup)](#workflow-adding-a-new-cluster-post-initial-setup)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
- [Security Considerations Review](#security-considerations-review)

## Core Concepts Review

A brief review of concepts detailed in the [Architecture Guide](./phase2-fluxcd-architecture.md).

### GitOps with FluxCD
Your Git repository (`flux-config/` directory) is the single source of truth. FluxCD automates deployment and configuration synchronization.

### Monorepo for Flux Configuration
All FluxCD configurations for all environments and clusters are in the `flux-config/` directory within a single GitLab repository.

### Base and Overlays Pattern (Kustomize)
- **`flux-config/bases/`**: Common, reusable configurations.
- **`flux-config/clusters/<cluster-name>/`**: Environment-specific overlays that customize bases.

## Git Repository Structure (`flux-config/`) Review

Refer to the [Architecture Guide](./phase2-fluxcd-architecture.md) for the detailed structure of the `flux-config/` monorepo directory.
Key reminder: `clusters/<cluster-name>/flux-system/kustomizations.yaml` is the main entry point for a cluster's synchronization, managed by you.
`gotk-sync.yaml` and `gotk-components.yaml` in the same directory are managed by the `flux bootstrap` process.

## Flux Git Authentication (SSH & Bootstrap PAT) Review

- **Runtime (SSH)**: Flux components in the cluster use an SSH key pair (private key in a K8s secret, public key as a GitLab Deploy Key) for ongoing Git operations. This is set up by the bootstrap process.
- **Initial Bootstrap (`flux bootstrap gitlab` command)**: The CLI tool itself requires a GitLab Personal Access Token (PAT) for API interactions and to commit initial Flux files to the repository. This PAT is not used by Flux runtime. Details in the [Bootstrap Guide](./phase2-fluxcd-bootstrap-guide.md).

## Managing Kubernetes Resources

All resources are defined as YAML manifests within the `flux-config` directory and managed by Kustomizations. Changes are made by committing to Git.

### Namespaces
- Define each namespace in its own YAML file (e.g., `dev-backend-ns.yaml`) within `flux-config/clusters/<cluster-name>/infrastructure/namespaces/`.
- A `kustomization.yaml` in that directory lists all namespace files.
- This Kustomization is then referenced by the main cluster Kustomization (`flux-config/clusters/<cluster-name>/flux-system/kustomizations.yaml`) usually as a dependency for other resources.

    ```yaml
    # flux-config/clusters/platform-core-dev-aks/infrastructure/namespaces/dev-backend-ns.yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: dev-backend
    ```

### Helm Repositories
- Define `HelmRepository` resources (CRDs provided by Flux) in `flux-config/clusters/<cluster-name>/infrastructure/helm-repositories/`.
- A `kustomization.yaml` in that directory lists all Helm repository files.

    ```yaml
    # flux-config/clusters/platform-core-dev-aks/infrastructure/helm-repositories/jetstack-hr.yaml
    apiVersion: source.toolkit.fluxcd.io/v1beta2 # or v1 for newer Flux versions
    kind: HelmRepository
    metadata:
      name: jetstack
      namespace: flux-system # Typically deployed in flux-system to be globally available for Flux
    spec:
      interval: 1h # How often to fetch new Helm chart versions
      url: https://charts.jetstack.io
    ```

### Helm Releases (Infrastructure & Applications)

Follows the base/overlay pattern.

1.  **Base HelmRelease**: Defined in `flux-config/bases/<component-name>/helmrelease.yaml`.
    ```yaml
    # flux-config/bases/ingress-nginx/helmrelease.yaml
    apiVersion: helm.toolkit.fluxcd.io/v2 # or v2beta2 for older Flux versions
    kind: HelmRelease
    metadata:
      name: ingress-nginx # This name will be patched by overlays if a different release name is needed per cluster
      namespace: ingress-nginx # Default namespace, can be overridden by overlay Kustomization
    spec:
      interval: 5m
      chart:
        spec:
          chart: ingress-nginx
          sourceRef:
            kind: HelmRepository
            name: ingress-nginx # Assumes a HelmRepository CR with this name exists in flux-system
            namespace: flux-system
          version: "4.0.0" # Specify desired chart version
      # Common values can go here
      values: 
        controller:
          replicaCount: 2
    ```
    And its accompanying `kustomization.yaml`:
    ```yaml
    # flux-config/bases/ingress-nginx/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - helmrelease.yaml
    ```

2.  **Overlay Kustomization**: In `flux-config/clusters/<cluster-name>/infrastructure/components/<component-name>/kustomization.yaml` (for infra) or `flux-config/clusters/<cluster-name>/apps/<app-name>/kustomization.yaml` (for apps).
    This file points to the base and applies cluster-specific patches or adds values.

    ```yaml
    # flux-config/clusters/platform-core-dev-aks/infrastructure/components/ingress-nginx/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    namespace: ingress-nginx # Ensures all resources from this overlay are in the ingress-nginx namespace
    resources:
      - ../../../../../bases/ingress-nginx # Relative path to the base Kustomization
    patches:
      - target:
          kind: HelmRelease
          name: ingress-nginx # Must match the name in the base helmrelease.yaml
        patch: |-
          apiVersion: helm.toolkit.fluxcd.io/v2 # or v2beta2
          kind: HelmRelease
          metadata:
            name: ingress-nginx-dev # Cluster-specific release name (if differentiation is needed)
          spec:
            values:
              controller:
                replicaCount: 1 # Dev-specific value
                service:
                  annotations:
                    # Example Azure-specific annotation for internal LB
                    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    ```
    This overlay Kustomization is then referenced in a grouping Kustomization (e.g., `flux-config/clusters/<cluster-name>/infrastructure/components/kustomization.yaml`), which is in turn referenced by the main cluster Kustomization (`flux-config/clusters/<cluster-name>/flux-system/kustomizations.yaml`).

### ClusterIssuers (cert-manager)
Similar to HelmReleases, `ClusterIssuer` (or `Issuer`) resources for cert-manager are managed with a base/overlay pattern.

1.  **Base Issuer**: Defined in `flux-config/bases/cluster-issuers/<issuer-name>/issuer.yaml`.
    ```yaml
    # flux-config/bases/cluster-issuers/letsencrypt-staging/issuer.yaml
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-staging # Base name
    spec:
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: your-default-email@example.com # Replace with your default email
        privateKeySecretRef:
          name: letsencrypt-staging-private-key # Secret to store ACME account private key
        solvers:
          - http01:
              ingress:
                class: nginx # Assumes nginx ingress controller is used
    ```
    And its `kustomization.yaml`:
    ```yaml
    # flux-config/bases/cluster-issuers/letsencrypt-staging/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - issuer.yaml
    ```

2.  **Overlay Kustomization**: In `flux-config/clusters/<cluster-name>/infrastructure/cluster-issuers/<issuer-name>/kustomization.yaml`.
    ```yaml
    # flux-config/clusters/platform-core-dev-aks/infrastructure/cluster-issuers/letsencrypt-staging/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - ../../../../../../bases/cluster-issuers/letsencrypt-staging # Path to base
    # Patches can be added if needed, e.g., to change the email for this specific cluster.
    patches:
      - target:
          kind: ClusterIssuer
          name: letsencrypt-staging
        patch: |-
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          spec:
            acme:
              email: dev-cluster-admin@example.com # Override email for dev cluster
    ```

## Workflow: Adding a New Application

Assume you have a Helm chart for your application `my-app`.

1.  **Create Base Configuration (Recommended)**:
    *   Create `flux-config/bases/my-app/`.
    *   Inside, create `helmrelease.yaml` with common HelmRelease settings for `my-app`.
    *   Create `kustomization.yaml` referencing `helmrelease.yaml`.

2.  **Create Overlay Configuration for the Target Cluster (e.g., `dev` cluster)**:
    *   Create `flux-config/clusters/platform-core-dev-aks/apps/my-app/kustomization.yaml`.
        *   In `resources:`, reference the base: `../../../../../../bases/my-app`.
        *   Add a `patches:` section to customize the HelmRelease (e.g., set dev-specific values, image tags, namespace if different from base).
        *   If `my-app` needs additional manifests specific to `dev` (e.g., `configmap-dev.yaml`), create them in this directory and add them to `resources:` list in this Kustomization.

3.  **Update App Group Kustomization for the Cluster**:
    *   Edit `flux-config/clusters/platform-core-dev-aks/apps/kustomization.yaml`.
    *   Add a reference to your new app's overlay Kustomization: `- ./my-app`.

4.  **Ensure Dependencies are Met (Namespace, Helm Repo, etc.)**:
    *   If `my-app` needs a new namespace, ensure it's defined under `flux-config/clusters/platform-core-dev-aks/infrastructure/namespaces/` and included in its Kustomization.
    *   If `my-app` uses a new Helm repository, ensure the `HelmRepository` CR is defined under `flux-config/clusters/platform-core-dev-aks/infrastructure/helm-repositories/`.
    *   Update the main cluster Kustomization (`flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml`) to include these dependencies if they are new, using `dependsOn` to ensure correct creation order (e.g., app Kustomization `dependsOn` namespace Kustomization).

5.  **Commit and Push Changes**: Commit all new/modified files to your GitLab monorepository and push to the `main` (or your target) branch.

6.  **Verify**: Flux will automatically reconcile. Check with `flux get kustomizations -A` (all namespaces) and `flux get helmreleases -A`. Look for status and events.

## Workflow: Updating an Existing Application/Component

1.  **Identify Files**: Locate the base configuration (`flux-config/bases/...`) and/or the overlay Kustomization (`flux-config/clusters/<cluster-name>/...`) for the component.
2.  **Make Changes**: Modify Helm values in the base `helmrelease.yaml`, image tags or other settings in patches within overlay `kustomization.yaml`, ConfigMap data, etc., as needed.
3.  **Commit and Push**: Commit changes to GitLab.
4.  **Verify**: Flux will reconcile. Use `flux` CLI commands to check status (e.g., `flux get hr <release-name> -n <namespace>`).

## Workflow: Adding a New Cluster (Post-Initial Setup)

This assumes you have already bootstrapped at least one cluster and want to add another (e.g., `staging`).

1.  **Create New Cluster Directory Structure in Git**:
    *   In `flux-config/clusters/`, create a new directory for your cluster (e.g., `platform-core-stg-aks`).
    *   Mimic the subdirectory structure of an existing cluster (e.g., copy from `platform-core-dev-aks`), focusing on `infrastructure/` and `apps/` overlays, and the main `flux-system/kustomizations.yaml`.
    *   **Do NOT copy `flux-system/gotk-components.yaml` or `flux-system/gotk-sync.yaml` from another cluster.** These are specific to a bootstrap instance and will be (re)generated for the new cluster by its own bootstrap.
2.  **Adapt Configuration Files for the New Cluster**:
    *   Modify `flux-config/clusters/platform-core-stg-aks/flux-system/kustomizations.yaml` to reference the correct paths within the `platform-core-stg-aks` directory for its infrastructure and apps.
    *   Review and adapt all Kustomizations and YAML overlay files within the new `platform-core-stg-aks/` directory to suit the new environment (e.g., different replica counts, endpoints, resource limits, image tags if not managed by base patches appropriately).
3.  **Push New Cluster Configuration Structure to GitLab**: Commit and push the new `flux-config/clusters/platform-core-stg-aks/` directory with its adapted configurations (excluding `gotk-*.yaml` files) to your GitLab monorepository.
4.  **Bootstrap FluxCD on the New Physical Cluster**: This step is identical to the initial bootstrap process for any cluster, but targets the new physical Kubernetes cluster and the new path in Git.
    *   Ensure your `kubectl` context points to the new physical Kubernetes cluster (e.g., `platform-core-stg-aks`).
    *   Run the `flux bootstrap gitlab ...` command as detailed in the [Bootstrap Guide](./phase2-fluxcd-bootstrap-guide.md).
        *   Crucially, set the `--path` argument to the `flux-system` directory of your new cluster configuration in Git (e.g., `--path=./clusters/platform-core-stg-aks/flux-system`).
        *   Use the same GitLab monorepo details (`--owner`, `--repository`), SSH private key file (`--private-key-file`), and your `GITLAB_TOKEN`.
    *   This command will generate and commit `gotk-components.yaml` and `gotk-sync.yaml` specifically for this new cluster into `flux-config/clusters/platform-core-stg-aks/flux-system/` in your GitLab repository.
5.  **Verify**: Once bootstrapped, Flux on the new cluster will start reconciling the configuration from the path you specified (e.g., `flux-config/clusters/platform-core-stg-aks/flux-system/kustomizations.yaml`).

## Troubleshooting Common Issues

-   **`flux get kustomizations -A` / `flux get hr -A` (HelmRelease)**: Check status, readiness, and error messages for all Flux resources in all namespaces. Use `-A` for all namespaces.
-   **`flux logs <controller-name> -n flux-system --level=error`**: View error logs (e.g., `flux logs kustomize-controller -n flux-system --level=error`). Increase log verbosity (`--level=info` or `debug`) if needed.
-   **`flux reconcile kustomization <name> -n <namespace> --with-source`**: Force reconciliation of a specific Kustomization and its source.
-   **`kubectl describe <resource-type> <resource-name> -n <namespace>`**: Get detailed events and status for specific Kubernetes resources managed by Flux (e.g., `kubectl describe kustomization infra-components -n flux-system`).
-   **Check `dependsOn`**: Incorrect dependencies in Kustomization resources are a common source of errors. Ensure components that rely on others (e.g., an app needing a namespace or a HelmRepository) have the correct `dependsOn` entries pointing to the Kustomization managing the dependency.
-   **SSH Key Issues**:
    *   Verify the public key is correctly added as a Deploy Key in your GitLab repository settings and has appropriate (read-only is sufficient) access.
    *   Ensure the private key secret (default `flux-system` in `flux-system` namespace) exists in the cluster and is correctly referenced by the `GitRepository` resource in `flux-config/clusters/<cluster-name>/flux-system/gotk-sync.yaml`.
    *   Check permissions on the SSH key files if issues arise during local `flux bootstrap` execution.
-   **Kustomize Build Errors**: Run `kustomize build <path-to-kustomization-dir>` locally to validate Kustomize configurations before committing.
-   **Helm Errors**: Use `flux get hr <helmrelease-name> -n <namespace>` and `kubectl describe hr <helmrelease-name> -n <namespace>` to see Helm-specific errors. Check Helm values and chart versions in your `HelmRelease` manifests.

## Security Considerations Review

Refer to the [Architecture Guide](./phase2-fluxcd-architecture.md) for detailed security considerations, including:
-   Principle of Least Privilege for the SSH Deploy Key.
-   Secure management of the GitLab PAT for bootstrap.
-   RBAC for Flux components and secrets.
-   Secrets management strategies for applications. 