# FluxCD GitOps Architecture (GitHub)

This document outlines the architecture for managing Kubernetes cluster configurations and application deployments using FluxCD with a Kustomize-based GitOps workflow, leveraging a single GitHub monorepo as the source of truth.

**This guide assumes GitHub is the primary Git provider.**

## Table of Contents

- [Overview](#overview)
- [Core Components](#core-components)
  - [1. GitHub Monorepo (`flux-config/`)](#1-github-monorepo-flux-config)
  - [2. FluxCD Controllers](#2-fluxcd-controllers)
  - [3. Kustomize](#3-kustomize)
  - [4. Helm Controller (for Helm charts)](#4-helm-controller-for-helm-charts)
- [FluxCD Authentication with GitHub](#fluxcd-authentication-with-github)
  - [1. Runtime Git Access (SSH Deploy Key)](#1-runtime-git-access-ssh-deploy-key)
  - [2. Initial Bootstrap (`flux bootstrap github` command)](#2-initial-bootstrap-flux-bootstrap-github-command)
    - [GitHub Personal Access Token (PAT) Usage](#github-personal-access-token-pat-usage)
    - [Enterprise/Self-Hosted GitHub Considerations](#enterpriseself-hosted-github-considerations)
- [Directory Structure: `flux-config/` Monorepo](#directory-structure-flux-config-monorepo)
  - [Top-Level Directories](#top-level-directories)
  - [Detailed Structure: `bases/`](#detailed-structure-bases)
  - [Detailed Structure: `clusters/<cluster-name>/`](#detailed-structure-clusterscluster-name)
- [Synchronization Workflow](#synchronization-workflow)
- [Managing Multiple Environments/Clusters](#managing-multiple-environmentsclusters)
- [Security Considerations](#security-considerations)
- [Diagram (Conceptual)](#diagram-conceptual)

## Overview

The GitOps model implemented uses FluxCD to continuously reconcile the state of Kubernetes clusters with the configurations defined in a GitHub monorepo. Kustomize is used for managing environment-specific configurations through a base and overlay structure.

## Core Components

### 1. GitHub Monorepo (`flux-config/`)
- **Single Source of Truth**: All Kubernetes manifests, Kustomize configurations, and HelmRelease definitions for all clusters and applications reside within the `flux-config/` directory in a dedicated, private GitHub repository.
- **Change Management**: All changes to the cluster state are made via commits to this repository, ideally through Pull Requests for review and approval.

### 2. FluxCD Controllers
Installed in the `flux-system` namespace on each managed Kubernetes cluster:
- **Source Controller**: Watches the GitHub repository (via `GitRepository` custom resources) for changes.
- **Kustomize Controller**: Takes Kustomize configurations (defined in `Kustomization` custom resources) and applies the generated manifests to the cluster.
- **Helm Controller**: Manages Helm chart deployments (defined in `HelmRelease` custom resources).
- **Notification Controller**: Handles events and notifications (e.g., webhooks from GitHub, alerts to Slack).

### 3. Kustomize
- **Declarative Configuration**: Used to customize Kubernetes manifests for different environments without forking or templating YAML directly in complex ways.
- **Base and Overlay Structure**: Common configurations are defined in `bases/`, and environment-specific modifications are applied via `overlays/` (typically within each `clusters/<cluster-name>/...` path).

### 4. Helm Controller (for Helm charts)
- **Helm Integration**: FluxCD can manage applications packaged as Helm charts via `HelmRelease` custom resources.
- **GitOps for Helm**: Helm chart sources (`HelmRepository` CRs), versions, and values are all defined declaratively in Git.

## FluxCD Authentication with GitHub

FluxCD interacts with the GitHub monorepo in two main ways, each with its authentication method:

### 1. Runtime Git Access (SSH Deploy Key)
This is how FluxCD components running in the Kubernetes cluster authenticate to the GitHub monorepo for ongoing synchronization.
- **Mechanism**: SSH Key Pair.
  - The **private key** is stored as a Kubernetes secret in the `flux-system` namespace.
  - The **public key** is added as a **Deploy Key** to the GitHub repository (ideally with read-only permissions).
- **Setup**: Configured during the `flux bootstrap github` process using the `--private-key-file` argument.

### 2. Initial Bootstrap (`flux bootstrap github` command)
This is the one-time command run per cluster to install FluxCD components and connect them to the GitHub repository.

#### GitHub Personal Access Token (PAT) Usage
- The `flux bootstrap github` CLI tool itself can use a **GitHub Personal Access Token (PAT)** to interact with the GitHub API if the `--token-auth` flag is used or if `GITHUB_TOKEN` environment variable is set and `--personal` is used with a personal repository.
- **Purpose**: Allows the bootstrap command to perform actions like:
  1.  Verify the existence of the GitHub repository and user permissions.
  2.  Commit the initial FluxCD manifests (e.g., `gotk-components.yaml`, `gotk-sync.yaml`) to the specified `--path` in your GitHub monorepo.
- **Security**: This PAT is for the CLI tool's execution only and is *not* stored in the cluster or used by Flux components for runtime Git access if SSH keys are configured for runtime.

#### Enterprise/Self-Hosted GitHub Considerations
If using a GitHub Enterprise Server instance not hosted on `github.com`:
- `--hostname <your-github-api-hostname>`: Tells the bootstrap CLI which GitHub API endpoint to talk to (using the PAT if applicable for API actions).
- Flux internally constructs the SSH URL using this hostname if SSH is the primary method for runtime.

## Directory Structure: `flux-config/` Monorepo

This structure promotes consistency and manageability across multiple clusters and applications.

### Top-Level Directories

-   **`flux-config/`**
    -   **`bases/`**: Contains common, reusable Kustomize bases for infrastructure components and applications.
    -   **`clusters/`**: Contains cluster-specific configurations (overlays). Each subdirectory represents a unique Kubernetes cluster environment.

### Detailed Structure: `bases/`

-   `bases/`
    -   `<component-or-app-name>/` (e.g., `ingress-nginx/`, `cert-manager/`, `my-app/`)
        -   `helmrelease.yaml`: (If using Helm) The generic `HelmRelease` manifest for this component/app.
        -   `namespace.yaml`: (Optional) If the component typically resides in its own namespace.
        -   `kustomization.yaml`: Defines the resources for this base (e.g., includes `helmrelease.yaml`, `namespace.yaml`).
        -   Other raw Kubernetes manifests forming the base.

### Detailed Structure: `clusters/<cluster-name>/`

-   `clusters/`
    -   `<cluster-name>/` (e.g., `platform-core-dev-aks/`, `platform-core-prod-aks/`)
        -   **`flux-system/`**: This directory is targeted by `flux bootstrap github --path=./clusters/<cluster-name>/flux-system`.
            -   `gotk-components.yaml`: FluxCD component manifests (managed by Flux bootstrap).
            -   `gotk-sync.yaml`: Defines the `GitRepository` source and the root `Kustomization` for this cluster (managed by Flux bootstrap).
            -   `kustomization.yaml`: **You manage this file.** This is the top-level Kustomization for the cluster. It references other Kustomizations (e.g., for infrastructure, apps) within this cluster's configuration directory.
                ```yaml
                apiVersion: kustomize.config.k8s.io/v1beta1
                kind: Kustomization
                resources:
                  - ../infrastructure # Path to the main infra kustomization for this cluster
                  - ../apps         # Path to the main apps kustomization for this cluster
                ```
        -   **`infrastructure/`**: Cluster-specific infrastructure configurations.
            -   `namespaces/`: Kustomization and YAMLs for namespaces specific to this cluster or its infra.
            -   `helm-repositories/`: Kustomization and YAMLs for `HelmRepository` CRs needed by this cluster.
            -   `components/`: Contains Kustomizations that apply overlays to base infrastructure services.
                -   `<component-name>/kustomization.yaml`: (e.g., `ingress-nginx/kustomization.yaml`) Points to a base (e.g., `../../../../../../bases/ingress-nginx`) and applies cluster-specific patches or values.
                -   `kustomization.yaml`: Groups all infrastructure component Kustomizations for this cluster.
            -   `cluster-issuers/`: Kustomizations for `ClusterIssuer` CRs (e.g., for Let's Encrypt), overlaying bases.
            -   `kustomization.yaml`: The main Kustomization for all infrastructure in this cluster. Referenced by `flux-system/kustomization.yaml`.
        -   **`apps/`**: Cluster-specific application configurations.
            -   `<app-name>/kustomization.yaml`: Points to an application base (e.g., `../../../../../../bases/my-app`) and applies cluster-specific patches/values.
            -   `kustomization.yaml`: The main Kustomization for all applications in this cluster. Referenced by `flux-system/kustomization.yaml`.

## Synchronization Workflow

1.  A change is pushed to the `main` branch (or designated branch) of the GitHub monorepo (`flux-config/`).
2.  FluxCD's Source Controller, monitoring the `GitRepository` source, detects the new commit.
3.  The Source Controller fetches the updated manifests and stores them as an Artifact.
4.  The Kustomize Controller is notified of the new Artifact.
5.  The Kustomize Controller reads its `Kustomization` resources (starting from the root one in `clusters/<cluster-name>/flux-system/kustomization.yaml` and traversing dependencies).
6.  For each `Kustomization`, it builds the final set of manifests by applying overlays to bases.
7.  The Kustomize Controller applies these manifests to the Kubernetes cluster.
8.  If `HelmRelease` objects are involved, the Helm Controller picks them up and manages the Helm chart lifecycle (install, upgrade, uninstall).

## Managing Multiple Environments/Clusters

-   Each cluster (e.g., dev, staging, production) has its own dedicated directory under `flux-config/clusters/` (e.g., `platform-core-dev-aks`, `platform-core-stg-aks`).
-   Each cluster is bootstrapped independently with `flux bootstrap github`, pointing to its specific path in the monorepo (e.g., `--path=./clusters/platform-core-stg-aks/flux-system`).
-   This allows for environment-specific configurations and independent lifecycle management while sharing common bases.

## Security Considerations

-   **Least Privilege for Deploy Key**: The SSH Deploy Key used by Flux for runtime Git access should ideally have read-only access to the GitHub monorepo. Write access is only needed if using features like image update automation that commit back to Git.
-   **GitHub PAT Security**: The PAT used for the `flux bootstrap github` CLI command is powerful. It should be stored securely, have minimum necessary scopes (e.g., `repo`), and ideally be short-lived or used in a controlled CI/CD environment for bootstrap.
-   **Secrets Management**: Kubernetes secrets should not be stored directly in Git. Use a solution like:
    -   [External Secrets Operator (ESO)](https://external-secrets.io/): Syncs secrets from external providers like Azure Key Vault into Kubernetes secrets.
    -   [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets): Encrypts secrets before committing them to Git, which can then be decrypted by a controller in the cluster.
-   **Network Policies**: Implement NetworkPolicies to restrict communication between pods based on the principle of least privilege.
-   **RBAC**: Configure Kubernetes RBAC to limit permissions for FluxCD service accounts and other components.
-   **Image Provenance & Scanning**: Integrate image scanning tools into your CI/CD pipeline and potentially use admission controllers (like Kyverno or OPA Gatekeeper) to enforce policies on deployed images.

## Diagram (Conceptual)

```mermaid
graph TD
    Developer -->|Commits to| GitHub[GitHub Monorepo (flux-config/)]
    GitHub -->|Webhook (Optional) or Polls| FluxSourceCtrl[Flux Source Controller (in K8s)]
    FluxSourceCtrl -->|Fetches Manifests| Artifacts[(Manifest Artifacts)]
    Artifacts -->|Notifies| FluxKustomizeCtrl[Flux Kustomize Controller (in K8s)]
    FluxKustomizeCtrl -->|Builds with Kustomize| FinalManifests[(Final Manifests)]
    FinalManifests -->|Applies to| K8sCluster[Kubernetes Cluster API]

    FluxKustomizeCtrl -->|Manages CRD| FluxHelmCtrl[Flux Helm Controller (in K8s)]
    FluxHelmCtrl -->|Manages| HelmCharts[Helm Chart Deployments]

    subgraph "Kubernetes Cluster (flux-system)"
        FluxSourceCtrl
        FluxKustomizeCtrl
        FluxHelmCtrl
    end

    subgraph "GitHub Monorepo (flux-config/)"
        direction LR
        Bases[bases/] --> Overlays[clusters/cluster-A/]
        Overlays --> Kustomization[flux-system/kustomization.yaml]
    end
```

</rewritten_file>