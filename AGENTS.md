# AGENTS.md

Guidance for coding agents working in this repository.

This file mirrors the project conventions in `CLAUDE.md` for generic coding
agents. When repository rules, topology, or infrastructure reference paths
change, update both files in the same change.

## Scope

These instructions apply to the whole repository.

## Repository Overview

This repository has two main purposes:

1. Publishable Helm charts in `charts/`. They are packaged on push and hosted on the `gh-pages` branch, served as a Helm repository at `https://logic3579.github.io/helm-charts`. There are no Git tags and no GitHub Releases.
2. Infrastructure reference configs in `infrastructure/`.

Artifact Hub ownership is verified by `artifacthub-repo.yml` at the repository root. The release workflow copies it to `gh-pages` alongside `index.yaml`.

## Common Commands

Lint application charts only. Do not lint the `common` library chart directly.

```bash
for chart in charts/*/; do
  if [ -f "$chart/Chart.yaml" ] && ! grep -q 'type: library' "$chart/Chart.yaml"; then
    helm lint "$chart"
  fi
done
```

Update dependencies after changing `Chart.yaml` dependencies:

```bash
helm dependency update charts/elasticvue
```

Render a chart locally:

```bash
helm template my-release charts/elasticvue -f charts/elasticvue/values.yaml
```

Install from the hosted Helm repo:

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm install my-elasticvue logic3579/elasticvue -f my-values.yaml
```

## Agent Working Rules

- Prefer existing chart and infrastructure patterns over new abstractions.
- Keep edits narrowly scoped to the requested chart, manifest, or workflow.
- Never hand-edit generated release artifacts such as `index.yaml` on `gh-pages`.
- Do not edit the `gh-pages` branch manually. It is auto-managed by `.github/workflows/release.yaml`.
- Use `.yaml` for YAML files, never `.yml`.
- Pin image tags to explicit versions. Do not use `latest`.
- Do not duplicate shared template logic across app charts. Add reusable logic to `charts/common` when it applies broadly.
- For chart changes, run the app-chart lint loop above and render the affected chart with `helm template` when possible.
- For version bumps, update `Chart.yaml` and append an entry to `annotations.artifacthub.io/changes` for the affected publishable chart.
- Do not commit `charts/*/charts/` or `charts/*/Chart.lock`; they are intentionally ignored.

## Chart Architecture

### `charts/common`

Library chart (`type: library`, version `0.3.0`) embedded into app charts via `file://../common`. It is not published to the registry.

It provides helpers such as:

- `common.name`
- `common.fullname`
- `common.chart`
- `common.labels`
- `common.selectorLabels`
- `common.serviceAccountName`
- `common.image`
- `common.podLabels`

It also provides reusable templates for Service, ServiceAccount, ConfigMap, Secret, HPA, PDB, and Istio VirtualService.

### Common-Based App Charts

`elasticvue`, `redisinsight`, and `rocketmq-exporter` delegate most templates to `common` with one-line `{{- include "common.xxx" . }}` wrappers.

Only `deployment.yaml`, `NOTES.txt`, and chart-specific add-ons should contain chart-specific logic. Examples include `redisinsight/templates/pvc.yaml` and `rocketmq-exporter/templates/servicemonitor.yaml`.

These charts support:

- `startupProbe`
- `volumes` and `volumeMounts`
- HPA with CPU and memory targets
- PDB with mutually exclusive `minAvailable` and `maxUnavailable`
- Istio VirtualService CORS with `exact`, `prefix`, and `regex` origins

Each chart's `values.yaml` doubles as its configuration reference. Deployment-specific overrides live outside the chart directory.

### `charts/elasticvue`

Web UI for Elasticsearch and OpenSearch.

- Port: `8080`
- Base image: `nginx-unprivileged`
- Uses TCP probes because upstream has no `/health` endpoint.
- Deployment injects `ELASTICVUE_CLUSTERS`.
- `elasticvue.clusters` is JSON-encoded unless `elasticvue.existingSecret` is set.
- If both inline clusters and `existingSecret` are set, the Secret wins for credential safety.

### `charts/redisinsight`

