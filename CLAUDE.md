# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Helm charts repository that serves two purposes:

1. **Publishable Helm charts** in `charts/` — released via GitHub Pages using `helm/chart-releaser-action`
2. **Project templates** in `project-demo/` — reusable Kubernetes/Helm manifests for infrastructure components (ArgoCD, Istio, monitoring, logging, databases, etc.)

The repo is hosted at `https://logic3579.github.io/helm-charts` as a Helm chart repository.

## Common Commands

```bash
# Lint all charts
helm lint charts/*

# Package charts into .tgz archives
helm package charts/*

# Update chart index for GitHub Pages publishing
helm repo index ./charts --url https://logic3579.github.io/helm-charts

# Update library chart dependency (mychart depends on mylibchart)
cd charts/mychart && helm dependency update

# Template a chart locally to inspect rendered output
helm template mychart charts/mychart -f charts/mychart/values.yaml
```

## Architecture

### charts/

- **mychart** — Application chart (type: application) that depends on `mylibchart` as a local file dependency (`file://mylibchart`)
- **mylibchart** — Library chart (type: library) providing shared templates (`_configmap.tpl`, `_util.yaml`) that cannot be installed directly

### project-demo/

Reference configurations organized by concern:

- **application/** — Helm charts for deploying apps. `common/` provides shared named templates (deployment, service, ingress, HPA, configmap, virtualservice) consumed by `backend-example` and `frontend-example` via template includes (`tpl/` defines, `yaml/` invokes)
- **argocd/** — Multi-cluster GitOps setup with ApplicationSets, cluster secrets, projects, notifications. Uses GKE Workload Identity for cross-project auth. Example files (`.yaml.example`) need placeholders replaced before use
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
