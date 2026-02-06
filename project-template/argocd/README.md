# ArgoCD Installation Guide

This guide covers the installation and configuration of ArgoCD for multi-cluster GitOps CD pipeline using a dedicated Mgmt cluster.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GCP Project: example-mgmt                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                      Mgmt GKE Cluster                              │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                 ArgoCD (argocd namespace)                    │  │  │
│  │  │   - argocd-server (UI/API)                                  │  │  │
│  │  │   - argocd-repo-server (Git clone & Helm render)            │  │  │
│  │  │   - argocd-application-controller (Sync & Health)           │  │  │
│  │  │   - argocd-notifications-controller (Slack notifications)   │  │  │
│  │  │                                                              │  │  │
│  │  │   KSA: argocd-application-controller                        │  │  │
│  │  │   ↓ Workload Identity                                       │  │  │
│  │  │   GSA: argocd-cluster-access@example-mgmt.iam...            │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
        ┌───────────────────┐           ┌───────────────────┐
        │ GCP: example-uat  │           │ GCP: example-prod │
        │ ┌───────────────┐ │           │ ┌───────────────┐ │
        │ │  UAT Cluster  │ │           │ │ Prod Cluster  │ │
        │ └───────────────┘ │           │ └───────────────┘ │
        └───────────────────┘           └───────────────────┘
```

## Prerequisites

- GKE Mgmt cluster (`example-mgmt` project) with `kubectl` configured
- GKE UAT cluster (`example-uat` project)
- GKE Prod cluster (`example-prod` project)
- Helm 3.x installed
- Istio service mesh deployed on Mgmt cluster (optional, for ingress)
- GitHub Personal Access Token (PAT) with repo access
- Slack Incoming Webhook URL (optional, for notifications)

---

## Installation Steps

### Step 1: Configure GKE Workload Identity (Mgmt Cluster)

ArgoCD uses Workload Identity to authenticate to remote GKE clusters. This requires WI enabled on the **Mgmt cluster** where ArgoCD runs.

```bash
# 1. Enable Workload Identity on Mgmt cluster
gcloud container clusters update mgmt-gke \
  --region=<REGION> \
  --project=example-mgmt \
  --workload-pool=example-mgmt.svc.id.goog

# 2. Enable GKE_METADATA on the node pool where ArgoCD runs
gcloud container node-pools update mgmt-pool \
  --cluster=mgmt-gke \
  --region=<REGION> \
  --project=example-mgmt \
  --workload-metadata=GKE_METADATA
```

### Step 2: Create GCP Service Account and IAM Bindings

Create a central GSA in the Mgmt project that has access to all target clusters.

```bash
# 1. Create GSA for ArgoCD cluster access (in Mgmt project)
gcloud iam service-accounts create argocd-cluster-access \
  --display-name="ArgoCD Multi-Cluster Access" \
  --project=example-mgmt

# 2. Grant GKE access to each target project
# UAT cluster
gcloud projects add-iam-policy-binding example-uat \
  --member="serviceAccount:argocd-cluster-access@example-mgmt.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Prod cluster
gcloud projects add-iam-policy-binding example-prod \
  --member="serviceAccount:argocd-cluster-access@example-mgmt.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# 3. Bind ArgoCD KSA to GSA via Workload Identity
# IMPORTANT: Use the Mgmt cluster's WI pool (example-mgmt.svc.id.goog)
gcloud iam service-accounts add-iam-policy-binding \
  argocd-cluster-access@example-mgmt.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:example-mgmt.svc.id.goog[argocd/argocd-application-controller]" \
  --project=example-mgmt
```

### Step 3: Add Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### Step 4: Create Namespace

```bash
kubectl create namespace argocd
```

### Step 5: Create GitHub Credentials Secret

```bash
kubectl create secret generic argocd-repo-creds-github \
  --from-literal=url=https://github.com/<YOUR_ORG> \
  --from-literal=username=git \
  --from-literal=password=<GITHUB_PAT> \
  -n argocd

kubectl label secret argocd-repo-creds-github \
  argocd.argoproj.io/secret-type=repo-creds \
  -n argocd
```

### Step 6: Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  -n argocd \
  -f values-argocd.yaml \
  --version 9.3.5
```

### Step 7: Wait for ArgoCD to be Ready

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-applicationset-controller -n argocd --timeout=300s
```

### Step 8: Get Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 9: Create Cluster Secrets

Get cluster information for each target cluster:

```bash
# Get UAT cluster endpoint and CA cert
gcloud container clusters describe <UAT_CLUSTER_NAME> \
  --region=<REGION> \
  --project=example-uat \
  --format='value(endpoint)'

gcloud container clusters describe <UAT_CLUSTER_NAME> \
  --region=<REGION> \
  --project=example-uat \
  --format='value(masterAuth.clusterCaCertificate)'

# Get Prod cluster endpoint and CA cert
gcloud container clusters describe <PROD_CLUSTER_NAME> \
  --region=<REGION> \
  --project=example-prod \
  --format='value(endpoint)'

