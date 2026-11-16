# AGENTS.md

Guidance for coding agents working in this repository.

This is the single source of project conventions for coding agents. Update
this file when repository rules, topology, or infrastructure reference paths
change. Keep shared conventions here instead of duplicating them in
agent-specific instruction files.

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
- For version bumps, update `Chart.yaml` and append a `kind`/`description` entry to `annotations.artifacthub.io/changes` for the affected publishable chart.
- Do not commit generated dependency artifacts: `charts/*/charts/`, `charts/*/Chart.lock`, `infrastructure/app/*/charts/`, or `infrastructure/app/*/Chart.lock`; they are intentionally ignored.

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

`elasticvue`, `redisinsight`, and `rocketmq-dashboard` delegate most templates to `common` with one-line `{{- include "common.xxx" . }}` wrappers.

Only `deployment.yaml`, `NOTES.txt`, and chart-specific add-ons should contain chart-specific logic. Examples are `redisinsight/templates/pvc.yaml` and `rocketmq-dashboard/templates/frontend-configmap.yaml`.

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

Redis Inc.'s official Redis GUI, built on Node.js.

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

### `charts/rocketmq-dashboard`

RocketMQ Studio v3.0.0, the successor to RocketMQ Dashboard.

- Uses `common` version `0.3.0` and runs frontend Nginx plus Java backend in one pod.
- Frontend Service/Nginx port: `service.port` (default `8080`); backend: `dashboard.port` (default `8888`). The ports must differ.
- Default application images are public Docker Hub images `logic3579/rocketmq-server:3.0.0` and `logic3579/rocketmq-web:3.0.0`, built from upstream v3.0.0 `server/Dockerfile` (repository-root context) and `web/Dockerfile` (web context). Local builds and image pull Secrets are not required; image repositories, tags, and digests remain overridable.
- Retain the upstream backend PropertiesLauncher entrypoint so the separately supplied MySQL JDBC driver is loaded.
- Bundles a single-replica `mysql:8.0` StatefulSet by default, matching upstream Compose, with an 8Gi PVC, distinct MySQL selectors, and an authenticated wait init container before backend startup.
- MySQL creates its database and non-root app user. Passwords are generated into a retained Secret and reused through Helm `lookup`, or supplied through `mysql.auth.existingSecret`. Preserve credentials with retained PVCs; password values only initialize empty data directories.
- Offline rendering cannot reuse live Secret values through `lookup`; use an existing Secret reference or explicit credentials when deterministic rendering is required. MySQL data lives in the PVC's `mysql/` subdirectory.
- Set `mysql.enabled: false` to use `externalDatabase`. `mysql.initializeSchema` or `externalDatabase.initializeSchema` controls initialization from the packaged `classpath:db/schema.sql` in the selected mode. Upstream migrations still require schema permissions.
- Injects v3 `STUDIO_*` settings, with bootstrap admin passwords and optional external DB passwords from existing Secrets. No upstream demo passwords are used as fallbacks.
- `auth.existingSecret` bootstraps users on first login to an empty user table; later account changes are stored in MySQL. Session cookies require HTTPS by default; the mgmt example uses `istio-ingress/internal-gateway`.
- Backend startup/liveness use `/livez`; readiness uses `/readyz`, including DB availability. Frontend probes use `/index.html`.
- `frontend-configmap.yaml` renders `files/nginx.conf`, adapting upstream API, Swagger, health, and SSE routing to loopback. Bypass the image's Docker/Podman DNS entrypoint; both containers run without root with writable temp/log volumes.
- Keep one replica for hosted AI sessions unless session routing and schema initialization have been reviewed. MySQL persists application state; local AI workspaces are ephemeral unless extra volumes are configured.
- Publishable chart with a standalone-only mgmt values example; no ArgoCD Application is provided.

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
- Supporting configs include `argocd-values.yaml`, `argocd-virtualservice.yaml`, cluster secrets, projects, and notifications.

ArgoCD-managed mgmt components:

- `elasticvue`
- `redisinsight`
- `kafka-ui`
- `nightingale`

ArgoCD-managed mgmt components are not generated by an ApplicationSet. When adding an ArgoCD-managed component, add a new `applications/<name>.yaml` and a values file in the matching subtree. Standalone examples such as `rocketmq-dashboard` are listed separately under `infrastructure/mgmt` below.

Each mgmt Application uses multiple sources: a chart source and a `ref: values` source for `$values`. The UIs use `$values/infrastructure/mgmt/<chart>-values.yaml`; Nightingale uses `$values/infrastructure/observability/nightingale/nightingale-values.yaml`. Set `ignoreMissingValueFiles: false` because these shared overrides are required. `kafka-ui` also has a third source for its raw VirtualService manifests.

UAT/prod ApplicationSets use a Git directory generator on `infrastructure/app/*`, excluding `infrastructure/app/common`. Each generated Application is single-source, with no `$values` ref. Each app provides colocated `values.yaml` plus `values-uat.yaml` or `values-prod.yaml`, passed in that order with `ignoreMissingValueFiles: false`. The namespace is derived from the chart directory name via `{{ .path.basename }}`.

