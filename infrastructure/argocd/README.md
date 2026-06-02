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
│  │  │   GSA: argocd-sa@example-mgmt.iam...            │  │  │
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

## Directory Layout

```
infrastructure/argocd/
├── argocd-values.yaml              # Helm values for `helm install argocd`
├── argocd-virtualservice.yaml      # Istio VS exposing the ArgoCD UI
├── applications/                   # Explicit per-component Applications (mgmt cluster ONLY)
│   ├── elasticvue.yaml             # mgmt — in-repo charts/elasticvue
│   ├── redisinsight.yaml           # mgmt — in-repo charts/redisinsight
│   ├── kafka-ui.yaml               # mgmt — upstream kafbat/kafka-ui (multi-source: chart + $values + manifests)
│   └── nightingale.yaml            # mgmt — in-repo charts/nightingale (values under observability/nightingale/)
├── applicationsets/
│   ├── uat-apps.yaml               # UAT ApplicationSet (auto-sync, scans infrastructure/app/*)
│   └── prod-apps.yaml              # Prod ApplicationSet (manual sync, scans infrastructure/app/*)
├── clusters/                       # Cluster registration secrets (edit placeholders in place)
├── projects/                       # AppProjects per env (edit placeholders in place)
└── notifications/                  # Slack notification ConfigMap + Secret template
```

mgmt values and the kafka-ui VS manifest live under
`../mgmt/<chart>-values.yaml` and `../mgmt/kafka-ui-manifests/` respectively
— shared with the standalone helm fallback so both paths render identically.

### Two routing patterns

ArgoCD topology is split by env type, not unified under one ApplicationSet.

**mgmt cluster** — no ApplicationSet. Each component is wired as an
explicit `applications/<name>.yaml` so it can be sized, scheduled, and
synced independently. Layout per file:

- **Source 1** renders the chart (`charts/<name>` for in-repo charts, or
  the upstream helm repo URL for `kafka-ui`) with two `valueFiles`: the
  chart's own `values.yaml` (defaults) followed by a shared `$values/...`
  file consumed by both ArgoCD and the standalone helm fallback so both
  renders are identical. Path depends on the component:
    - UIs (elasticvue / redisinsight / kafka-ui):
      `$values/infrastructure/mgmt/<name>-values.yaml`
    - nightingale (lives alongside its observability companions):
      `$values/infrastructure/observability/nightingale/nightingale-values.yaml`
  `ignoreMissingValueFiles: false` — the shared values file is required.
- **Source 2** is a `ref: values` pointer to the same repo — it is *not*
  rendered, it only provides the `$values` prefix used by source 1.
- **Source 3** (kafka-ui only) is the raw manifests directory under
  `infrastructure/mgmt/kafka-ui-manifests/` — adds the Istio VS that
  upstream's chart doesn't ship.
- `destination.namespace`: UIs (elasticvue / redisinsight / kafka-ui) share the
  `mgmt` namespace — the kafka-ui VS at
  `infrastructure/mgmt/kafka-ui-manifests/virtualservice.yaml` also pins
  `namespace: mgmt`. nightingale lives in its own `nightingale` namespace
  (matching `infrastructure/observability/nightingale/nightingale-virtualservice.yaml`).

**uat / prod clusters** — `applicationsets/{uat,prod}-apps.yaml` use a
Git directory generator on `infrastructure/app/*` to auto-discover every
example application. Layout per generated Application:

- **Single source**, no `$values` ref. `valueFiles: [values.yaml,
  values-<env>.yaml]` — both colocated under `infrastructure/app/<name>/`.
- `ignoreMissingValueFiles: false` — each app **must** ship a
  `values-uat.yaml` and `values-prod.yaml`. New apps fail loudly until
  both env override files exist.
- `destination.namespace: "{{ .path.basename }}"` — namespace is the chart
  directory name (e.g. `infrastructure/app/nginx` → namespace `nginx`),
  symmetric with the mgmt Applications. Auto-created via
  `CreateNamespace=true`.