gcloud container clusters describe <PROD_CLUSTER_NAME> \
  --region=<REGION> \
  --project=example-prod \
  --format='value(masterAuth.clusterCaCertificate)'
```

Copy the example files and fill in the values:

```bash
cp ../clusters/uat-cluster-secret.yaml.example ../clusters/uat-cluster-secret.yaml
cp ../clusters/prod-cluster-secret.yaml.example ../clusters/prod-cluster-secret.yaml

# Edit the files to replace placeholders:
#   <UAT_CLUSTER_ENDPOINT>     - UAT cluster API endpoint
#   <UAT_CLUSTER_CA_CERT_BASE64> - UAT cluster CA certificate (base64)
#   <PROD_CLUSTER_ENDPOINT>    - Prod cluster API endpoint
#   <PROD_CLUSTER_CA_CERT_BASE64> - Prod cluster CA certificate (base64)

kubectl apply -f ../clusters/
```

### Step 10: Create Projects

Copy the example files and configure for your environment:

```bash
cp ../projects/uat-project.yaml.example ../projects/uat-project.yaml
cp ../projects/prod-project.yaml.example ../projects/prod-project.yaml

# Edit the files to replace placeholders:
#   <YOUR_ORG>  - Your GitHub organization
#   <YOUR_REPO> - Your repository name

kubectl apply -f ../projects/
```

### Step 11: Create ApplicationSets

Copy the example files and configure for your environment:

```bash
cp ../applicationsets/uat-apps.yaml.example ../applicationsets/uat-apps.yaml
cp ../applicationsets/prod-apps.yaml.example ../applicationsets/prod-apps.yaml

# Edit the files to replace placeholders:
#   <YOUR_ORG>         - Your GitHub organization
#   <YOUR_REPO>        - Your repository name
#   <HELM_CHARTS_PATH> - Path to helm charts in repo (e.g., helm-charts)
#   <TARGET_NAMESPACE> - Kubernetes namespace for apps (e.g., default)

kubectl apply -f ../applicationsets/
```

### Step 12: Apply Notifications (Optional)

```bash
kubectl apply -f ../notifications/
```

---

## Account Management

### Default Accounts

| Account  | Capabilities | Role          | Description                       |
| -------- | ------------ | ------------- | --------------------------------- |
| `admin`  | login        | `role:admin`  | Full access to all resources      |
| `viewer` | login        | `role:viewer` | Read-only access (no sync/delete) |

### Creating the Viewer Account Password

After installation, set the password for the `viewer` account:

```bash
# Using kubectl with initial admin secret
argocd account update-password --account viewer \
  --new-password '<new-password>' \
  --current-password "$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)" \
  --grpc-web
```

### Adding New Local Accounts

Update `values-argocd.yaml`:

```yaml
configs:
  cm:
    accounts.newuser: login

  rbac:
    policy.csv: |
      # ... existing policies ...
      g, newuser, role:viewer
```

Then upgrade and set password:

```bash
helm upgrade argocd argo/argo-cd -n argocd -f values-argocd.yaml
argocd account update-password --account newuser --grpc-web
```

### RBAC Roles

| Role            | Permissions                                        |
| --------------- | -------------------------------------------------- |
| `role:admin`    | Full access to all resources                       |
| `role:viewer`   | View applications, logs, projects (no sync/delete) |
| `role:readonly` | View applications only (default role)              |

---

## Project Configuration

### Project Roles

#### example-uat

| Role    | Group            | Permissions                      |
| ------- | ---------------- | -------------------------------- |
| `admin` | `devops-team`    | Full access (sync, delete, etc.) |
| `dev`   | `developer-team` | View, Sync, Logs                 |

#### example-prod

| Role    | Group            | Permissions                      |
| ------- | ---------------- | -------------------------------- |
| `admin` | `devops-team`    | Full access (sync, delete, etc.) |
| `dev`   | `developer-team` | View, Logs only (no sync)        |

### Orphaned Resources

Projects are configured to warn about orphaned resources while ignoring known shared resources.

#### Ignored Resources

| Resource Type  | Name Pattern             | Reason                            |
| -------------- | ------------------------ | --------------------------------- |
| ConfigMap      | `global-*`               | Global Helm chart shared configs  |
| ConfigMap      | `istio-ca-*`             | Istio auto-generated certificates |
| Secret         | `github-registry-secret` | Manually managed pull secret      |
| ServiceAccount | `app`                    | Manually managed SA               |

---

## ArgoCD CLI Reference

### Login

```bash
argocd login <ARGOCD_DOMAIN> --grpc-web
argocd login <ARGOCD_DOMAIN> --username admin --password <password> --grpc-web
```

### Application Management

```bash
# List all applications
argocd app list --grpc-web

# List by environment
argocd app list --grpc-web -l environment=uat
argocd app list --grpc-web -l environment=prod

# Get application details
argocd app get <app-name> --grpc-web

# Sync an application
argocd app sync <app-name> --grpc-web

# Force sync
argocd app sync <app-name> --force --grpc-web

# Hard refresh
argocd app get <app-name> --hard-refresh --grpc-web

