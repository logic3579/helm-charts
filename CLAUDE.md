# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Helm charts repository that serves two purposes:

1. **Publishable Helm charts** in `charts/` — released via GitHub Pages using `helm/chart-releaser-action`
2. **Infrastructure examples** in `infrastructure/` — cluster infrastructure reference configs

The repo is hosted at `https://logic3579.github.io/helm-charts` as a Helm chart repository.

## Common Commands

```bash
# Lint application charts only (common is a library chart — not linted standalone)
for chart in charts/*/; do
  if [ -f "$chart/Chart.yaml" ] && ! grep -q 'type: library' "$chart/Chart.yaml"; then
    helm lint "$chart"
  fi
done

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

- **common** — Shared Helm library chart (`type: library`) providing reusable named templates. All app charts depend on this via `dependencies` using `file://../common` pinned to version `0.2.0`. Not published to the registry — it is embedded into each app chart's `.tgz` during packaging. Provides:
  - **Helpers**: `common.name`, `common.fullname`, `common.chart`, `common.labels`, `common.selectorLabels`, `common.serviceAccountName`, `common.image` (with digest support), `common.podLabels` (standard labels + user podLabels)
  - **Resource templates**: `common.service`, `common.serviceaccount` (parameterized `automountServiceAccountToken`), `common.configmap`, `common.secret` (with ESO warning), `common.hpa` (CPU + memory), `common.pdb` (with mutual exclusivity validation), `common.virtualservice` (CORS `exact`/`prefix`/`regex`)
- **go-app** — Generic deployment chart for Go applications (port 8080, /healthz + /readyz probes, `readOnlyRootFilesystem: true`, minimal resource footprint)
- **python-app** — Generic deployment chart for Python applications (port 8000, /health probes, `readOnlyRootFilesystem: false` for Python tmp needs, `startupProbe` enabled by default with 30×5s window, higher memory defaults)
- **frontend-app** — Generic deployment chart for compiled frontend apps served by nginx (port 80, `readOnlyRootFilesystem: true` with `emptyDir` volumes auto-mounted for `/var/cache/nginx`, `/var/run`, `/tmp`, optional custom nginx config)
- **kafka-ui** — Chart for UI for Apache Kafka (port 8080, Spring Boot actuator probes, `readOnlyRootFilesystem: false` for Java tmp needs, `startupProbe` enabled by default with 30×5s window). Deployment template includes kafka-specific logic: `auth` config (LOGIN_FORM/DISABLED/LDAP/OAUTH2 with secretKeyRef), `kafkaClusters` list rendered as `KAFKA_CLUSTERS_N_*` env vars (bootstrapServers, readonly, schemaRegistry, ksqldbServer, arbitrary properties)

All four app charts delegate most templates to `common` via one-line `{{- include "common.xxx" . }}` calls. Only `deployment.yaml` and `NOTES.txt` remain as full templates per chart (deployment has chart-specific logic like nginx volumes for frontend-app, kafka cluster env vars for kafka-ui).

All four app charts support: `startupProbe`, `volumes`/`volumeMounts`, HPA with CPU+memory targets, and Istio VirtualService CORS with `exact`/`prefix`/`regex` origin match types.

Each chart has a single `values.yaml` that serves as both the default values and the configuration reference. Deployment-specific overrides (image repo, resources, env vars, etc.) should be provided via ArgoCD Application `values` or `helm install -f`.

### infrastructure/

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

The GitHub Actions workflow (`.github/workflows/release.yaml`) automates chart publishing.

### Trigger

- **Auto**: Push to `main` that modifies `charts/**`
- **Manual**: `workflow_dispatch`

### How to publish a new chart version

1. Modify chart source under `charts/`
2. **Bump `version` in `Chart.yaml`** — this is the release trigger; chart-releaser skips versions that already have a corresponding Git tag
3. `git commit && git push origin main`

### Workflow steps

```
checkout (fetch-depth: 0, full history + tags for chart-releaser)  [ubuntu-24.04]
    ↓
helm dependency update (resolve file://../common for each app chart)
    ↓
helm lint (application charts only — filters type: library)
    ↓
helm package (application charts only → .cr-release-packages/)
    ↓
check for new versions (gh release view per package; skip chart-releaser if all exist)
    ↓
chart-releaser-action (skip_packaging: true, only runs when new versions detected):
  a. cr upload — create GitHub Release per new version, .tgz as asset
  b. cr index  — regenerate index.yaml, push to gh-pages branch
    ↓
Prepare Pages (index.html from main + index.yaml from gh-pages → ./public/)
    ↓
Deploy to GitHub Pages (serves both index.html and index.yaml)
```

**Important**: Do NOT manually run `helm repo index` — `index.yaml` is exclusively managed by chart-releaser on the `gh-pages` branch.

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
- **Secrets management**: All credentials use Kubernetes Secrets with `secretKeyRef` or environment variable placeholders (`${VAR_NAME}`) — never hardcode secrets in ConfigMaps or manifests. The built-in `secret:` chart feature base64-encodes plaintext values at render time — for production use External Secrets Operator (ESO) or Sealed Secrets instead
- **Image tags**: Always pin container images to specific versions, never use `:latest`
- **Istio gateways**: Internal services use `istio-ingress/internal-gateway`, external services use `istio-ingress/external-gateway`
- **CORS**: VirtualService `corsPolicy.allowOrigins` accepts strings (shorthand for `exact`) or maps (`exact`/`prefix`/`regex`). Never use wildcard `*` with credentials
- **Library chart**: `common` is never packaged or published; it is embedded via `helm dependency update`. Pin the dependency to an explicit version (e.g. `"0.2.0"`) in each app chart's `Chart.yaml` — avoid version ranges like `">=0.x.x"`
- **Helm dependency artifacts**: `charts/*/charts/` and `charts/*/Chart.lock` are gitignored (generated by `helm dependency update`)
- **PodDisruptionBudget**: `minAvailable` and `maxUnavailable` are mutually exclusive — setting both causes a `helm template` failure by design
- **Startup probes**: python-app enables `startupProbe` by default (`failureThreshold: 30, periodSeconds: 5` = 150s max startup window). For go-app and frontend-app, `startupProbe` is optional and empty by default
- **Volumes**: All app charts accept `volumes` and `volumeMounts` lists for injecting arbitrary volumes. For go-app (`readOnlyRootFilesystem: true`), mount a tmpfs `emptyDir` for `/tmp` if the app writes temp files. frontend-app auto-mounts nginx writable dirs (`nginxWritableDirs`) — customize in values if using a non-standard nginx image
- **No Ingress**: Ingress resources have been removed from all charts (deprecated in newer Kubernetes). Use Istio VirtualService (`virtualservice.*` in values) for traffic routing instead
- **ServiceAccount token**: `serviceAccount.automountServiceAccountToken` is parameterized in values — defaults to `true` for go-app/python-app and `false` for frontend-app (frontend pods don't need API access)
- **Template structure**: App chart templates (service, serviceaccount, configmap, secret, hpa, pdb, virtualservice) are one-line `include` calls to `common.*`. Only `deployment.yaml` and `NOTES.txt` contain chart-specific logic. Do not duplicate template logic in app charts — add new shared templates to common instead
- **Linting**: Always lint with the loop command above (or the CI workflow pattern) — never `helm lint charts/*` which includes the library chart and may produce misleading errors
