# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Helm charts repository that serves two purposes:

1. **Publishable Helm charts** in `charts/` — released via GitHub Pages using `helm/chart-releaser-action`
2. **Infrastructure examples** in `infrastructure-example/` — cluster infrastructure reference configs

The repo is hosted at `https://logic3579.github.io/helm-charts` as a Helm chart repository.

## Common Commands

```bash
# Lint all charts
helm lint charts/*

# Update chart dependencies (required after modifying Chart.yaml dependencies)
helm dependency update charts/go-app

# Template a chart locally to inspect rendered output
helm template my-release charts/go-app -f charts/go-app/values.yaml

# Install from Helm registry
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm install my-go-app logic-charts/go-app -f my-values.yaml
```

## Architecture

### charts/

- **common** — Shared Helm library chart (`type: library`) providing reusable named templates: labels, helpers, VirtualService, PodDisruptionBudget. All app charts depend on this via `dependencies` using `file://../common`. Not published to the registry — it is embedded into each app chart's `.tgz` during packaging
- **go-app** — Generic deployment chart for Go applications (port 8080, /healthz + /readyz probes, minimal resource footprint)
- **python-app** — Generic deployment chart for Python applications (port 8000, /health probes, higher memory defaults for Python runtimes)
- **frontend-app** — Generic deployment chart for compiled frontend apps served by nginx (port 80, optional custom nginx config, lightweight resources)

Each chart has a single `values.yaml` that serves as both the default values and the configuration reference. Deployment-specific overrides (image repo, resources, env vars, etc.) should be provided via ArgoCD Application `values` or `helm install -f`.

### infrastructure-example/

Cluster infrastructure reference configs:

- **argocd/** — Multi-cluster GitOps setup with ApplicationSets, cluster secrets, projects, notifications (GKE Workload Identity)
- **istio/** — Gateway and AuthorizationPolicy configs for external/internal traffic
- **monitoring/** — Nightingale (n9e) + Categraf + Grafana dashboards and alert rules
- **cert-manager/, database/, bigdata/, logging/, streaming/, mgmt/** — Various infrastructure component manifests

## Dual Deployment Model

The `charts/` directory supports two deployment methods simultaneously:

1. **Helm Registry** — Charts are packaged, released to GitHub Releases, and indexed on GitHub Pages. Users install via `helm repo add` / `helm install`
2. **ArgoCD Directory** — ArgoCD points directly to a chart path in this Git repo (e.g., `charts/go-app`) with `source.helm` type. ArgoCD auto-runs `helm dependency build` to resolve the `file://../common` dependency

## CI/CD — Release Workflow

The GitHub Actions workflow (`.github/workflows/release.yml`) automates chart publishing.

### Trigger

- **Auto**: Push to `main` that modifies `charts/**`
- **Manual**: `workflow_dispatch`

### How to publish a new chart version

1. Modify chart source under `charts/`
2. **Bump `version` in `Chart.yaml`** — this is the release trigger; chart-releaser skips versions that already have a corresponding Git tag
3. `git commit && git push origin main`

### Workflow steps

```
checkout (fetch-depth: 0, full history + tags for chart-releaser)
    ↓
helm dependency update (resolve file://../common for each app chart)
    ↓
helm lint (validate all charts)
    ↓
helm package (only type: application charts → .cr-release-packages/)
    ↓
chart-releaser-action (skip_packaging: true):
  a. cr upload — create GitHub Release per new version, .tgz as asset
  b. cr index  — regenerate index.yaml, push to gh-pages branch
    ↓
Prepare Pages (index.html from main + index.yaml from gh-pages → ./public/)
    ↓
Deploy to GitHub Pages (serves both index.html and index.yaml)
```

### Key branches

- **main** — Chart source code, workflow, docs
- **gh-pages** — Managed by chart-releaser; stores `index.yaml` only. Do not manually edit

### How users install

```
helm repo add logic-charts https://logic3579.github.io/helm-charts
  → fetches /index.yaml from GitHub Pages
helm install my-app logic-charts/go-app
  → downloads .tgz from GitHub Releases (URL recorded in index.yaml)
```

## Conventions

- Template files use `.example` suffix for configs requiring secret/environment-specific values
- ArgoCD notification templates use `.template` suffix for secret templates
- **Secrets management**: All credentials use Kubernetes Secrets with `secretKeyRef` or environment variable placeholders (`${VAR_NAME}`) — never hardcode secrets in ConfigMaps or manifests
- **Image tags**: Always pin container images to specific versions, never use `:latest`
- **Istio gateways**: Internal services use `istio-ingress/internal-gateway`, external services use `istio-ingress/external-gateway`
- **CORS**: Use parameterized origins via values (`.Values.ingress.corsAllowOrigin`, `.Values.virtualservice.corsAllowOrigins`), never wildcard `*` with credentials
- **Library chart**: `common` is never packaged or published; it is embedded via `helm dependency update`
- **Helm dependency artifacts**: `charts/*/charts/` and `charts/*/Chart.lock` are gitignored (generated by `helm dependency update`)