# View orphaned resources
argocd app resources <app-name> --orphaned --grpc-web
```

### Project Management

```bash
argocd proj list --grpc-web
argocd proj get <project-name> --grpc-web
argocd proj role list <project-name> --grpc-web
```

### Account Management

```bash
argocd account list --grpc-web
argocd account get-user-info --grpc-web
argocd account update-password --grpc-web
argocd account update-password --account <account-name> --grpc-web
```

### Cluster Management

```bash
argocd cluster list --grpc-web
argocd cluster get <cluster-name> --grpc-web
```

---

## Troubleshooting

### Check ArgoCD Logs

```bash
kubectl logs -f deployment/argocd-server -n argocd
kubectl logs -f deployment/argocd-application-controller -n argocd
kubectl logs -f deployment/argocd-repo-server -n argocd
```

### Reset Admin Password

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
kubectl rollout restart deployment/argocd-server -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Orphaned Resource Warnings

```bash
# Check orphaned resources
argocd app resources <app-name> --orphaned --grpc-web

# Solutions:
# 1. Add ignore rules to Project orphanedResources.ignore
# 2. Delete orphaned resources if no longer needed
# 3. Sync applications to have ArgoCD take ownership
```

### Application Stuck in Sync

```bash
argocd app terminate-op <app-name> --grpc-web
argocd app sync <app-name> --grpc-web
```

### Workload Identity Issues

```bash
# Verify KSA annotation
kubectl get sa argocd-application-controller -n argocd -o yaml | grep -A1 annotations

# Test GCP authentication from controller pod
kubectl exec -it deployment/argocd-application-controller -n argocd -- \
  gcloud auth list

# Check IAM bindings
gcloud iam service-accounts get-iam-policy \
  argocd-cluster-access@example-mgmt.iam.gserviceaccount.com \
  --project=example-mgmt
```

---

## Upgrading ArgoCD

```bash
helm upgrade argocd argo/argo-cd \
  -n argocd \
  -f values-argocd.yaml
```

---

## Uninstallation

```bash
# Delete ApplicationSets first
kubectl delete -f ../applicationsets/

# Uninstall ArgoCD
helm uninstall argocd -n argocd

# Delete namespace
kubectl delete namespace argocd
```

---

## Related Files

| Path                                              | Description                           |
| ------------------------------------------------- | ------------------------------------- |
| `values-argocd.yaml`                              | Helm values for ArgoCD installation   |
| `../clusters/uat-cluster-secret.yaml.example`     | UAT cluster connection template       |
| `../clusters/prod-cluster-secret.yaml.example`    | Prod cluster connection template      |
| `../projects/uat-project.yaml.example`            | UAT project definition template       |
| `../projects/prod-project.yaml.example`           | Prod project definition template      |
| `../applicationsets/uat-apps.yaml.example`        | UAT ApplicationSet template           |
| `../applicationsets/prod-apps.yaml.example`       | Prod ApplicationSet template          |
| `../notifications/`                               | Slack notification configuration      |
| `../istio/`                                       | Istio VirtualService for UI access    |

### Placeholders Reference

| Placeholder                      | Description                                    | How to Get                                                                         |
| -------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------- |
| `<YOUR_ORG>`                     | GitHub organization name                       | Your org name (e.g., `example-org`)                                                |
| `<YOUR_REPO>`                    | Repository name                                | Your repo name (e.g., `devops-tools`)                                              |
| `<REGION>`                       | GCP region                                     | e.g., `asia-southeast1`                                                            |
| `<UAT_CLUSTER_NAME>`             | UAT GKE cluster name                           | `gcloud container clusters list --project=example-uat`                             |
| `<PROD_CLUSTER_NAME>`            | Prod GKE cluster name                          | `gcloud container clusters list --project=example-prod`                            |
| `<UAT_CLUSTER_ENDPOINT>`         | UAT cluster API server IP                      | `gcloud container clusters describe <name> --format='value(endpoint)'`             |
| `<PROD_CLUSTER_ENDPOINT>`        | Prod cluster API server IP                     | `gcloud container clusters describe <name> --format='value(endpoint)'`             |
| `<UAT_CLUSTER_CA_CERT_BASE64>`   | UAT cluster CA certificate (base64)            | `gcloud container clusters describe <name> --format='value(masterAuth.clusterCaCertificate)'` |
| `<PROD_CLUSTER_CA_CERT_BASE64>`  | Prod cluster CA certificate (base64)           | `gcloud container clusters describe <name> --format='value(masterAuth.clusterCaCertificate)'` |
| `<HELM_CHARTS_PATH>`             | Path to helm charts in repo                    | e.g., `helm-charts` or `charts`                                                    |
| `<TARGET_NAMESPACE>`             | Kubernetes namespace for applications          | e.g., `default`, `apps`, `example`                                                 |
| `<GITHUB_PAT>`                   | GitHub Personal Access Token                   | Create at GitHub Settings > Developer settings > Personal access tokens            |
| `<ARGOCD_DOMAIN>`                | ArgoCD UI domain                               | e.g., `argocd.example.com`                                                         |
