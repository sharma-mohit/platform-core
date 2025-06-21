# Phase 3: Observability Stack Foundation - How-To Guide

This guide provides the step-by-step instructions to deploy the foundational infrastructure for the centralized observability stack as outlined in the `WEEK3-OBSERVABILITY-PLAN.md`. This phase involves provisioning Azure resources via Terraform for the central operations cluster (`ops`) and configuring the development workload cluster (`dev`) to communicate with it.

**For the overall observability architecture, refer to [./WEEK3-OBSERVABILITY-PLAN.md](./WEEK3-OBSERVABILITY-PLAN.md).**

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Overview](#deployment-overview)
- [Step 1: Provision the Central Operations (`ops`) Cluster Infrastructure](#step-1-provision-the-central-operations-ops-cluster-infrastructure)
- [Step 2: Provision the Workload (`dev`) Cluster Agent Infrastructure](#step-2-provision-the-workload-dev-cluster-agent-infrastructure)
- [Step 3: Bootstrap the `ops` Cluster with FluxCD](#step-3-bootstrap-the-ops-cluster-with-fluxcd)
- [Step 4: Verify FluxCD Synchronization](#step-4-verify-fluxcd-synchronization)
- [Step 5: Deploy Observability Components via FluxCD](#step-5-deploy-observability-components-via-fluxcd)
- [Troubleshooting](#troubleshooting)

## Prerequisites

1.  **Phase 1 & 2 Completed**: The core Azure infrastructure (from Phase 1) and the GitOps bootstrap for the `dev` cluster (from Phase 2) must be complete.
2.  **Azure CLI & `kubectl` Access**: Configured for your Azure subscription and existing AKS clusters.
3.  **FluxCD CLI Installed**: ([Install Guide](https://fluxcd.io/flux/installation/))
4.  **GitHub Monorepo**: Your `flux-config` and `terraform` code must be pushed to your GitHub repository.
5.  **SSH Key for Flux**: The SSH private key used for FluxCD bootstrap must be available.

## Deployment Overview

This phase is deployed in two parts:

1.  **`ops-uaenorth` Environment**: We will first apply Terraform configurations to create a new AKS cluster dedicated to central observability tools (Mimir, Loki, Tempo, etc.). This also creates the necessary storage accounts.
2.  **`dev-uaenorth` Environment**: We will then apply Terraform changes to the existing `dev` cluster. This doesn't create new resources in `dev`, but it grants the `dev` cluster's identity the required permissions to access the secrets (like storage keys) from the `ops` cluster's Key Vault. This is achieved using a `terraform_remote_state` data source.

**IMPORTANT**: You must apply the `ops-uaenorth` changes *before* applying the `dev-uaenorth` changes, as the `dev` deployment depends on the `ops` deployment's output.

## Step 1: Provision the Central Operations (`ops`) Cluster Infrastructure

This step creates the `ops-uaenorth` AKS cluster and all its dependencies, including the storage accounts for the LGTM stack.

1.  **Navigate to the `ops` environment directory**:
    ```bash
    cd terraform/envs/ops-uaenorth
    ```

2.  **Initialize Terraform**:
    This command configures the backend to use the correct state file for the `ops` environment.
    ```bash
    terraform init -backend-config=backend.hcl
    ```

3.  **Plan the Deployment**:
    Review the plan to see what resources will be created. You should see a new AKS cluster, a new resource group for observability, and three new storage accounts.
    ```bash
    terraform plan -out=tfplan
    ```

4.  **Apply the Configuration**:
    This will start the provisioning of the `ops` cluster. This step will take some time.
    ```bash
    terraform apply tfplan
    ```

## Step 2: Provision the Workload (`dev`) Cluster Agent Infrastructure

This step updates the `dev-uaenorth` environment to grant it permissions to the central Key Vault created in the `ops` environment.

1.  **Navigate to the `dev` environment directory**:
    ```bash
    cd ../dev-uaenorth
    ```

2.  **Initialize Terraform**:
    Re-initialize Terraform for the `dev` environment.
    ```bash
    terraform init -backend-config=backend.hcl
    ```

3.  **Plan the Deployment**:
    Review the plan. It should show the creation of a new `azurerm_key_vault_access_policy`. The plan will read remote state from the `ops` environment to get the Key Vault ID.
    ```bash
    terraform plan -out=tfplan
    ```

4.  **Apply the Configuration**:
    ```bash
    terraform apply tfplan
    ```

## Step 3: Bootstrap the `ops` Cluster with FluxCD

Now that the `ops-uaenorth` AKS cluster exists, we need to bootstrap it with FluxCD so it can start managing itself from the Git repository.

1.  **Get `ops` Cluster Credentials**:
    Configure `kubectl` to point to your newly created `ops` cluster.
    ```bash
    # Get the resource group and cluster name from Terraform output if needed
    OPS_AKS_RG=$(terraform -chdir="../../envs/ops-uaenorth" output -raw resource_group_name)
    OPS_AKS_NAME=$(terraform -chdir="../../envs/ops-uaenorth" output -raw aks_cluster_name)

    az aks get-credentials --resource-group "${OPS_AKS_RG}" --name "${OPS_AKS_NAME}" --overwrite-existing
    ```

2.  **Run Flux Bootstrap**:
    This command is similar to the one used for the `dev` cluster, but with the `--path` argument pointing to the `ops` cluster's configuration directory.
    ```bash
    # --- Replace these placeholders ---
    GITHUB_OWNER="YOUR_GITHUB_ORG"
    GITHUB_REPO="YOUR_REPO_NAME"
    FLUX_SSH_PRIVATE_KEY_FILE="~/.ssh/flux_github_deploy_key" # The same key used for dev
    # ---

    flux bootstrap github \
      --owner="${GITHUB_OWNER}" \
      --repository="${GITHUB_REPO}" \
      --branch=main \
      --path="./clusters/platform-core-ops-aks/flux-system" \
      --private-key-file="${FLUX_SSH_PRIVATE_KEY_FILE}" \
      --personal # Use if GITHUB_OWNER is your personal GitHub account, omit for an organization
    ```

## Step 4: Verify FluxCD Synchronization

1.  **Check the `ops` cluster**:
    Ensure `kubectl` is still configured for the `ops` cluster.
    ```bash
    flux get kustomizations --all-namespaces
    ```
    You should see the `flux-system` kustomization, and it should eventually reconcile. It will then start reconciling the `infrastructure` kustomization, which in turn includes `observability`, and all the components underneath (mimir, loki, etc.).

2.  **Check the `dev` cluster**:
    Switch your `kubectl` context back to the `dev` cluster.
    ```bash
    az aks get-credentials --resource-group YOUR_DEV_AKS_RESOURCE_GROUP --name YOUR_DEV_AKS_CLUSTER_NAME --overwrite-existing
    ```
    The `infrastructure` kustomization should have been updated automatically by Flux to include the new `observability` components.
    ```bash
    flux get kustomizations --all-namespaces
    ```
    Look for the `infra-observability` kustomization (or similar name based on your structure) and verify it's reconciled.

## Step 5: Deploy Observability Components via FluxCD

With the clusters bootstrapped and the foundational Terraform resources applied, FluxCD will now automatically deploy the observability stack based on the `HelmRelease` manifests we've added to the `flux-config` directory.

The deployment happens automatically as FluxCD syncs with your Git repository. The following steps are for verification.

1.  **Verify Central Stack Deployment (`ops` cluster)**:
    Ensure your `kubectl` context is pointing to the `ops` cluster.

    *   **Check Namespaces**: Verify the namespaces for the central components have been created.
        ```bash
        kubectl get ns | grep observability
        # EXPECTED OUTPUT:
        # observability-grafana        Active   ...
        # observability-loki           Active   ...
        # observability-mimir          Active   ...
        # observability-tempo          Active   ...
        ```
    *   **Check HelmReleases**: Verify that FluxCD is deploying the Helm charts.
        ```bash
        flux get helmreleases --all-namespaces
        ```
        You should see releases for `grafana`, `loki`, `mimir`, and `tempo`. Wait for them to become `Ready`.
    *   **Check Pods**: Once the HelmReleases are ready, check that the pods are running.
        ```bash
        kubectl get pods -n observability-grafana
        kubectl get pods -n observability-loki
        kubectl get pods -n observability-mimir
        kubectl get pods -n observability-tempo
        ```

2.  **Verify Agent Deployment (`dev` cluster)**:
    Switch your `kubectl` context to the `dev` cluster.

    *   **Check Namespaces**:
        ```bash
        kubectl get ns | grep observability-agent
        # EXPECTED OUTPUT:
        # observability-agent-prometheus   Active   ...
        # observability-agent-promtail     Active   ...
        ```
    *   **Check HelmReleases**:
        ```bash
        flux get helmreleases --all-namespaces
        ```
        You should see releases for `prometheus-agent` and `promtail`.
    *   **Check Pods**:
        ```bash
        kubectl get pods -n observability-agent-prometheus
        kubectl get pods -n observability-agent-promtail
        ```

3.  **Verify Connectivity (Important)**:
    The agents in the `dev` cluster need to be able to communicate with the services in the `ops` cluster. This relies on:
    *   **VNet Peering**: Assumed to be configured by the Terraform `network` module between the `dev` and `ops` VNets.
    *   **Internal DNS**: The service hostnames (e.g., `mimir.platform-core.internal`, `loki-gateway.observability-loki.svc.cluster.local`) must be resolvable from the `dev` cluster pods. This may require setting up a Private DNS Zone in Azure and linking it to both VNets.
    *   **Check Prometheus Agent Logs**:
        ```bash
        kubectl logs -n observability-agent-prometheus -l app.kubernetes.io/name=prometheus -f
        ```
        Look for successful "remote write" messages. Errors about "server returned HTTP status 400 Bad Request" or DNS resolution failures indicate a connectivity or configuration problem.

## Troubleshooting

- **Remote State Access Error on `dev` plan**: If `terraform plan` for the `dev` environment fails with an error about accessing the remote state, ensure that:
    - You have successfully run `terraform apply` on the `ops-uaenorth` environment first.
    - The `backend.hcl` configuration in `terraform/envs/dev-uaenorth/main.tf` (the `data "terraform_remote_state"` block) points to the correct storage container and key for the `ops` state file.
    - You have permissions to read the storage account where the `ops` state is stored.
- **Flux Bootstrap Fails**:
    - Verify your GitHub PAT (`GITHUB_TOKEN`) is correct and has `repo` scope if you are using it.
    - Ensure the public part of your SSH key (`--private-key-file`) has been added as a Deploy Key to your GitHub repository with read access.
    - Check that the `--path` argument correctly points to an existing directory in your Git repository.
- **Agent Connectivity Issues**: If agents in the `dev` cluster cannot reach services in the `ops` cluster:
    - **DNS Resolution**: From a pod in the `dev` cluster, try to resolve the `ops` service hostname: `kubectl exec -it <some-pod-in-dev> -- nslookup mimir.platform-core.internal`. If it fails, your cross-cluster DNS is not set up correctly. This often requires an Azure Private DNS Zone.
    - **Network Peering**: Ensure VNet peering is active and configured correctly between the two environments' virtual networks in Azure.
    - **NSG Rules**: Check the Network Security Group rules for both the `ops` ingress subnet and the `dev` agent subnets to ensure traffic is allowed on the required ports (e.g., 80, 443).

---

Following these steps will result in a fully deployed central observability stack on the `ops` cluster and the necessary collection agents on your `dev` workload cluster, all managed via GitOps.
