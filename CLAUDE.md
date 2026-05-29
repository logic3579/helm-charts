# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Repository Overview

Two purposes:

1. **Publishable Helm charts** in `charts/` — packaged on push and hosted on the `gh-pages` branch (served as a Helm repo at the Pages URL). No Git tags, no GitHub Releases.
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
- **nightingale** — Repackaged from upstream [`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm) so the chart is discoverable on Artifact Hub (upstream doesn't publish there). Self-contained — does NOT depend on `common`. Has its own `templates/{n9e,nginx,prometheus,redis,database,ingress,categraf}/` subtree and is *not* refactored to use `common`. Keep the chart structurally aligned with upstream; pull upstream changes wholesale rather than diverging. On every version bump, append a `kind/description` entry to `Chart.yaml`'s `annotations.artifacthub.io/changes` block. Companion infra reference manifests (categraf, VirtualService, dashboards) live under `infrastructure/observability/nightingale/`.

App charts (go-app, python-app, frontend-app, kafka-ui) delegate most templates to `common` via one-line `{{- include "common.xxx" . }}`. Only `deployment.yaml` and `NOTES.txt` carry chart-specific logic. All four support `startupProbe`, `volumes`/`volumeMounts`, HPA (CPU+memory), and Istio VirtualService CORS (`exact`/`prefix`/`regex`). Each chart's `values.yaml` doubles as the configuration reference — deployment-specific overrides live OUTSIDE the chart directory: ArgoCD users put them under `infrastructure/argocd/values/<env>/<chart>.yaml`; standalone Helm users pass `-f my-values.yaml`. The nightingale chart is an exception — it's a vendored upstream chart, not a `common`-based app chart.

### infrastructure/

- **argocd/** — Multi-cluster GitOps: install values (`argocd-values.yaml`), UI VirtualService (`argocd-virtualservice.yaml`), multi-source ApplicationSets (`applicationsets/{uat,prod}-apps.yaml`), per-env chart overrides (`values/{uat,prod}/<chart>.yaml`), cluster/project/notification templates. UAT auto-syncs; Prod is manual-sync.
- **istio/** — Gateway and AuthorizationPolicy configs.
- **observability/grafana-lgtm/** — Grafana LGTM stack (Loki + Grafana + Tempo + Mimir) with Alloy/Promtail collectors.
- **observability/victoriametrics/** — VictoriaMetrics stack (VMCluster + VictoriaLogs + VictoriaTraces) with vmagent / vmalert / vlagent and bundled vmauth gateway.
- **observability/prometheus-community/** — `prometheus-community/prometheus` chart, **server-only** (alertmanager/KSM/node-exporter/pushgateway subcharts disabled). Minimal single-node alternative to Mimir / VMCluster; namespace `prom`.
- **observability/opentelemetry/** — OTel Operator + agent/gateway Collector CRs + Instrumentation CR (auto-injects Java/Python SDKs); collection layer that exports to either grafana-lgtm or victoriametrics (or remote_write to the plain prometheus stack for metrics only).
- **observability/nightingale/** — Nightingale (n9e) + Categraf with curated dashboards and alert rules. Pairs with `prometheus-community/` exporters; namespace `nightingale`.
- **cert-manager/, database/, bigdata/, streaming/, mgmt/** — Various component manifests.

## Dual Deployment Model

`charts/` supports two methods simultaneously:

1. **Helm Registry** — packaged on push and hosted on `gh-pages` (served via GitHub Pages). Users install via `helm repo add` / `helm install`.
2. **ArgoCD Directory** — ArgoCD points at a chart path (e.g. `charts/go-app`) with `source.helm`. ArgoCD auto-runs `helm dependency build` to resolve `file://../common`.

## CI/CD — Release Workflow

`.github/workflows/release.yaml`. Trigger: auto on push to `main` modifying `charts/**`, or manual `workflow_dispatch`.

To publish a new chart version:

1. Modify chart source under `charts/`.
2. Bump `version` in `Chart.yaml`.
3. `git commit && git push origin main`.

Workflow (ubuntu-24.04): checkout main → `helm dependency update` → `helm lint` (app charts only) → `helm package` into `.packages/` → `git worktree add gh-pages` → copy new `.tgz` into the worktree (preserve already-published versions via existence check) → prune to the latest 3 versions per chart (strict `^<name>-[0-9]` regex match, `sort -V`) → `helm repo index gh-pages --url https://logic3579.github.io/helm-charts` → sync `index.html` + `artifacthub-repo.yml` from `main` → commit and push to `gh-pages`.

**No Git tags, no GitHub Releases.** Pages source is the `gh-pages` branch root (Settings → Pages → Build and deployment → Source: *Deploy from a branch* → `gh-pages` / `/`); the workflow does NOT use `actions/deploy-pages`.

**Important**:
- `index.yaml` is regenerated from scratch by `helm repo index` on every run, based on the `.tgz` files currently in the `gh-pages` worktree. Do NOT hand-edit `index.yaml`.
- Retention: 3 versions per chart. Older `.tgz` files are deleted from `gh-pages` automatically. To keep more, change `RETENTION` in the workflow `env` block.
- `artifacthub-repo.yml` must remain reachable at `https://logic3579.github.io/helm-charts/artifacthub-repo.yml` for ownership verification — the workflow copies it onto `gh-pages` on every run.
- The prune step uses a strict `^<chart-name>-[0-9]` regex (not a raw glob) so that, e.g., a future `kafka` chart wouldn't accidentally match `kafka-ui-*.tgz`.

Branches: **main** (chart source, workflow, docs) — **gh-pages** (auto-managed by the workflow: `.tgz` artifacts + `index.yaml` + `index.html` + `artifacthub-repo.yml`; do not edit manually).

## Chart Conventions

- **`.template` suffix** for files that must be copied to a `.yaml` sibling before applying (currently only `infrastructure/argocd/notifications/secret.yaml.template`, which receives the Slack webhook URL). Files with `<PLACEHOLDER>` tokens are committed as plain `.yaml` and edited in place — no `.example` shadow files.
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

- **Flat layout under each observability stack**: `infrastructure/observability/<stack>/` keeps every values + VirtualService manifest at the top level — no per-component subdirectories. Filenames carry the component prefix (`loki-values.yaml`, `vmcluster-values.yaml`, `collector-agent.yaml`). All stacks (`grafana-lgtm/`, `victoriametrics/`, `prometheus-community/`, `opentelemetry/`, `nightingale/`) follow this for K8s manifests. Exception: `nightingale/n9e-ui/` holds dashboard and alert-rule JSON definitions imported into the Nightingale UI — content, not manifests.
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
- **ArgoCD ApplicationSet pattern**: `infrastructure/argocd/applicationsets/{uat,prod}-apps.yaml` use a Git directory generator on `charts/*` with `charts/common` excluded (library chart, not deployable). Each generated Application is **multi-source**: source 1 renders the chart with `valueFiles: [values.yaml, $values/infrastructure/argocd/values/<env>/<chart>.yaml]`; source 2 is a `ref: values` pointer that resolves the `$values` prefix. `ignoreMissingValueFiles: true` lets a chart sync before its env override file exists. Env values live under `infrastructure/argocd/values/<env>/<chart>.yaml` — never inside the chart directory, so publishable charts stay deployment-agnostic.