Publishable charts under `charts/` are not deployed in UAT/prod. UAT/prod only run the in-cluster example apps under `infrastructure/app/`.

### `infrastructure/mgmt`

Shared values files for mgmt-tier UIs.

- `elasticvue`, `redisinsight`, `kafka-ui`, and the standalone `rocketmq-dashboard` example use the `mgmt` namespace.
- Values files for ArgoCD-managed components are consumed both by ArgoCD Applications and by standalone Helm fallback commands.
- ArgoCD is the canonical deployment route; standalone Helm is a fallback/debug path.
- `rocketmq-dashboard-values.yaml` is a standalone-only RocketMQ Studio example with bundled MySQL 8.0 (external optional) and public `logic3579` frontend/backend images. It has no ArgoCD Application; do not add one unless requested.
- `elasticvue` and `redisinsight` use the in-repo `logic3579` Helm repository, with VirtualServices configured through `virtualservice.enabled` and related values.
- `kafka-ui` uses the upstream `kafbat/kafka-ui` chart, not a chart from `charts/`.
- `kafka-ui` uses `infrastructure/mgmt/kafka-ui-values.yaml`; its companion `infrastructure/mgmt/kafka-ui-manifests/virtualservice.yaml` pins `namespace: mgmt` and is rendered by ArgoCD's third source or applied directly in the standalone path.

Nightingale follows the same single-source-of-truth pattern, but its values live under `infrastructure/observability/nightingale/` and it deploys to the `nightingale` namespace.

### `infrastructure/app`

In-cluster example applications for UAT/prod ApplicationSets.

- Contains its own `common` library chart, copied from `charts/common` and pinned independently to `0.3.0`.
- Contains `nginx` (DHI hardened nginx front end) and `alpine` (BusyBox `nc` HTTP server back end) example apps.
- Each app ships `values.yaml`, `values-uat.yaml`, and `values-prod.yaml`.
- These charts are not published to GitHub Pages or OCI.

### `infrastructure/streaming/flink`

Standalone Apache Flink Kubernetes Operator reference.

- Do not add an ArgoCD Application unless explicitly requested.
- Use `FlinkDeployment` Application mode for production jobs.
- Keep checkpoints, savepoints, and HA metadata in object storage.
- Use Kubernetes HA for new references.
- Use Istio VirtualService for the Web UI when needed.
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
- `prometheus-community/`: `prometheus-community/prometheus` chart, server-only, with Alertmanager, kube-state-metrics, node-exporter, and pushgateway subcharts disabled. Minimal single-node alternative to Mimir or VMCluster. Namespace `prom`.
- `opentelemetry/`: OTel Operator, agent/gateway Collector CRs, and Instrumentation CR for Java/Python SDK auto-injection. Collectors export to the Grafana LGTM or VictoriaMetrics stacks, or use remote_write to the plain Prometheus stack for metrics only.
- `nightingale/`: Nightingale plus Categraf, dashboards, and alert rules; pairs with the `prometheus-community/` exporters. Namespace `nightingale`.

Keep all values and Kubernetes manifests for each observability stack flat at `infrastructure/observability/<stack>/`. Filename prefixes identify components. The exception is `nightingale/n9e-ui/`, which stores dashboard and alert-rule JSON content for UI import, not Kubernetes manifests.

### `infrastructure/envoy-gateway`

Kubernetes Gateway API reference manifests using the upstream Envoy Gateway Helm chart (`oci://docker.io/envoyproxy/gateway-helm`).

- Standalone-only for now; do not add an ArgoCD Application unless explicitly requested.
- Parallel exploration path; does not replace existing Istio `VirtualService` routing.
- Uses Gateway API resources: `GatewayClass`, `Gateway`, `HTTPRoute`, and `ReferenceGrant`.
- Keeps internal/external Gateway examples analogous to the current internal/external Istio gateway split.
- Avoid Ingress resources.

### Other Infrastructure References

- `infrastructure/istio/`: gateways, AuthorizationPolicy, and EnvoyFilter access logging.
- `infrastructure/cert-manager/`: TLS automation with Let's Encrypt and GCP Cloud DNS.
- `infrastructure/database/`: ClickHouse with GCS backup, Elasticsearch, and Neo4j.
- `infrastructure/bigdata/`: HBase and MLflow VirtualService configs.
- `infrastructure/streaming/`: overview of the standalone streaming references.

## Deployment Model

`charts/` supports two deployment methods:

1. Helm repository: packaged on push and hosted on `gh-pages`.
2. ArgoCD directory source: ArgoCD points `source.helm` (or a chart entry in `sources`) at paths such as `charts/elasticvue` and resolves `file://../common` with `helm dependency build`.

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

1. Checkout `main` on `ubuntu-24.04`.
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

OCI publishing uses the same `.packages/*.tgz` artifacts as the Pages repository:

