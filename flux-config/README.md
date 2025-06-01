# FluxCD Configuration (Monorepo)

This directory (`flux-config/`) is the root of the GitHub monorepository used to manage all Kubernetes cluster configurations via FluxCD, following GitOps principles.

It contains the actual Kustomize bases and cluster-specific overlays that define the desired state of your Kubernetes environments.

## Documentation

For a complete understanding of the FluxCD setup, including architecture, initial bootstrap, and ongoing operational procedures, please refer to the main documentation in the `docs/` directory at the root of this project:

1.  **FluxCD Architecture**: Understand the design, monorepo structure, Kustomize patterns, and authentication mechanisms.
    *   [`../docs/phase2-fluxcd-architecture.md`](../docs/phase2-fluxcd-architecture.md)

2.  **Initial Cluster Bootstrap Guide**: Step-by-step instructions for setting up FluxCD on a new AKS cluster for the first time.
    *   [`../docs/phase2-fluxcd-bootstrap-guide.md`](../docs/phase2-fluxcd-bootstrap-guide.md)

3.  **FluxCD Operational Guide**: Comprehensive instructions for managing your cluster configurations, infrastructure components, and applications *after* initial bootstrap.
    *   [`../docs/phase2-fluxcd-operational-guide.md`](../docs/phase2-fluxcd-operational-guide.md)

## Repository Structure Overview (`flux-config/`)

-   **`bases/`**: Contains common, reusable Kustomize bases for infrastructure and applications.
-   **`clusters/`**: Contains cluster-specific overlays. Each sub-directory (e.g., `platform-core-dev-aks/`) represents a unique Kubernetes cluster environment and includes:
    -   `flux-system/`: FluxCD's own synchronization configurations for that cluster (including the main `kustomizations.yaml` you manage, and `gotk-*.yaml` files managed by Flux bootstrap).
    -   `infrastructure/`: Overlays for shared infrastructure components.
    -   `apps/`: Overlays for application deployments.

For a detailed explanation of this structure and how to work with it, please consult the [FluxCD Operational Guide](../docs/phase2-fluxcd-operational-guide.md) and the [FluxCD Architecture Guide](../docs/phase2-fluxcd-architecture.md).

## Directory Structure Overview

-   `flux-howto.md`: The main operational guide.
-   `bases/`: Contains common, reusable base configurations for services and applications.
    -   `<service-or-app-name>/`
        -   `helmrelease.yaml`: The generic HelmRelease manifest.
        -   `kustomization.yaml`: Kustomization file for this base.
        -   Potentially other default manifests.
-   `clusters/<cluster-name>/`: Contains cluster-specific configurations (overlays).
    -   `flux-system/`: FluxCD's own configuration and the main Kustomization (`kustomizations.yaml`) that orchestrates all syncs for this cluster.
    -   `infrastructure/`: Cluster-specific infrastructure configurations.
        -   `namespaces/`: Definitions for namespaces specific to this cluster or used by its infrastructure.
        -   `helm-repositories/`: HelmRepository custom resources needed by this cluster.
        -   `components/`: Kustomizations that apply overlays to base infrastructure services.
            -   `<service-name>/kustomization.yaml`: Points to a base in `../../../../../bases/<service-name>` and applies cluster-specific patches.
            -   `kustomization.yaml`: Groups all infrastructure component Kustomizations for this cluster.
        -   `cluster-issuers/`: ClusterIssuer custom resources (e.g., for Let's Encrypt).
        -   Other manifests (ServiceAccounts, NetworkPolicies, etc.) specific to this cluster's infrastructure.
    -   `apps/`: Contains Kustomizations for applications deployed to this cluster, which overlay base application configurations.
        -   `<app-name>/kustomization.yaml`: Points to a base in `../../../../../bases/<app-name>` and applies cluster-specific patches/values.
        -   `kustomization.yaml`: Groups all application Kustomizations for this cluster.

## Usage

FluxCD will monitor the Git repository. The main Kustomization (`clusters/<cluster-name>/flux-system/kustomizations.yaml`) defines how base configurations are layered with cluster-specific overlays and the order of application.

Refer to [`../docs/phase2-fluxcd-operational-guide.md`](../docs/phase2-fluxcd-operational-guide.md) for all operational details.

### Bootstrapping

The initial bootstrapping process is detailed in `../docs/phase2-fluxcd-bootstrap-guide.md`. The `--path` for `flux bootstrap` should point to the `flux-system` directory within your cluster's configuration (e.g., `./clusters/platform-core-dev-aks/flux-system`).

```bash
flux bootstrap github --owner=<your-github-username-or-org> \
  --repository=<your-github-repository-name> \
  --branch=main \
  --path=./clusters/<cluster-name>/flux-system \
  --personal # Use --token-auth if using a PAT for bootstrap, otherwise SSH is default
``` 