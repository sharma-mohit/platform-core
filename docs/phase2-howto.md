# Phase 2 Implementation Guide

This guide provides step-by-step instructions for implementing Phase 2 of the platform: GitOps & Platform Bootstrap using FluxCD with Kustomize.

## Prerequisites

1. **Phase 1 completed**: AKS clusters, ACR, Key Vault, and networking infrastructure deployed
2. **Terraform state backend** configured and working
3. **AKS clusters accessible** via kubectl
4. **Azure Key Vault** populated with initial secrets
5. **FluxCD CLI** installed locally
6. **GitLab repository** created for GitOps manifests
7. **GitLab Deploy Keys** generated for FluxCD access
8. **GitLab CI/CD runners** configured and accessible
9. **Cloudflare origin certificates** available (optional)

## Directory Structure

```
gitops-bootstrap/
├── clusters/
│   ├── dev-uaenorth/
│   │   ├── flux-system/
│   │   │   ├── gotk-components.yaml
│   │   │   ├── gotk-sync.yaml
│   │   │   └── kustomization.yaml
│   │   ├── infrastructure.yaml
│   │   └── apps.yaml
│   ├── stg-uaenorth/
│   └── prd-uaenorth/
├── infrastructure/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespaces/
│   │   ├── ingress-nginx/
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   ├── loki/
│   │   └── tempo/
│   └── overlays/
│       ├── dev-uaenorth/
│       ├── stg-uaenorth/
│       └── prd-uaenorth/
└── apps/
    ├── base/
    └── overlays/
```

## Implementation Steps

### 1. GitOps Foundation Setup

#### 1.1 Install FluxCD CLI

```bash
# Install FluxCD CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version
```

#### 1.2 Bootstrap FluxCD

1. **Set up GitLab Deploy Keys**:
   ```bash
   # Generate SSH key pair for each environment
   ssh-keygen -t ed25519 -C "fluxcd-deploy-key-dev" -f ~/.ssh/fluxcd-deploy-key-dev
   ssh-keygen -t ed25519 -C "fluxcd-deploy-key-stg" -f ~/.ssh/fluxcd-deploy-key-stg
   ssh-keygen -t ed25519 -C "fluxcd-deploy-key-prd" -f ~/.ssh/fluxcd-deploy-key-prd
   ```

2. **Add Deploy Keys to GitLab**:
   - Go to GitLab Project → Settings → Repository → Deploy Keys
   - Add each public key with read-only access

3. **Store Deploy Keys in Azure Key Vault**:
   ```bash
   # Store private keys in Key Vault
   az keyvault secret set --vault-name kv-platform-dev-uaenorth-001 --name fluxcd-deploy-key-dev --file ~/.ssh/fluxcd-deploy-key-dev
   az keyvault secret set --vault-name kv-platform-stg-uaenorth-001 --name fluxcd-deploy-key-stg --file ~/.ssh/fluxcd-deploy-key-stg
   az keyvault secret set --vault-name kv-platform-prd-uaenorth-001 --name fluxcd-deploy-key-prd --file ~/.ssh/fluxcd-deploy-key-prd
   ```

4. **Bootstrap FluxCD in each environment**:
   ```bash
   # Get AKS credentials
   az aks get-credentials --resource-group rg-aks-dev-uaenorth-001 --name aks-platform-dev-uaenorth-001

   # Bootstrap FluxCD
   flux bootstrap gitlab \
     --owner=your-org \
     --repository=platform-core-gitops \
     --branch=main \
     --path=clusters/dev-uaenorth \
     --deploy-key
   ```

#### 1.3 Create GitRepository and Kustomization Resources

1. **GitRepository resource for GitLab**:
   ```yaml
   # clusters/dev-uaenorth/infrastructure.yaml
   apiVersion: source.toolkit.fluxcd.io/v1beta2
   kind: GitRepository
   metadata:
     name: platform-core-gitops
     namespace: flux-system
   spec:
     interval: 1m
     url: https://gitlab.com/your-org/platform-core-gitops
     ref:
       branch: main
     secretRef:
       name: gitlab-deploy-key
   ---
   apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
   kind: Kustomization
   metadata:
     name: infrastructure
     namespace: flux-system
   spec:
     interval: 10m
     sourceRef:
       kind: GitRepository
       name: platform-core-gitops
     path: "./infrastructure/overlays/dev-uaenorth"
     prune: true
   ```