| Registry | Push target | Authentication |
| --- | --- | --- |
| GHCR | `oci://ghcr.io/${{ github.repository_owner }}/helm-charts` | Built-in `GITHUB_TOKEN`, with `permissions: packages: write` |
| Docker Hub | `oci://registry-1.docker.io/${{ github.repository_owner }}` | `DOCKERHUB_TOKEN` repository secret |
| Quay | `oci://quay.io/${{ github.repository_owner }}` | `QUAY_TOKEN` repository secret |

All three registries use the GitHub repository owner's username. Only the token varies by registry. Push targets are namespaces; Helm appends the chart name and version. GHCR has the extra `helm-charts/` path segment; Docker Hub and Quay use flat namespaces.

Important release details:

- `index.yaml` is regenerated from scratch from the `.tgz` files in the `gh-pages` worktree.
- Retention is 3 versions per chart, controlled by `RETENTION` in the workflow env.
- Chart removal from `charts/` deletes its `.tgz` files from `gh-pages` on the next workflow run.
- Orphan cleanup reads the embedded chart name with `helm show chart`; regenerating `index.yaml` removes the chart entry, which Artifact Hub picks up on its next scan.
- Retention uses a strict `^<chart-name>-[0-9]` regex and `sort -V` to avoid prefix collisions, such as `api` matching `api-server-*.tgz`.
- OCI registries keep historical tags indefinitely.
- Same-version OCI pushes are left to registry digest deduplication; the workflow does not probe registry tag lists.
- Docker Hub and Quay pushes are skipped when their token secrets are not configured. Tokens are surfaced through job environment variables for step-level `if` conditions.
- All OCI push steps use `continue-on-error: true`, so OCI push failures do not block `gh-pages` publishing.
- `artifacthub-repo.yml` must remain reachable at `https://logic3579.github.io/helm-charts/artifacthub-repo.yml`. Existing ownership verification does not register OCI repositories; register those separately in Artifact Hub's UI if needed.
- GitHub Pages serves the `gh-pages` branch root directly (Settings → Pages → Deploy from a branch → `gh-pages` / `/`). The workflow does not use `actions/deploy-pages`.

Branches:

- `main`: chart source, workflow, docs.
- `gh-pages`: auto-managed chart repository artifacts. Do not edit manually.

## Chart Conventions

- Use `.template` only for files that must be copied to a `.yaml` sibling before applying. Currently this applies to `infrastructure/argocd/notifications/secret.yaml.template`, which receives the Slack webhook URL.
- Files with `<PLACEHOLDER>` tokens are committed as plain `.yaml` and edited in place; do not add `.example` shadow files.
- Use Kubernetes Secrets with `secretKeyRef` or `${VAR_NAME}` env var placeholders for sensitive values.
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
- Prefer a maintained upstream chart over publishing a parallel local chart when one exists, as with `kafbat/kafka-ui`. Wire it through an explicit multi-source ArgoCD Application (upstream chart, `$values` ref, and any raw companion manifests) and shared values for the standalone Helm fallback.

## Infrastructure Conventions

- Observability stack namespaces are short names such as `lgtm`, `vm`, and `otel`.
- Cross-stack service hostnames use `<svc>.<ns>.svc.cluster.local`.
- Values files with `serviceAccount.annotations` should include comments for both AWS IRSA and GCP Workload Identity formats above the annotations map:

  ```yaml
  serviceAccount:
    create: true
    # AWS IRSA:                eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/<comp>-role
    # GCP Workload Identity:   iam.gke.io/gcp-service-account: <comp>@PROJECT_ID.iam.gserviceaccount.com
    annotations: {}
  ```

- Do not add VirtualServices for OTLP-receiving components such as Tempo, VictoriaTraces, and the OpenTelemetry collector. OTLP gRPC does not fit the current HTTP gateway routing; Grafana queries these backends through in-cluster Service URLs.
- Keep `infrastructure/envoy-gateway/` as a standalone Gateway API reference path unless the user explicitly asks to wire it into ArgoCD. Existing charts still use Istio `VirtualService` values; do not retrofit Gateway API templates into `charts/common` as part of Envoy Gateway reference work.
- Keep `infrastructure/streaming/kafka/` and `infrastructure/streaming/flink/` as standalone operator-based reference paths unless the user explicitly asks to wire them into ArgoCD.
- Grafana LGTM uses object storage by default, with GCS `gcs.bucket_name: example-*` placeholders.
- VictoriaMetrics uses local PVCs (`premium-rwo` storageClass) and has no native object storage hot tier. Keep the storage model of each stack; do not retrofit one stack's storage assumptions into the other.
- Nightingale alert-rule JSON files live under `infrastructure/observability/nightingale/n9e-ui/alert-rules/`.
- Nightingale domain files are `common-alerts.json`, `k8s-alert-rules.json`, `istio-alert-rules.json`, `kafka-alerts.json`, and `redis-alerts.json`. Keep middleware-specific rules in their own domain files; do not reintroduce a combined `middleware-alerts.json`.
- Nightingale rule names should use stable prefixes such as `Common -`, `K8S -`, `Istio -`, `Kafka -`, and `Redis -`.
- Kafka and Redis rule examples pin notification routing with `notify_rule_ids: [5]` and `notify_rule_ids: [6]`, respectively.

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
