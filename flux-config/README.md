# FluxCD Configuration

This directory contains the Kubernetes configurations that will be managed by FluxCD for the AI Platform, following a "base and overlays" pattern.

**For detailed instructions on how to manage your cluster, infrastructure components, and applications using this setup, please refer to the comprehensive guide: [`flux-howto.md`](./flux-howto.md).**

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

Refer to [`flux-howto.md`](./flux-howto.md) for all operational details.

### Bootstrapping

The initial bootstrapping process is detailed in `terraform/docs/phase2-week1-fluxcd-setup.md`. The `--path` for `flux bootstrap` should point to the `flux-system` directory within your cluster's configuration (e.g., `./clusters/platform-core-dev-aks/flux-system`).

```bash
flux bootstrap gitlab --owner=<your-gitlab-username-or-group> \
  --repository=<your-gitlab-repository-name> \
  --branch=main \
  --path=./clusters/<cluster-name>/flux-system \
  --personal \
  --token-auth
``` 