[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-repo-blue)](https://artifacthub.io/) [![Release Charts](https://github.com/logic3579/helm-charts/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/logic3579/helm-charts/actions/workflows/release.yml)

## Repository Overview

This repo provides two things:

1. **Publishable Helm charts** in [`charts/`](./charts/) — released via GitHub Pages and GitHub Releases
2. **Infrastructure examples** in [`infrastructure-example/`](./infrastructure-example/) — cluster infrastructure reference configs

## Available Charts

| Chart | Description | Default Port |
|-------|-------------|-------------|
| [common](./charts/common) | Shared library chart (labels, VirtualService, PDB) — embedded into app charts, not published to the registry | — |
| [go-app](./charts/go-app) | Generic chart for Go application deployment | 8080 |
| [python-app](./charts/python-app) | Generic chart for Python application deployment (FastAPI, Django, Flask) | 8000 |
| [frontend-app](./charts/frontend-app) | Generic chart for frontend application deployment (nginx-based SPA) | 80 |

## Install from Helm Repo

```bash
# Add the chart repository
helm repo add logic-charts https://logic3579.github.io/helm-charts

# Update repository
helm repo update

# Search for available charts
helm search repo logic-charts

# Install a chart
helm install my-go-app logic-charts/go-app -f my-values.yaml
```

## Deploy from Local Chart

```bash
# Update dependencies (required for charts with common library)
helm dependency update charts/go-app

# Template and inspect rendered manifests
helm template my-release charts/go-app -f charts/go-app/values.yaml

# Install from local chart
helm install my-release charts/go-app -f my-values.yaml
```

## Release a New Version

To release a new version of the charts:

1. Modify chart source under `charts/`
2. **Bump `version` in `Chart.yaml`** — this is the release trigger
3. Commit and push to `main`

```bash
# Example: bump version to 0.3.0
# Edit charts/go-app/Chart.yaml, charts/python-app/Chart.yaml, charts/frontend-app/Chart.yaml
# Set version: 0.3.0

git add charts/
git commit -m "release: bump charts to v0.3.0"
git push origin main
```

The GitHub Actions workflow will automatically:
- Lint and package the charts
- Create GitHub Releases with `.tgz` assets
- Update `index.yaml` on the `gh-pages` branch
- Deploy to GitHub Pages

## Chart Features

All application charts (`go-app`, `python-app`, `frontend-app`) support:

| Feature | Key | Notes |
|---------|-----|-------|
| Liveness / Readiness probe | `livenessProbe`, `readinessProbe` | Configurable path, timing, thresholds |
| Startup probe | `startupProbe` | Optional; python-app enables it by default (30×5s window) |
| Horizontal Pod Autoscaler | `autoscaling.*` | CPU and memory targets |
| Pod Disruption Budget | `podDisruptionBudget.*` | `minAvailable` or `maxUnavailable` (mutually exclusive) |
| Istio VirtualService | `virtualservice.*` | CORS origins support `exact`/`prefix`/`regex` match types |
| Extra volumes | `volumes`, `volumeMounts` | Inject arbitrary volumes (e.g. tmpfs for `/tmp`) |
| ConfigMap / Secret | `configMap.*`, `secret.*` | Secret values are base64-encoded at render time — use ESO for production |

`frontend-app` additionally mounts `emptyDir` volumes for nginx writable directories (`/var/cache/nginx`, `/var/run`, `/tmp`) and runs with `readOnlyRootFilesystem: true`.

## ArgoCD Integration

The `charts/` directory can also be used directly with ArgoCD. Point ArgoCD to a chart path (e.g., `charts/go-app`) and provide deployment-specific values in the Application's `values` field.