`infrastructure/app/common` is excluded from the directory generator
because it's a Helm *library chart* (`type: library`).

**Where each component lands:**

| Component            | Mgmt | UAT | Prod | Source                                       | Notes                                                                                                                       |
| -------------------- | :--: | :-: | :--: | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `elasticvue`         | yes  |     |      | `charts/elasticvue`                          | Mgmt-tier UI. Namespace `mgmt`.                                                                                             |
| `redisinsight`       | yes  |     |      | `charts/redisinsight`                        | Mgmt-tier UI. Namespace `mgmt`.                                                                                             |
| `kafka-ui`           | yes  |     |      | upstream `kafbat/kafka-ui`                   | Multi-cluster bootstrap servers — monitors kafka across mgmt/uat/prod from one instance. Namespace `mgmt`.                  |
| `nightingale`        | yes  |     |      | `charts/nightingale`                         | Shared monitoring stack. Namespace `nightingale`; values at `infrastructure/observability/nightingale/nightingale-values.yaml`. |
| `nginx` (example)    |      | yes | yes  | `infrastructure/app/nginx`                   | Front-end example app — DHI hardened nginx image.                                                                           |
| `alpine` (example)   |      | yes | yes  | `infrastructure/app/alpine`                  | Back-end example app — BusyBox `nc` httpd loop.                                                                             |
| `common` (library)   |      |     |      | both `charts/common` and `infrastructure/app/common` | Library charts (`type: library`) — never deployed as standalone Applications.                                       |
| `rocketmq-exporter`  |      |     |      | `charts/rocketmq-exporter`                   | Published to the registry; not ArgoCD-deployed (standalone-only via `infrastructure/mgmt/rocketmq-exporter-values.yaml`).   |

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
gcloud iam service-accounts create argocd-sa \
  --display-name="ArgoCD Multi-Cluster Access" \
  --project=example-mgmt

# 2. Grant GKE access to each target project
# UAT cluster
gcloud projects add-iam-policy-binding example-uat \
  --member="serviceAccount:argocd-sa@example-mgmt.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Prod cluster
gcloud projects add-iam-policy-binding example-prod \
  --member="serviceAccount:argocd-sa@example-mgmt.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# 3. Bind ArgoCD KSA to GSA via Workload Identity
# IMPORTANT: Use the Mgmt cluster's WI pool (example-mgmt.svc.id.goog)
gcloud iam service-accounts add-iam-policy-binding \
  argocd-sa@example-mgmt.iam.gserviceaccount.com \
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

### Step 5: Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  -n argocd \
  -f argocd-values.yaml \
  --version 9.3.5
```

This creates the credential template secret (`argocd-repo-creds-github`) with `url` and `username`, and the repository secret (`argocd-repo-devops-tools`). The credential template still needs the GitHub PAT — see next step.

### Step 6: Patch GitHub PAT into Credential Template

Helm intentionally does not include the PAT in `argocd-values.yaml` to avoid storing secrets in Git. Patch it manually after install (or upgrade):

```bash
kubectl patch secret argocd-repo-creds-github -n argocd \
  --type merge -p "{\"stringData\":{\"password\":\"<GITHUB_PAT>\"}}"
```

Verify the repo connection:

```bash
argocd repo list
# STATUS should be "Successful"
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

Fill in the placeholders in the cluster secrets and apply:

```bash
# Edit the files to replace placeholders:
#   <UAT_CLUSTER_ENDPOINT>        - UAT cluster API endpoint
#   <UAT_CLUSTER_CA_CERT_BASE64>  - UAT cluster CA certificate (base64)
#   <PROD_CLUSTER_ENDPOINT>       - Prod cluster API endpoint
#   <PROD_CLUSTER_CA_CERT_BASE64> - Prod cluster CA certificate (base64)
$EDITOR clusters/uat-cluster-secret.yaml clusters/prod-cluster-secret.yaml

# The mgmt-cluster-secret has no placeholders — it points at the in-cluster
# Kubernetes API (`https://kubernetes.default.svc`) and uses the controller's
# own ServiceAccount token. Apply it as-is.
kubectl apply -f clusters/
```

### Step 10: Create Projects

Fill in the placeholders in the AppProject definitions and apply:

```bash
# Edit the files to replace placeholders:
#   <YOUR_ORG>  - Your GitHub organization
#   <YOUR_REPO> - Your repository name
$EDITOR projects/mgmt-project.yaml projects/uat-project.yaml projects/prod-project.yaml

kubectl apply -f projects/
```

### Step 11: Create mgmt Applications and uat/prod ApplicationSets

**mgmt** uses explicit per-component Application manifests under `applications/`
— one file per workload. Each consumes its values via a multi-source `$values`
ref pointing at `infrastructure/mgmt/<name>-values.yaml` — the **same** file
used by the standalone helm fallback in `infrastructure/mgmt/README.md`, so
ArgoCD-managed and standalone renders are identical (`ignoreMissingValueFiles: false`).

**uat / prod** use ApplicationSet directory generators on `infrastructure/app/*`.
Each generated Application is single-source with colocated `valueFiles:
[values.yaml, values-<env>.yaml]` both under `infrastructure/app/<name>/`.
`ignoreMissingValueFiles: false` — each example app **must** ship a
`values-uat.yaml` and `values-prod.yaml`.

```bash
# 1) Edit placeholders in mgmt Applications:
#    <YOUR_ORG>  - Your GitHub organization
#    <YOUR_REPO> - Your repository name
# UIs land in the shared `mgmt` namespace; nightingale lands in `nightingale`.
$EDITOR applications/elasticvue.yaml \
        applications/redisinsight.yaml \
        applications/kafka-ui.yaml \
        applications/nightingale.yaml

# 2) Edit the shared values files + the kafka-ui VS:
$EDITOR ../mgmt/elasticvue-values.yaml \
        ../mgmt/redisinsight-values.yaml \
        ../mgmt/kafka-ui-values.yaml \
        ../mgmt/kafka-ui-manifests/virtualservice.yaml \
        ../observability/nightingale/nightingale-values.yaml

# 3) Apply mgmt Applications:
kubectl apply -f applications/

# 4) Edit placeholders in the uat/prod ApplicationSets:
#    <YOUR_ORG>  - Your GitHub organization
#    <YOUR_REPO> - Your repository name
# Note: each example app lands in a namespace named after its chart
# directory (e.g. `infrastructure/app/nginx` -> namespace `nginx`),
# auto-derived via `{{ .path.basename }}` — no namespace placeholder.
$EDITOR applicationsets/uat-apps.yaml applicationsets/prod-apps.yaml

# 5) Apply the ApplicationSets:
kubectl apply -f applicationsets/
```

> **Adding a new mgmt-tier component:** copy one of the existing
> `applications/<name>.yaml` files (e.g. `elasticvue.yaml`), adjust
> `metadata.name` and `path`. Default to `destination.namespace: mgmt`
> for UIs; components that warrant their own namespace (large stateful
> apps, observability stacks, etc.) set their own — see `nightingale.yaml`
> for the pattern. Drop a values file in the matching subtree
> (`infrastructure/mgmt/<name>-values.yaml` for UIs;
> `infrastructure/observability/<stack>/<name>-values.yaml` for
> observability stacks) — the same file is consumed by the standalone
> helm fallback documented in the adjacent README.
>
> **Adding a new uat/prod example app:** create
> `infrastructure/app/<name>/` with its own `Chart.yaml`,
> `values.yaml`, `values-uat.yaml`, `values-prod.yaml`, and standard
> templates (delegating to `infrastructure/app/common` via
> `file://../common`). The directory generator picks it up automatically.
>
> **Why `common` is excluded from the generator:** both
> `charts/common` and `infrastructure/app/common` are Helm *library
> charts* (`type: library`) — they have no installable resources and
> would fail to sync as a standalone Application. The uat/prod
> ApplicationSets carry an `exclude: true` rule for
> `infrastructure/app/common`.

### Step 12: Apply Notifications (Optional)

```bash
# Fill in the Slack webhook URL in the secret template, then apply:
cp notifications/secret.yaml.template notifications/secret.yaml
$EDITOR notifications/secret.yaml          # paste the Slack webhook URL

kubectl apply -f notifications/configmap.yaml
kubectl apply -f notifications/secret.yaml
```

---

## Account Management

### Default Accounts

| Account  | Capabilities | Role            | Description                       |
| -------- | ------------ | --------------- | --------------------------------- |
| `admin`  | login        | `role:admin`    | Full access to all resources      |
| `viewer` | login        | `role:readonly` | Read-only access (no sync/delete) |

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

Update `argocd-values.yaml`:

```yaml
configs:
  cm:
    accounts.newuser: login

  rbac:
    policy.csv: |
      # ... existing policies ...
      g, newuser, role:readonly
```

Then upgrade and set password:

```bash
helm upgrade argocd argo/argo-cd -n argocd -f argocd-values.yaml
argocd account update-password --account newuser --grpc-web
```

### RBAC Roles

Two layers of bindings are OR-merged at evaluation time:

**Global RBAC** (`argocd-values.yaml` → `configs.rbac`):

| Role / Binding                  | Source           | Effect                                          |
| ------------------------------- | ---------------- | ----------------------------------------------- |
| `policy.default: role:readonly` | global           | Authenticated users get universal `get`         |
| `g, devops-team, role:admin`    | global           | DevOps team is superuser across all projects    |
| `g, viewer, role:readonly`      | global           | Local `viewer` account → built-in `role:readonly` |

Built-in roles (`role:admin`, `role:readonly`) come from the chart and must
**not** be redefined.

**Project-scoped RBAC** (`AppProject.spec.roles`) — only adds *extra* grants on
top of the global layer:

| Project        | Role        | Group              | Adds                                           |
| -------------- | ----------- | ------------------ | ---------------------------------------------- |
| `example-mgmt` | —           | —                  | No project-scoped roles (ops-only)             |
| `example-uat`  | `developer` | `developer-team`   | `applications, sync` on `example-uat/*` apps   |
| `example-prod` | —           | —                  | No project-scoped roles (see below)            |

> `example-mgmt` deliberately has no project-scoped roles: it holds shared
> infrastructure components (the mgmt UIs — elasticvue, redisinsight,
> kafka-ui) that only devops-team should manage. devops-team is already
> global admin via the layer above.
>
> `example-prod` deliberately has no project-scoped roles: devops-team is
> already global admin, developer-team is already global readonly, and Prod
> sync is intentionally not delegated to developers — it stays a devops-team
> action, matching the ApplicationSet's auto-sync=disabled posture.

---

## Project Configuration

### Orphaned Resources

Projects are configured to warn about orphaned resources while ignoring known shared resources.

#### Ignored Resources

| Resource Type  | Name Pattern             | Reason                            |
| -------------- | ------------------------ | --------------------------------- |
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
  argocd-sa@example-mgmt.iam.gserviceaccount.com \
  --project=example-mgmt
```

---

## Upgrading ArgoCD

```bash
helm upgrade argocd argo/argo-cd \
  -n argocd \
  -f argocd-values.yaml
```

---

## Uninstallation

```bash
# Delete mgmt Applications and uat/prod ApplicationSets first
kubectl delete -f applications/
kubectl delete -f applicationsets/

# Uninstall ArgoCD
helm uninstall argocd -n argocd

# Delete namespace
kubectl delete namespace argocd
```

---

## Related Files

| Path                                        | Description                                              |
| ------------------------------------------- | -------------------------------------------------------- |
| `argocd-values.yaml`                        | Helm values for ArgoCD installation                      |
| `argocd-virtualservice.yaml`                | Istio VirtualService exposing the ArgoCD UI              |
| `clusters/mgmt-cluster-secret.yaml`         | Mgmt cluster registration (in-cluster, no placeholders)  |
| `clusters/uat-cluster-secret.yaml`          | UAT cluster connection secret (fill in placeholders)     |
| `clusters/prod-cluster-secret.yaml`         | Prod cluster connection secret (fill in placeholders)    |
| `projects/mgmt-project.yaml`                | Mgmt AppProject definition (fill in placeholders)        |
| `projects/uat-project.yaml`                 | UAT AppProject definition (fill in placeholders)         |
| `projects/prod-project.yaml`                | Prod AppProject definition (fill in placeholders)        |
| `applications/elasticvue.yaml`              | Mgmt Application — in-repo charts/elasticvue             |
| `applications/redisinsight.yaml`            | Mgmt Application — in-repo charts/redisinsight           |
| `applications/kafka-ui.yaml`                | Mgmt Application — upstream kafbat/kafka-ui              |
| `applications/nightingale.yaml`             | Mgmt Application — in-repo charts/nightingale (ns `nightingale`) |
| `applicationsets/uat-apps.yaml`             | UAT ApplicationSet (auto-sync, scans infrastructure/app/*) |
| `applicationsets/prod-apps.yaml`            | Prod ApplicationSet (manual sync, scans infrastructure/app/*) |
| `../mgmt/<chart>-values.yaml`               | Mgmt UI values — shared by ArgoCD Applications and standalone helm fallback |
| `../mgmt/kafka-ui-manifests/`               | Raw Istio VS manifest — rendered by kafka-ui Application + applied standalone |
| `../observability/nightingale/nightingale-values.yaml` | Nightingale values — shared by the nightingale Application and the observability standalone helm path |
| `notifications/configmap.yaml`              | Slack notification triggers / templates                  |
| `notifications/secret.yaml.template`        | Slack webhook secret template                            |

### Placeholders Reference

| Placeholder                     | Description                           | How to Get                                                                                    |
| ------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------- |
| `<YOUR_ORG>`                    | GitHub organization name              | Your org name (e.g., `example-org`)                                                           |
| `<YOUR_REPO>`                   | Repository name                       | Your repo name (e.g., `devops-tools`)                                                         |
| `<REGION>`                      | GCP region                            | e.g., `asia-southeast1`                                                                       |
| `<UAT_CLUSTER_NAME>`            | UAT GKE cluster name                  | `gcloud container clusters list --project=example-uat`                                        |
| `<PROD_CLUSTER_NAME>`           | Prod GKE cluster name                 | `gcloud container clusters list --project=example-prod`                                       |
| `<UAT_CLUSTER_ENDPOINT>`        | UAT cluster API server IP             | `gcloud container clusters describe <name> --format='value(endpoint)'`                        |
| `<PROD_CLUSTER_ENDPOINT>`       | Prod cluster API server IP            | `gcloud container clusters describe <name> --format='value(endpoint)'`                        |
| `<UAT_CLUSTER_CA_CERT_BASE64>`  | UAT cluster CA certificate (base64)   | `gcloud container clusters describe <name> --format='value(masterAuth.clusterCaCertificate)'` |
| `<PROD_CLUSTER_CA_CERT_BASE64>` | Prod cluster CA certificate (base64)  | `gcloud container clusters describe <name> --format='value(masterAuth.clusterCaCertificate)'` |
| `<GITHUB_PAT>`                  | GitHub Personal Access Token          | Create at GitHub Settings > Developer settings > Personal access tokens                       |
| `<ARGOCD_DOMAIN>`               | ArgoCD UI domain                      | e.g., `argocd.example.com`                                                                    |