### 2. Core Platform Services

#### 2.1 NGINX Ingress Controller

1. **Create base configuration**:
   ```yaml
   # infrastructure/base/ingress-nginx/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   resources:
     - namespace.yaml
     - helmrelease.yaml
   ```

2. **Create Helm release**:
   ```yaml
   # infrastructure/base/ingress-nginx/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: ingress-nginx
     namespace: ingress-nginx
   spec:
     interval: 15m
     chart:
       spec:
         chart: ingress-nginx
         version: "4.8.3"
         sourceRef:
           kind: HelmRepository
           name: ingress-nginx
           namespace: flux-system
     values:
       controller:
         service:
           type: LoadBalancer
         config:
           ssl-protocols: "TLSv1.2 TLSv1.3"
   ```

3. **Create environment overlay**:
   ```yaml
   # infrastructure/overlays/dev-uaenorth/ingress-nginx-values.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: ingress-nginx
     namespace: ingress-nginx
   spec:
     values:
       controller:
         service:
           annotations:
             service.beta.kubernetes.io/azure-load-balancer-internal: "false"
   ```

#### 2.2 Certificate Management

1. **Deploy cert-manager**:
   ```yaml
   # infrastructure/base/cert-manager/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: cert-manager
     namespace: cert-manager
   spec:
     interval: 15m
     chart:
       spec:
         chart: cert-manager
         version: "v1.13.2"
         sourceRef:
           kind: HelmRepository
           name: jetstack
           namespace: flux-system
     values:
       installCRDs: true
   ```

2. **Create ClusterIssuer for Cloudflare**:
   ```yaml
   # infrastructure/base/cert-manager/cluster-issuer.yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: cloudflare-origin-issuer
   spec:
     ca:
       secretName: cloudflare-origin-ca-key
   ```

#### 2.3 External Secrets Operator

1. **Deploy ESO**:
   ```yaml
   # infrastructure/base/external-secrets/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: external-secrets
     namespace: external-secrets-system
   spec:
     interval: 15m
     chart:
       spec:
         chart: external-secrets
         version: "0.9.11"
         sourceRef:
           kind: HelmRepository
           name: external-secrets
           namespace: flux-system
   ```

2. **Configure Azure Key Vault SecretStore**:
   ```yaml
   # infrastructure/overlays/dev-uaenorth/secretstore.yaml
   apiVersion: external-secrets.io/v1beta1
   kind: SecretStore
   metadata:
     name: azure-keyvault-store
     namespace: external-secrets-system
   spec:
     provider:
       azurekv:
         vaultUrl: "https://kv-platform-dev-uaenorth-001.vault.azure.net/"
         authType: WorkloadIdentity
   ```

### 3. Observability Stack

#### 3.1 Prometheus Monitoring

1. **Deploy kube-prometheus-stack**:
   ```yaml
   # infrastructure/base/prometheus/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: kube-prometheus-stack
     namespace: monitoring
   spec:
     interval: 15m
     chart:
       spec:
         chart: kube-prometheus-stack
         version: "55.5.0"
         sourceRef:
           kind: HelmRepository
           name: prometheus-community
           namespace: flux-system
     values:
       prometheus:
         prometheusSpec:
           retention: 30d
           storageSpec:
             volumeClaimTemplate:
               spec:
                 storageClassName: managed-csi
                 accessModes: ["ReadWriteOnce"]
                 resources:
                   requests:
                     storage: 50Gi
   ```

#### 3.2 Grafana Dashboards

1. **Configure Grafana**:
   ```yaml
   # infrastructure/overlays/dev-uaenorth/grafana-values.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: kube-prometheus-stack
     namespace: monitoring
   spec:
     values:
       grafana:
         adminPassword: "admin"
         ingress:
           enabled: true
           hosts:
             - grafana-dev.yourdomain.com
   ```

#### 3.3 Loki Log Aggregation

1. **Deploy Loki**:
   ```yaml
   # infrastructure/base/loki/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: loki
     namespace: monitoring
   spec:
     interval: 15m
     chart:
       spec:
         chart: loki
         version: "5.41.4"
         sourceRef:
           kind: HelmRepository
           name: grafana
           namespace: flux-system
   ```