Redis Inc.'s official Redis GUI.

- Port: `5540`
- Uses TCP probes because there is no documented HTTP health endpoint.
- Sets `RI_APP_HOST=0.0.0.0`.
- Derives `RI_APP_PORT` from `service.port`.
- Supports arbitrary `redisinsight.extraConfig` as `RI_<UPPER_KEY>`.
- Stateful SQLite data lives at `/data`.
- Persistence is opt-in through `persistence.{enabled,size,storageClass,accessMode,existingClaim}`.
- `templates/pvc.yaml` renders only when persistence is enabled.
- Deployment strategy is `Recreate` so RWO PVCs can detach cleanly during rollout.
- Use image namespace `redis/redisinsight`; `redislabs/` is legacy.

### `charts/rocketmq-exporter`

Apache RocketMQ Prometheus exporter.

- Port: `5557`
- Spring Boot app with TCP probes.
- Deployment injects `ROCKETMQ_CONFIG_*` env vars from `rocketmq.{namesrvAddr,rocketmqVersion,webTelemetryPath,enableCollect,outOfTimeSeconds,extraConfig}`.
- Optional ACL is configured with `auth.{enabled,existingSecret}`.
- `templates/servicemonitor.yaml` is gated by `serviceMonitor.enabled`.
- Published to the registry but not ArgoCD-deployed in this repository.

### `charts/nightingale`

Repackaged from upstream `flashcatcloud/n9e-helm` so it is discoverable on Artifact Hub.

- Self-contained chart.
- Does not depend on `common`.
- Has its own template subtree under `templates/{n9e,nginx,prometheus,redis,database,ingress,categraf}/`.
- Keep it structurally aligned with upstream.
- Pull upstream changes wholesale rather than refactoring it into local common patterns.
- Companion infra manifests live under `infrastructure/observability/nightingale/`.

## Infrastructure Architecture

### `infrastructure/argocd`

Multi-cluster GitOps.

- Mgmt and UAT auto-sync.
- Prod is manual-sync.
- Mgmt uses explicit per-component Applications in `infrastructure/argocd/applications/`.
- UAT and prod use ApplicationSets in `infrastructure/argocd/applicationsets/`.

Mgmt components:

- `elasticvue`
- `redisinsight`
- `kafka-ui`
- `nightingale`

Mgmt components are not generated by an ApplicationSet. Add a new mgmt-tier component by adding a new `applications/<name>.yaml` and a values file in the matching subtree.

UAT/prod ApplicationSets use a Git directory generator on `infrastructure/app/*`, excluding `infrastructure/app/common`. Each app provides colocated `values.yaml` plus `values-uat.yaml` or `values-prod.yaml`. The namespace is derived from the chart directory name.

Publishable charts under `charts/` are not deployed in UAT/prod. UAT/prod only run the in-cluster example apps under `infrastructure/app/`.

### `infrastructure/mgmt`

Shared values files for mgmt-tier UIs and standalone-only `rocketmq-exporter`.

- `elasticvue`, `redisinsight`, and `kafka-ui` share the `mgmt` namespace.
- `rocketmq-exporter` is standalone-only and not ArgoCD-managed here.
- Values files are consumed both by ArgoCD Applications and by standalone Helm fallback commands.
- ArgoCD is the canonical deployment route; standalone Helm is a fallback/debug path.
- `kafka-ui` uses the upstream `kafbat/kafka-ui` chart, not a chart from `charts/`.
- `kafka-ui` companion VirtualService manifests live under `infrastructure/mgmt/kafka-ui-manifests/`.

Nightingale follows the same single-source-of-truth pattern, but its values live under `infrastructure/observability/nightingale/` and it deploys to the `nightingale` namespace.

### `infrastructure/app`

In-cluster example applications for UAT/prod ApplicationSets.

- Contains its own `common` library chart, copied from `charts/common` and pinned independently to `0.3.0`.
- Contains `nginx` and `alpine` example apps.
- Each app ships `values.yaml`, `values-uat.yaml`, and `values-prod.yaml`.
- These charts are not published to GitHub Pages or OCI.

### `infrastructure/streaming/flink`

