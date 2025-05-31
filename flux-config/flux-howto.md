# How to Manage Your Cluster and Applications with FluxCD

This guide explains how to manage your Kubernetes cluster configurations and deploy applications using the FluxCD GitOps setup, which follows a "base and overlays" pattern.

## Understanding the "Base and Overlays" Structure

Our FluxCD configuration is organized to promote reusability and manage environment-specific variations effectively:

-   **`flux-config/bases/`**: This directory contains common, reusable base configurations for services and applications.
    -   Each service or application (e.g., `ingress-nginx`, `cert-manager`, `my-cool-api`) has its own subdirectory (e.g., `bases/ingress-nginx/`, `bases/apps/my-cool-api/`).
    -   Inside, you'll typically find a generic `helmrelease.yaml` (if it's a Helm chart) and a `kustomization.yaml` that bundles the base resources.
    -   These base configurations should be as generic as possible, without cluster-specific values hardcoded.

-   **`flux-config/clusters/<your-cluster-name>/`** (e.g., `flux-config/clusters/platform-core-dev-aks/`): This directory contains cluster-specific configurations (overlays).
    -   **`flux-system/kustomizations.yaml`**: This is the master Kustomization file for the cluster, orchestrated by FluxCD after bootstrapping. It defines the order and dependencies for applying all other configurations (infrastructure and applications) for this specific cluster.
    -   **`infrastructure/`**: Manages core cluster services.
        -   `namespaces/`: Cluster-specific Kubernetes namespaces.
        -   `helm-repositories/`: `HelmRepository` sources needed for this cluster.
        -   `cluster-issuers/`: `ClusterIssuer` resources for certificate management.
        -   `components/`: This is where overlays for base infrastructure services are defined.
            -   Each service has a subdirectory (e.g., `components/ingress-nginx/`).
            -   Inside, a `kustomization.yaml` points to the corresponding base in `flux-config/bases/` (e.g., `../../../../../bases/ingress-nginx`).
            -   This overlay `kustomization.yaml` is where you apply cluster-specific patches (e.g., change replica counts, update domain names, set resource limits for this cluster).
            -   A parent `infrastructure/components/kustomization.yaml` groups all these component overlays.
    -   **`apps/`**: Manages your deployable applications for this cluster.
        -   Similar to infrastructure components, each application has a subdirectory (e.g., `apps/my-cool-api/`).
        -   Inside, a `kustomization.yaml` points to the application's base configuration in `flux-config/bases/apps/` and applies cluster-specific overlays (e.g., environment variables, different image tags for dev vs. prod).
        -   A parent `apps/kustomization.yaml` groups all these application overlays for the cluster.

## General GitOps Workflow

1.  **Make Changes Locally**: Edit or add YAML files in your local clone of the `flux-config` Git repository.
2.  **Commit Changes**: `git add .`, `git commit -m "Your descriptive message"`.
3.  **Push to GitLab**: `git push`.
4.  **FluxCD Syncs**: FluxCD, running in your cluster, detects the changes in the Git repository and automatically applies them to your cluster according to the Kustomization definitions.

## Managing Infrastructure Components

Infrastructure components are core services like ingress controllers, certificate managers, service meshes (e.g., Cilium), or custom platform services (e.g., Portkey).