#### 3.4 Tempo Distributed Tracing

1. **Deploy Tempo**:
   ```yaml
   # infrastructure/base/tempo/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2beta1
   kind: HelmRelease
   metadata:
     name: tempo
     namespace: monitoring
   spec:
     interval: 15m
     chart:
       spec:
         chart: tempo
         version: "1.7.1"
         sourceRef:
           kind: HelmRepository
           name: grafana
           namespace: flux-system
   ```

### 4. Deployment

1. **Set Working Directory**:
   ```bash
   # Navigate to your GitOps repository
   cd platform-core-gitops
   ```

2. **Create and commit base configurations**:
   ```bash
   # Create the directory structure and base configurations
   git add infrastructure/
   git commit -m "Add base infrastructure configurations"
   git push origin main
   ```

3. **Create environment overlays**:
   ```bash
   # Create environment-specific overlays
   git add infrastructure/overlays/dev-uaenorth/
   git commit -m "Add dev environment overlay"
   git push origin main
   ```

4. **Verify FluxCD sync**:
   ```bash
   # Check FluxCD status
   flux get all
   
   # Check specific resources
   flux get helmreleases -A
   flux get kustomizations
   ```

### 5. Post-Deployment

1. **Verify deployments**:
   ```bash
   # Check all pods are running
   kubectl get pods -A
   
   # Check ingress controller
   kubectl get svc -n ingress-nginx
   
   # Check monitoring stack
   kubectl get pods -n monitoring
   ```

2. **Access services**:
   ```bash
   # Port-forward to Grafana
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   
   # Access Grafana at http://localhost:3000
   ```

3. **Validate GitOps workflow**:
   ```bash
   # Make a test change and verify sync
   echo "# Test change" >> README.md
   git commit -am "Test GitOps sync"
   git push origin main
   
   # Watch FluxCD reconcile
   flux logs --follow
   ```

## Security Considerations

1. **Access Control**:
- FluxCD service account with minimal required permissions
- Workload Identity for External Secrets Operator
- Network policies for service-to-service communication
- RBAC for Grafana and Prometheus access

2. **Secrets Management**:
- All secrets stored in Azure Key Vault
- No plaintext secrets in Git repositories
- Automatic secret rotation where possible
- Audit logging for secret access

3. **Network Security**:
- Internal ingress for cluster services
- TLS encryption for all communications
- Network policies to restrict pod-to-pod traffic
- Azure Firewall rules for egress filtering

## Troubleshooting

### Common Issues

1. **FluxCD sync failures**:
   - Check GitLab repository access and deploy key permissions
   - Verify Kustomization syntax
   - Review FluxCD controller logs
   - Validate GitLab webhook configuration

2. **GitLab Integration Issues**:
   - Verify GitLab Deploy Key has read access to repository
   - Check GitLab webhook endpoint connectivity
   - Validate GitLab CI/CD pipeline permissions
   - Review GitLab Runner connectivity to AKS clusters

3. **Helm release failures**:
   - Check Helm repository accessibility
   - Verify chart versions and compatibility
   - Review resource quotas and limits
   - Check namespace creation and RBAC

4. **Secret sync failures**:
   - Verify Azure Key Vault permissions
   - Check workload identity configuration
   - Review ESO controller logs
   - Validate SecretStore configuration

### Resolution Steps

1. **Check FluxCD status**:
   ```bash
   flux get all
   flux logs --level=error
   ```

2. **Debug Helm releases**:
   ```bash
   kubectl describe helmrelease <name> -n <namespace>
   kubectl logs -n flux-system deployment/helm-controller
   ```

3. **Validate connectivity**:
   ```bash
   kubectl run test-pod --image=alpine --rm -it -- sh
   # Test DNS resolution and network connectivity
   ```

## Maintenance

1. **Regular Tasks**:
   - Monitor FluxCD reconciliation status
   - Update Helm chart versions
   - Review and rotate secrets
   - Monitor resource usage and scaling

2. **Backup and Recovery**:
   - GitOps repository backup
   - Persistent volume snapshots
   - Configuration backup procedures
   - Disaster recovery testing

## Additional Resources

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [External Secrets Operator](https://external-secrets.io/) 