Standalone Apache Flink Kubernetes Operator reference.

- Do not add an ArgoCD Application unless explicitly requested.
- Use `FlinkDeployment` Application mode for production jobs.
- Keep checkpoints, savepoints, and HA metadata in object storage.
- Use Kubernetes HA for new references.
- Do not reintroduce direct JobManager/TaskManager Helm chart deployments for production examples.

### `infrastructure/streaming/kafka`

Standalone Strimzi Kafka reference.

- Do not add an ArgoCD Application unless explicitly requested.
- Use KRaft mode and `KafkaNodePool` resources.
- Keep controller and broker node pools separate for production-like examples.
- Manage topics and users with `KafkaTopic` and `KafkaUser`.
- Use Cruise Control / `KafkaRebalance` for rebalance examples.
- Do not create new ZooKeeper-based Kafka references or direct Kafka Helm chart deployments for production examples.

### Observability

- `grafana-lgtm/`: Grafana LGTM stack with Loki, Grafana, Tempo, Mimir, Alloy/Promtail.
- `victoriametrics/`: VictoriaMetrics stack with VMCluster, VictoriaLogs, VictoriaTraces, vmagent, vmalert, vlagent, and vmauth.
- `prometheus-community/`: `prometheus-community/prometheus` chart, server-only. Namespace `prom`.
- `opentelemetry/`: OTel Operator, agent/gateway Collector CRs, and Instrumentation CR.
- `nightingale/`: Nightingale plus Categraf, dashboards, and alert rules. Namespace `nightingale`.

Keep all values and Kubernetes manifests for each observability stack flat at `infrastructure/observability/<stack>/`. Filename prefixes identify components. The exception is `nightingale/n9e-ui/`, which stores dashboard and alert-rule JSON content for UI import, not Kubernetes manifests.

### `infrastructure/envoy-gateway`

Kubernetes Gateway API reference manifests using the upstream Envoy Gateway Helm chart.

- Standalone-only for now; do not add an ArgoCD Application unless explicitly requested.
- Parallel exploration path; does not replace existing Istio `VirtualService` routing.
- Uses Gateway API resources: `GatewayClass`, `Gateway`, `HTTPRoute`, and `ReferenceGrant`.
- Keeps internal/external Gateway examples analogous to the current internal/external Istio gateway split.
- Avoid Ingress resources.

## Deployment Model

`charts/` supports two deployment methods:

1. Helm repository: packaged on push and hosted on `gh-pages`.
2. ArgoCD directory source: ArgoCD points at chart paths such as `charts/elasticvue` and resolves `file://../common` with `helm dependency build`.

OCI registries are downstream mirrors. The Pages-based Helm repo remains the source of truth.

OCI paths:

- GHCR: `oci://ghcr.io/logic3579/helm-charts/<chart>`
- Docker Hub: `oci://registry-1.docker.io/logic3579/<chart>`
- Quay: `oci://quay.io/logic3579/<chart>`

## Release Workflow

Release workflow: `.github/workflows/release.yaml`.

Triggers:

- Push to `main` that modifies `charts/**`
- Manual `workflow_dispatch`

To publish a new chart version:

1. Modify chart source under `charts/`.
2. Bump `version` in the affected `Chart.yaml`.
3. Append an entry to `annotations.artifacthub.io/changes`.
4. Commit and push to `main`.

Workflow summary:

1. Checkout `main`.
2. Run `helm dependency update`.
3. Run `helm lint` for app charts only.
4. Run `helm package` into `.packages/`.
5. Soft-fail OCI fan-out pushes to GHCR, Docker Hub, and Quay.
6. Add a `gh-pages` worktree.
7. Copy new `.tgz` files, preserving already-published versions.
8. Remove `.tgz` files for charts no longer present under `charts/`.
9. Keep the latest 3 versions per chart on `gh-pages`.
10. Regenerate `index.yaml` with `helm repo index`.
11. Sync `index.html` and `artifacthub-repo.yml`.
12. Commit and push `gh-pages`.

Important release details:

