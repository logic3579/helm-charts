[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-repo-blue)](https://artifacthub.io/) [![Release Charts](https://github.com/logic3579/helm-charts/actions/workflows/release.yaml/badge.svg?branch=main)](https://github.com/logic3579/helm-charts/actions/workflows/release.yaml)

## Repository Overview

This repo provides two things:

1. **Publishable Helm charts** in [`charts/`](./charts/) — released via GitHub Pages (chart `.tgz` hosted directly on the `gh-pages` branch)
2. **Infrastructure examples** in [`infrastructure/`](./infrastructure/) — cluster infrastructure reference configs

## Available Charts

| Chart | Description | Default Port |
|-------|-------------|-------------|
| [common](./charts/common) | Shared library chart (labels, VirtualService, PDB, HPA, ServiceAccount) — embedded into app charts, not published to the registry | — |
| [elasticvue](./charts/elasticvue) | Web UI for Elasticsearch / OpenSearch | 8080 |
| [kafka-ui](./charts/kafka-ui) | Web UI for monitoring and managing Apache Kafka clusters | 8080 |
| [nightingale](./charts/nightingale) | Nightingale (n9e) cloud-native monitoring system — repackaged from [`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm) | 80 |
| [redisinsight](./charts/redisinsight) | Redis Inc.'s official web UI for Redis (stateful — SQLite at `/data`) | 5540 |
| [rocketmq-exporter](./charts/rocketmq-exporter) | Apache RocketMQ Prometheus exporter | 5557 |

## Install from Helm Repo

```bash
# Add the chart repository
helm repo add logic3579 https://logic3579.github.io/helm-charts

# Update repository
helm repo update

# Search for available charts
helm search repo logic3579

# Install a chart
helm install my-kafka-ui logic3579/kafka-ui -f my-values.yaml
```

## Install via OCI

Each chart is also mirrored to three OCI registries on every release. No
`helm repo add` needed — pull directly by URL:

```bash
# GHCR (primary mirror; same namespace as the Pages repo)
helm install my-kafka-ui oci://ghcr.io/logic3579/helm-charts/kafka-ui --version 0.1.1 -f my-values.yaml

# Docker Hub
helm install my-kafka-ui oci://registry-1.docker.io/logic3579/kafka-ui --version 0.1.1 -f my-values.yaml

# Quay
helm install my-kafka-ui oci://quay.io/logic3579/kafka-ui --version 0.1.1 -f my-values.yaml
```

The Pages-based Helm repo remains the source of truth; OCI registries are
downstream mirrors with the same `.tgz` content.

## Deploy from Local Chart

```bash
# Update dependencies (required for charts with common library)
helm dependency update charts/kafka-ui

# Template and inspect rendered manifests
helm template my-release charts/kafka-ui -f charts/kafka-ui/values.yaml

# Install from local chart
helm install my-release charts/kafka-ui -f my-values.yaml
```

## Release a New Version

To release a new version of the charts:

1. Modify chart source under `charts/`
2. **Bump `version` in `Chart.yaml`** — this is the release trigger
3. Commit and push to `main`

```bash
# Example: bump version to 0.3.0
# Edit charts/kafka-ui/Chart.yaml
# Set version: 0.3.0

git add charts/
git commit -m "release: bump kafka-ui to v0.3.0"
git push origin main
```

The GitHub Actions workflow will automatically:
- Lint and package the charts
- Push the `.tgz` artifacts and regenerated `index.yaml` to the `gh-pages` branch (no Git tags, no GitHub Releases)
- Prune older versions, keeping only the latest **3 versions per chart** on `gh-pages`
- GitHub Pages serves the `gh-pages` branch directly

## Chart Features

`common`-based application charts (`elasticvue`, `kafka-ui`, `redisinsight`, `rocketmq-exporter`) support:

| Feature | Key | Notes |
|---------|-----|-------|
| Liveness / Readiness probe | `livenessProbe`, `readinessProbe` | Configurable path, timing, thresholds |
| Startup probe | `startupProbe` | Optional |
| Horizontal Pod Autoscaler | `autoscaling.*` | CPU and memory targets |
| Pod Disruption Budget | `podDisruptionBudget.*` | `minAvailable` or `maxUnavailable` (mutually exclusive) |
| Istio VirtualService | `virtualservice.*` | CORS origins support `exact`/`prefix`/`regex` match types |
| Extra volumes | `volumes`, `volumeMounts` | Inject arbitrary volumes (e.g. tmpfs for `/tmp`) |
| ConfigMap / Secret | `configMap.*`, `secret.*` | Secret values are base64-encoded at render time — use ESO for production |

`nightingale` is a vendored upstream chart and does NOT share this template surface — its values schema follows [`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm) directly. Companion infra manifests (Categraf, Istio VirtualService, dashboards, alert rules) live under [`infrastructure/observability/nightingale/`](./infrastructure/observability/nightingale).

## ArgoCD Integration

The `charts/` directory can also be used directly with ArgoCD. Point ArgoCD to a chart path (e.g., `charts/kafka-ui`) and provide deployment-specific values in the Application's `values` field.

## Helm chart workflows

The `helm show / pull / push` family accepts either an OCI reference or a `<repo>/<chart>` shorthand once the repo is added. Useful when picking a version, auditing a chart before install, vendoring it locally, or publishing your own.

**OCI registry** (Bitnami's primary distribution, GHCR, ECR, GAR, ...):

```bash
# Inspect chart metadata / rendered manifest / default values
helm show chart    oci://registry-1.docker.io/bitnamicharts/kafka
helm show manifest oci://registry-1.docker.io/bitnamicharts/kafka
helm show values   oci://registry-1.docker.io/bitnamicharts/kafka

# Pin a specific version
helm show values oci://registry-1.docker.io/bitnamicharts/kafka --version=32.4.3 > kafka-values.yaml

# Download the chart archive locally (add --untar to extract into ./<name>/)
helm pull oci://registry-1.docker.io/bitnamicharts/kafka --version=32.4.3
helm pull oci://registry-1.docker.io/bitnamicharts/kafka --version=32.4.3 --untar --destination ./charts
```

**Traditional Helm repo** (`https://<host>/index.yaml`):

```bash
# Add and refresh the repo's index.yaml cache
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# List versions known in the local cache (no OCI equivalent — use `crane ls` there)
helm search repo bitnami/kafka --versions

# Same show commands, addressed as <repo>/<chart>
helm show chart    bitnami/kafka
helm show manifest bitnami/kafka
helm show values   bitnami/kafka

# Pin a specific version
helm show values bitnami/kafka --version=32.4.3 > kafka-values.yaml

# Download the chart archive locally (add --untar to extract into ./<name>/)
helm pull bitnami/kafka --version=32.4.3
helm pull bitnami/kafka --version=32.4.3 --untar --destination ./charts
```

### Packaging and publishing

`helm package` produces a `<name>-<version>.tgz` from a local chart directory. The publish step differs by registry style:

```bash
# Package a local chart (name + version come from Chart.yaml)
helm package ./charts/kafka-ui
helm package ./charts/kafka-ui --destination ./.packages
```

**Push to an OCI registry**:

```bash
# Authenticate first (Docker creds also work for most registries)
helm registry login ghcr.io -u <user> --password-stdin <<< "$GHCR_TOKEN"

# Push the archive — the OCI path is the *namespace*, not the chart name
helm push kafka-ui-0.1.0.tgz oci://ghcr.io/<org>/charts
```

**Publish to a traditional Helm repo**: there is no `helm push` for HTTP repos. Copy the `.tgz` onto a static host (S3, GCS, GitHub Pages, ChartMuseum) and regenerate `index.yaml`:

```bash
# Regenerate or merge the index against the directory containing the .tgz files
helm repo index ./gh-pages --url https://logic3579.github.io/helm-charts
helm repo index ./gh-pages --url https://logic3579.github.io/helm-charts --merge ./gh-pages/index.yaml
```

This repo's release workflow (`.github/workflows/release.yaml`) automates that flow against the `gh-pages` branch.

### crane — registry-level inspection

`crane` (from [`go-containerregistry`](https://github.com/google/go-containerregistry)) works against any OCI registry — both chart artifacts and container images:

```bash
# List available tags
crane ls registry-1.docker.io/bitnamicharts/kafka

# Resolve a tag to an immutable digest (use it to pin image.tag in values.yaml)
crane digest docker.io/bitnami/kafka:3.8.0

# Show the OCI manifest (layers, mediaType, annotations)
crane manifest docker.io/bitnami/kafka:3.8.0

# Show the image config (entrypoint, env, labels, exposed ports)
crane config docker.io/bitnami/kafka:3.8.0 | jq

# Mirror an image to a private registry (air-gapped clusters, pull-through cache)
crane copy docker.io/bitnami/kafka:3.8.0 registry.internal/bitnami/kafka:3.8.0
```
