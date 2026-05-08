# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Repository Overview

Two purposes:

1. **Publishable Helm charts** in `charts/` — released via GitHub Pages using `helm/chart-releaser-action`.
2. **Infrastructure references** in `infrastructure/` — cluster infrastructure example configs.

Repo is hosted at `https://logic3579.github.io/helm-charts` and listed on Artifact Hub (verified via `artifacthub-repo.yml` at the repo root, deployed to Pages alongside `index.yaml`).

## Common Commands

```bash
# Lint application charts only (common is a library chart — skip)
for chart in charts/*/; do
  if [ -f "$chart/Chart.yaml" ] && ! grep -q 'type: library' "$chart/Chart.yaml"; then
    helm lint "$chart"
  fi
done

# Update chart dependencies (after modifying Chart.yaml dependencies)
helm dependency update charts/go-app

# Render locally
helm template my-release charts/go-app -f charts/go-app/values.yaml

# Install from registry
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm install my-go-app logic-charts/go-app -f my-values.yaml
```

## Architecture

### charts/

- **common** — Library chart (`type: library`, version `0.2.0`) embedded into every app chart via `file://../common`. Not published to the registry. Provides `common.{name,fullname,chart,labels,selectorLabels,serviceAccountName,image,podLabels}` helpers plus reusable templates: `service`, `serviceaccount` (parameterized `automountServiceAccountToken`), `configmap`, `secret` (with ESO warning), `hpa` (CPU+memory), `pdb` (mutual-exclusivity validation), `virtualservice` (CORS exact/prefix/regex).
- **go-app** — Go (port 8080, `/healthz` + `/readyz`, `readOnlyRootFilesystem: true`, minimal resources).
- **python-app** — Python (port 8000, `/health`, `readOnlyRootFilesystem: false`, `startupProbe` enabled by default, 30×5s window, higher memory defaults).
- **frontend-app** — Compiled SPA served by nginx (port 80, `readOnlyRootFilesystem: true` with `emptyDir` mounts to `/var/cache/nginx`, `/var/run`, `/tmp`, optional custom nginx config). Has a chart-specific `nginx-configmap.yaml` and intentionally no `secret.yaml`.
- **kafka-ui** — Kafka UI (port 8080, Spring Boot actuator probes, `startupProbe` enabled). Deployment template injects kafka-specific env: `auth` (LOGIN_FORM/DISABLED/LDAP/OAUTH2 via `secretKeyRef`) and `kafkaClusters` rendered as `KAFKA_CLUSTERS_N_*` (bootstrapServers, readonly, schemaRegistry, ksqldbServer, arbitrary properties). On every version bump, append a `kind/description` entry to `Chart.yaml`'s `annotations.artifacthub.io/changes` block.

App charts delegate most templates to `common` via one-line `{{- include "common.xxx" . }}`. Only `deployment.yaml` and `NOTES.txt` carry chart-specific logic. All four support `startupProbe`, `volumes`/`volumeMounts`, HPA (CPU+memory), and Istio VirtualService CORS (`exact`/`prefix`/`regex`). Each chart's `values.yaml` doubles as the configuration reference — deployment-specific overrides go in ArgoCD `values` or `helm install -f`.

### infrastructure/