- `index.yaml` is regenerated from scratch from the `.tgz` files in the `gh-pages` worktree.
- Retention is 3 versions per chart, controlled by `RETENTION` in the workflow env.
- Chart removal from `charts/` deletes its `.tgz` files from `gh-pages` on the next workflow run.
- OCI registries keep historical tags indefinitely.
- Docker Hub and Quay pushes are skipped when their token secrets are not configured.
- OCI push failures do not block `gh-pages` publishing.

Branches:

- `main`: chart source, workflow, docs.
- `gh-pages`: auto-managed chart repository artifacts. Do not edit manually.

## Chart Conventions

- Use `.template` only for files that must be copied to a `.yaml` sibling before applying. Currently this applies to `infrastructure/argocd/notifications/secret.yaml.template`.
- Files with `<PLACEHOLDER>` tokens are committed as plain `.yaml` and edited in place.
- Use Kubernetes Secrets with `secretKeyRef` or env var placeholders for sensitive values.
- The built-in `secret:` chart template base64-encodes plaintext at render time. Prefer ESO or Sealed Secrets for production.
- Internal services use `istio-ingress/internal-gateway`.
- External services use `istio-ingress/external-gateway`.
- Route with Istio VirtualService, not Ingress resources.
- `virtualservice.corsPolicy.allowOrigins` accepts strings as shorthand for `exact`, or maps with `exact`, `prefix`, or `regex`.
- Do not combine wildcard `*` CORS origins with credentials.
- Pin `common` dependency versions explicitly in each app chart `Chart.yaml`, for example `"0.3.0"`. Avoid version ranges.
- PDB `minAvailable` and `maxUnavailable` are mutually exclusive; setting both should fail `helm template`.
- For charts with `readOnlyRootFilesystem: true`, mount tmpfs `emptyDir` for `/tmp` if the app writes temp files.
- `serviceAccount.automountServiceAccountToken` is per-chart and usually defaults to `false`.
- Add `annotations.artifacthub.io/license` and `annotations.artifacthub.io/links` to publishable charts when needed. Use `elasticvue` as the reference.
- Prefer a maintained upstream chart over publishing a parallel local chart when one exists, as with `kafbat/kafka-ui`.

## Infrastructure Conventions

- Observability stack namespaces are short names such as `lgtm`, `vm`, and `otel`.
- Cross-stack service hostnames use `<svc>.<ns>.svc.cluster.local`.
- Values files with `serviceAccount.annotations` should include comments for both AWS IRSA and GCP Workload Identity formats above the annotations map.
- Do not add VirtualServices for OTLP-receiving components such as Tempo, VictoriaTraces, and the OpenTelemetry collector.
- Keep `infrastructure/envoy-gateway/` as a standalone Gateway API reference path unless the user explicitly asks to wire it into ArgoCD. Existing charts still use Istio `VirtualService` values; do not retrofit Gateway API templates into `charts/common` as part of Envoy Gateway reference work.
- Keep `infrastructure/streaming/kafka/` and `infrastructure/streaming/flink/` as standalone operator-based reference paths unless the user explicitly asks to wire them into ArgoCD.
- Grafana LGTM uses object storage by default.
- VictoriaMetrics uses local PVCs. Do not retrofit object storage hot-tier assumptions into VM configs.
- Nightingale alert-rule JSON files live under `infrastructure/observability/nightingale/n9e-ui/alert-rules/`.
- Keep middleware-specific Nightingale rules in their own domain files.
- Nightingale rule names should use stable prefixes such as `Common -`, `K8S -`, `Istio -`, `Kafka -`, and `Redis -`.

## Validation Checklist

Before finishing chart work:

1. Run the app-chart Helm lint loop, or lint the affected app chart directly when appropriate.
2. Run `helm template` for the affected chart and values file.
3. Confirm `Chart.yaml` version and Artifact Hub changes annotations are correct for publishable chart changes.
4. Confirm generated dependency artifacts are not committed.

Before finishing infrastructure work:

1. Check affected manifests for namespace, gateway, and values-file path consistency.
2. Confirm ArgoCD source topology matches the target environment.
3. Keep mgmt values shared between ArgoCD and standalone Helm fallback paths when applicable.
