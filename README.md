[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-repo-blue)](https://artifacthub.io/) [![Release Charts](https://github.com/logic3579/helm-charts/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/logic3579/helm-charts/actions/workflows/release.yml)

## Repository Overview

This repo provides two things:

1. **Publishable Helm charts** in [`charts/`](./charts/) — released via GitHub Pages
2. **Quickstart examples** in `*-example/` directories — ready-to-use templates for Kustomize or Helm app deployment, plus infrastructure reference configs

## Available Charts

| Chart | Description | Default Port |
|-------|-------------|-------------|
| [common](./charts/common) | Shared library chart (labels, VirtualService, PDB) | — |
| [go-app](./charts/go-app) | Generic chart for Go application deployment | 8080 |
| [python-app](./charts/python-app) | Generic chart for Python application deployment (FastAPI, Django, Flask) | 8000 |
| [frontend-app](./charts/frontend-app) | Generic chart for frontend application deployment (nginx-based SPA) | 80 |

## Quickstart Examples

Choose your app deployment tool when setting up a new K8S cluster:

| Path | Description |
|------|-------------|
| [kustomize-example/](./kustomize-example/) | Kustomize base/components/overlays template — `kubectl apply -k` |
| [helm-example/](./helm-example/) | Helm values examples using the charts above — `helm install` |
| [infrastructure-example/](./infrastructure-example/) | Cluster infrastructure configs (ArgoCD, Istio, monitoring, etc.) |

## Usage

### Install from Helm repo

```bash
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm repo update
helm search repo logic-charts

# Install a chart
helm install my-go-app logic-charts/go-app -f my-values.yaml
```

### Build and publish charts

```bash
helm lint charts/*
helm package charts/*
helm repo index ./charts --url https://logic3579.github.io/helm-charts
```

### Use quickstart examples

```bash
# Kustomize
kustomize build kustomize-example/overlays/dev
kubectl apply -k kustomize-example/overlays/dev

# Helm
helm dependency update charts/go-app
helm install backend charts/go-app -f helm-example/backend-example/values.yaml
```

### GitLab Package registry

```bash
helm plugin install https://github.com/chartmuseum/helm-push
helm repo add --username <username> --password <access_token> my-repo \
  https://gitlab.example.com/api/v4/projects/<project_id>/packages/helm/stable
helm cm-push go-app-0.1.0.tgz my-repo
```