- **argocd/** — Multi-cluster GitOps (ApplicationSets, GKE Workload Identity, Slack notifications).
- **istio/** — Gateway and AuthorizationPolicy configs.
- **nightingale/** — Nightingale (n9e) + Categraf with curated dashboards and alert rules.
- **observability/grafana-lgtm/** — Grafana LGTM stack (Loki + Grafana + Tempo + Mimir) with Alloy/Promtail collectors.
- **observability/victoriametrics/** — VictoriaMetrics stack (VMCluster + VictoriaLogs + VictoriaTraces) with vmagent / vmalert / vlagent and bundled vmauth gateway.
- **observability/opentelemetry/** — OTel Operator + agent/gateway Collector CRs + Instrumentation CR (auto-injects Java/Python SDKs); collection layer that exports to either grafana-lgtm or victoriametrics.
- **cert-manager/, database/, bigdata/, streaming/, mgmt/** — Various component manifests.

## Dual Deployment Model

`charts/` supports two methods simultaneously:

1. **Helm Registry** — packaged, released to GitHub Releases, indexed on GitHub Pages. Users install via `helm repo add` / `helm install`.
2. **ArgoCD Directory** — ArgoCD points at a chart path (e.g. `charts/go-app`) with `source.helm`. ArgoCD auto-runs `helm dependency build` to resolve `file://../common`.

## CI/CD — Release Workflow

`.github/workflows/release.yaml`. Trigger: auto on push to `main` modifying `charts/**`, or manual `workflow_dispatch`.

To publish a new chart version:

1. Modify chart source under `charts/`.
2. Bump `version` in `Chart.yaml` — chart-releaser skips versions that already have a Git tag.
3. `git commit && git push origin main`.

Workflow (ubuntu-24.04): checkout (full history+tags) → `helm dependency update` → `helm lint` (app charts only) → `helm package` → check existing GH Releases → `chart-releaser-action` (`skip_packaging: true`, `continue-on-error: true`) uploads `.tgz` per new version + regenerates `index.yaml` on `gh-pages` → Prepare Pages (`index.html` + `artifacthub-repo.yml` from main + `index.yaml` from gh-pages) → Deploy Pages.

**Important**:
- `index.yaml` is exclusively managed by chart-releaser on `gh-pages`. Never run `helm repo index` manually.
- `chart-releaser-action@v1.7.0` has a known `latest_tag` bug; `continue-on-error: true` keeps the pipeline green. Don't remove until the upstream bug is verified fixed.
- `artifacthub-repo.yml` must remain reachable at `https://logic3579.github.io/helm-charts/artifacthub-repo.yml` for ownership verification.

Branches: **main** (chart source, workflow, docs) — **gh-pages** (chart-releaser-managed, do not edit manually).

## Chart Conventions

- **`.example` suffix** for configs needing secret/environment-specific values; **`.template` suffix** for ArgoCD notification secret templates.
- **Secrets**: use Kubernetes Secrets with `secretKeyRef` or env var placeholders (`${VAR_NAME}`). The built-in `secret:` chart template base64-encodes plaintext at render time — for production prefer External Secrets Operator (ESO) or Sealed Secrets.
- **Image tags**: pin to specific versions, never `:latest`.
- **Istio gateways**: internal services use `istio-ingress/internal-gateway`; external services use `istio-ingress/external-gateway`.
- **CORS**: VirtualService `corsPolicy.allowOrigins` accepts strings (shorthand for `exact`) or maps (`exact`/`prefix`/`regex`). Never combine wildcard `*` with credentials.
- **Library chart pinning**: each app chart's `Chart.yaml` pins `common` to an explicit version (e.g. `"0.2.0"`); avoid ranges like `">=0.x.x"`. `charts/*/charts/` and `charts/*/Chart.lock` are gitignored.
- **PDB**: `minAvailable` and `maxUnavailable` are mutually exclusive — setting both fails `helm template` by design.
- **Volumes**: app charts accept `volumes` and `volumeMounts` lists. For `readOnlyRootFilesystem: true` charts (go-app, frontend-app), mount a tmpfs `emptyDir` for `/tmp` if the app writes temp files. frontend-app auto-mounts nginx writable dirs (`nginxWritableDirs`) — adjust if using non-standard nginx images.
- **No Ingress**: route via Istio VirtualService (`virtualservice.*` in values), not Ingress resources.
- **ServiceAccount token**: `serviceAccount.automountServiceAccountToken` defaults to `true` for go-app/python-app and `false` for frontend-app.
- **Template structure**: only `deployment.yaml` and `NOTES.txt` are chart-specific. Don't duplicate template logic across charts — add new shared templates to `common`.
- **Linting**: use the loop above (or the CI pattern). Never `helm lint charts/*` — it includes the library chart and produces misleading errors.
- **YAML extension**: always `.yaml`, never `.yml`. The repo was normalized in a prior refactor.
- **Artifact Hub metadata**: when publishing a new chart, add `annotations.artifacthub.io/license` and `annotations.artifacthub.io/links` to `Chart.yaml` (kafka-ui is the reference).

## Infrastructure Conventions

These fix recurring decisions across `infrastructure/` so they don't get re-debated.

- **Flat layout under each observability stack**: `infrastructure/observability/<stack>/` keeps every values + VirtualService manifest at the top level — no per-component subdirectories. Filenames carry the component prefix (`loki-values.yaml`, `vmcluster-values.yaml`, `collector-agent.yaml`). All three stacks (`grafana-lgtm/`, `victoriametrics/`, `opentelemetry/`) follow this.
- **Per-stack short namespace**: each stack lives in a namespace named after the stack — `lgtm`, `vm`, `otel`. Cross-stack service hostnames read as `<svc>.<ns>.svc.cluster.local`.
- **IRSA + Workload Identity annotation block**: every component values file with a `serviceAccount.annotations` field carries a two-line comment showing both AWS IRSA and GCP Workload Identity formats above the (empty) annotations map. Mirror the existing shape:
  ```yaml
  serviceAccount:
    create: true
    # AWS IRSA:                eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/<comp>-role
    # GCP Workload Identity:   iam.gke.io/gcp-service-account: <comp>@PROJECT_ID.iam.gserviceaccount.com
    annotations: {}
  ```
- **VirtualService skip rule for OTLP-receiving components**: Tempo, VictoriaTraces, and the OpenTelemetry collector skip VS creation. OTLP gRPC doesn't fit Istio's HTTP gateway routing, and queries run intra-cluster via Grafana's Service URLs. Don't add a VS just for symmetry with Loki/Mimir/vmauth gateways.
- **Storage backend differs by stack**: grafana-lgtm uses object storage (GCS by default; values carry `gcs.bucket_name: example-*` placeholders). VictoriaMetrics uses local PVCs (`premium-rwo` storageClass). Don't retrofit the other model — VM has no native object-store hot tier; LGTM scales much better against object storage than PVCs.