**1. Adding a New Infrastructure Component (e.g., `external-secrets-operator`)**

   a.  **Define the Base Configuration**:
       -   Create a new directory: `flux-config/bases/external-secrets-operator/`
       -   Add the generic `helmrelease.yaml` (if it's a Helm chart) or Kubernetes manifests for the component.
       -   Add a `kustomization.yaml` in this directory bundling its resources (e.g., just `resources: [- helmrelease.yaml]`).

   b.  **Define the Cluster-Specific Overlay** (for `platform-core-dev-aks`):
       -   Create a new directory: `flux-config/clusters/platform-core-dev-aks/infrastructure/components/external-secrets-operator/`
       -   Inside, create a `kustomization.yaml`:
         ```yaml
         apiVersion: kustomize.config.k8s.io/v1beta1
         kind: Kustomization
         resources:
           - ../../../../../bases/external-secrets-operator # Path to the base
         # Add patches here for dev-specific configurations if needed
         # patches:
         #   - patch: |-
         #       - op: replace
         #         path: /spec/values/someValue
         #         value: "dev-specific-setting"
         #     target:
         #       kind: HelmRelease
         #       name: external-secrets-operator # Ensure name matches the HelmRelease in the base
         #       namespace: external-secrets # Ensure namespace matches
         ```

   c.  **Include in Cluster's Infrastructure Components**:
       -   Edit `flux-config/clusters/platform-core-dev-aks/infrastructure/components/kustomization.yaml`.
       -   Add `./external-secrets-operator` to the `resources` list.

   d.  **Verify Dependencies (Optional but Recommended)**:
       -   Check `flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml`.
       -   The `infra-components` Kustomization (for Helm-based services) and `infra-cluster-issuers` Kustomization should already be orchestrating these. Ensure their `dependsOn` clauses are appropriate (e.g., `infra-cluster-issuers` depends on `infra-components` because Cert-Manager needs to be running).

**2. Updating an Existing Infrastructure Component**

   -   **To change base configuration (affects all clusters using this base)**: Edit files in `flux-config/bases/<component-name>/`.
   -   **To change cluster-specific configuration**: Edit the Kustomization and/or patches in `flux-config/clusters/<your-cluster-name>/infrastructure/components/<component-name>/kustomization.yaml`.

**3. Removing an Infrastructure Component**

   a.  Remove its entry from `flux-config/clusters/<your-cluster-name>/infrastructure/components/kustomization.yaml`.
   b.  (Optional) Delete the overlay directory: `flux-config/clusters/<your-cluster-name>/infrastructure/components/<component-name>/`.
   c.  (Optional, if no other cluster uses it) Delete the base directory: `flux-config/bases/<component-name>/`.
   d.  Commit and push. FluxCD (with `prune: true`) will remove the component from the cluster.

## Deploying and Managing Applications

Applications are your own workloads (APIs, frontends, services).

**1. Adding a New Application (e.g., `my-invoice-api`)**

   a.  **Define the Base Application Configuration**:
       -   Create a directory: `flux-config/bases/apps/my-invoice-api/`
       -   Add your application's `helmrelease.yaml` (if using Helm) or Kubernetes manifests (Deployment, Service, Ingress, etc.).
       -   Add a `kustomization.yaml` in this base directory, listing its resources.

   b.  **Define the Cluster-Specific Application Overlay** (for `platform-core-dev-aks`):
       -   Create a directory: `flux-config/clusters/platform-core-dev-aks/apps/my-invoice-api/`
       -   Inside, create a `kustomization.yaml`:
         ```yaml
         apiVersion: kustomize.config.k8s.io/v1beta1
         kind: Kustomization
         resources:
           - ../../../../../bases/apps/my-invoice-api # Path to the app base
         # Add patches for dev-specific values (e.g., image tag, env vars, replicas)
         # patchesStrategicMerge:
         # - dev-values.yaml # If using a separate values file for patches
         # patches:
         #  - patch: |-
         #      - op: replace
         #        path: /spec/template/spec/containers/0/image
         #        value: youracr.azurecr.io/my-invoice-api:dev-latest
         #    target:
         #      kind: Deployment
         #      name: my-invoice-api
         ```

   c.  **Include in Cluster's Applications List**:
       -   Edit `flux-config/clusters/platform-core-dev-aks/apps/kustomization.yaml`.
       -   Add `./my-invoice-api` to the `resources` list.

   d.  **Verify Dependencies (Implicit)**:
       -   The main `apps` Kustomization in `flux-config/clusters/platform-core-dev-aks/flux-system/kustomizations.yaml` already depends on `infra-cluster-issuers`. This ensures infrastructure (like namespaces, ingress, cert-manager) is ready before apps are deployed.

**2. Updating an Existing Application**

   -   **To change base configuration**: Edit files in `flux-config/bases/apps/<app-name>/`.
   -   **To change cluster-specific configuration (e.g., deploy a new image version to dev)**: Edit the Kustomization and/or patches in `flux-config/clusters/<your-cluster-name>/apps/<app-name>/kustomization.yaml`.

**3. Removing an Application**

   a.  Remove its entry from `flux-config/clusters/<your-cluster-name>/apps/kustomization.yaml`.
   b.  (Optional) Delete the overlay directory: `flux-config/clusters/<your-cluster-name>/apps/<app-name>/`.
   c.  (Optional, if no other cluster uses it) Delete the base directory: `flux-config/bases/apps/<app-name>/`.
   d.  Commit and push. FluxCD will remove the application from the cluster.

## Managing Dependencies (`dependsOn`)

FluxCD uses `dependsOn` within its `Kustomization` resources (primarily in `flux-config/clusters/<your-cluster-name>/flux-system/kustomizations.yaml`) to ensure resources are created in the correct order. For example:
-   Namespaces are created before anything is deployed into them.
-   Helm repositories are available before HelmReleases try to use them.
-   Infrastructure components (like Cert-Manager, deployed via `infra-components`) are running before `ClusterIssuer`s (managed by `infra-cluster-issuers`) are created.
-   All infrastructure is ready before applications are deployed.

If a new component or application has specific dependencies, you might need to adjust the `dependsOn` arrays in `flux-system/kustomizations.yaml` or introduce finer-grained dependencies if one app depends on another.

## Troubleshooting FluxCD

If things don't appear as expected in your cluster:

1.  **Check FluxCD CLI for Status**:
    ```bash
    # Check overall sync status for Kustomizations and HelmReleases
    flux get kustomizations --all-namespaces
    flux get helmreleases --all-namespaces

    # Check specific resources (replace <name> and <namespace>)
    flux get kustomization <kustomization-name> -n flux-system
    flux get source git flux-system -n flux-system # Check Git repository sync
    flux get helmrelease <helmrelease-name> -n <target-namespace>
    flux get helmchart <helmchart-name> -n <target-namespace>
    ```

2.  **Inspect Flux Controller Logs**:
    ```bash
    kubectl logs -n flux-system deployment/source-controller
    kubectl logs -n flux-system deployment/kustomize-controller
    kubectl logs -n flux-system deployment/helm-controller
    kubectl logs -n flux-system deployment/notification-controller # If using notifications
    ```

3.  **Check Kubernetes Events**:
    ```bash
    # General events in flux-system
    kubectl get events -n flux-system --sort-by=.metadata.creationTimestamp

    # Events for a specific namespace where you expect resources
    kubectl get events -n <target-namespace> --sort-by=.metadata.creationTimestamp
    ```

4.  **Reconcile Manually (if needed)**:
    You can trigger a reconciliation for a specific resource if you suspect it's stuck or want to force an update without waiting for the interval.
    ```bash
    flux reconcile kustomization <kustomization-name> -n flux-system
    flux reconcile source git flux-system -n flux-system
    flux reconcile helmrelease <helmrelease-name> -n <target-namespace>
    ```

5.  **Validate Your Manifests**: Sometimes, errors are due to invalid YAML or incorrect Kubernetes manifest definitions. Use `kubectl apply --dry-run=client -f <your-file.yaml>` or linters locally before committing.

This base and overlays structure, combined with GitOps, provides a powerful and scalable way to manage your Kubernetes ecosystem. 