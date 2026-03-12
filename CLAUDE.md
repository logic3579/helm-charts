# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Helm charts repository that serves two purposes:

1. **Publishable Helm charts** in `charts/` — released via GitHub Pages using `helm/chart-releaser-action`
2. **Quickstart examples** in `*-example/` directories — ready-to-use templates for Kustomize or Helm app deployment, plus infrastructure reference configs

The repo is hosted at `https://logic3579.github.io/helm-charts` as a Helm chart repository.

## Common Commands

```bash
# Lint all charts
helm lint charts/*

# Package charts into .tgz archives
helm package charts/*

# Update chart index for GitHub Pages publishing
helm repo index ./charts --url https://logic3579.github.io/helm-charts

# Update chart dependencies (required after modifying Chart.yaml dependencies)
helm dependency update charts/go-app

# Template a chart locally to inspect rendered output
helm template my-release charts/go-app -f charts/go-app/values.yaml

# Template with example values
helm template backend charts/go-app -f helm-example/backend-example/values.yaml

# Build kustomize overlays
kustomize build kustomize-example/overlays/dev
```

## Architecture

### charts/

- **common** — Shared Helm library chart (`type: library`) providing reusable named templates: labels, helpers, VirtualService, PodDisruptionBudget. All app charts depend on this via `dependencies`
- **go-app** — Generic deployment chart for Go applications (port 8080, /healthz + /readyz probes, minimal resource footprint)
- **python-app** — Generic deployment chart for Python applications (port 8000, /health probes, higher memory defaults for Python runtimes)
- **frontend-app** — Generic deployment chart for compiled frontend apps served by nginx (port 80, optional custom nginx config, lightweight resources)

### kustomize-example/

Kustomize base/components/overlays pattern: base manifests with security hardening, reusable Components for shared resource limits, per-environment overlays (dev/stg/prod)

### helm-example/

Example values files (`backend-example/`, `frontend-example/`) that deploy apps using the `charts/` charts

### infrastructure-example/

Cluster infrastructure reference configs:

- **argocd/** — Multi-cluster GitOps setup with ApplicationSets, cluster secrets, projects, notifications (GKE Workload Identity)
- **istio/** — Gateway and AuthorizationPolicy configs for external/internal traffic
- **monitoring/** — Nightingale (n9e) + Categraf + Grafana dashboards and alert rules
- **cert-manager/, database/, bigdata/, logging/, streaming/, mgmt/** — Various infrastructure component manifests

## CI/CD

The GitHub Actions workflow (`.github/workflows/release.yml`) triggers on pushes to `main` that modify `charts/**`. It runs `helm lint` before packaging, uses `helm/chart-releaser-action` to release charts, then deploys `index.html` to GitHub Pages. Concurrency control prevents parallel release races.

## Conventions

- Chart archives (`.tgz`) are committed to `charts/` alongside source charts
- Template files use `.example` suffix for configs requiring secret/environment-specific values
- ArgoCD notification templates use `.template` suffix for secret templates
- **Secrets management**: All credentials use Kubernetes Secrets with `secretKeyRef` or environment variable placeholders (`${VAR_NAME}`) — never hardcode secrets in ConfigMaps or manifests
- **Image tags**: Always pin container images to specific versions, never use `:latest`
- **Istio gateways**: Internal services use `istio-ingress/internal-gateway`, external services use `istio-ingress/external-gateway`
- **CORS**: Use parameterized origins via values (`.Values.ingress.corsAllowOrigin`, `.Values.virtualservice.corsAllowOrigins`), never wildcard `*` with credentials
