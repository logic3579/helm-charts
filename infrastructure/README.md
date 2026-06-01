# Infrastructure Reference Configs

Production-ready reference configurations for Kubernetes cluster infrastructure components.

## Components

| Directory                          | Description                                                                                  |
| ---------------------------------- | -------------------------------------------------------------------------------------------- |
| [argocd/](./argocd/)               | Multi-cluster GitOps (ApplicationSets, GKE Workload Identity, Slack notifications)           |
| [bigdata/](./bigdata/)             | Flink, HBase, MLflow VirtualService configs                                                  |
| [cert-manager/](./cert-manager/)   | TLS automation via Let's Encrypt + GCP Cloud DNS                                             |
| [database/](./database/)           | ClickHouse (with GCS backup), Elasticsearch, Neo4j                                           |
| [istio/](./istio/)                 | Service mesh gateways, AuthorizationPolicy, EnvoyFilter access logging                       |
| [mgmt/](./mgmt/)                   | Management UIs (Kafka-UI, Cerebro, RedisInsight, RocketMQ Exporter)                          |
| [observability/](./observability/) | Observability stacks — Grafana LGTM, VictoriaMetrics, Prometheus, OpenTelemetry, Nightingale |
| [streaming/](./streaming/)         | Kafka broker service aliases                                                                 |

## Quick Start

1. Start with [argocd/](./argocd/) for GitOps-based deployments
2. Set up [istio/](./istio/) gateways for traffic management
3. Configure [cert-manager/](./cert-manager/) for TLS
4. Add an [observability/](./observability/) stack — pick Grafana LGTM or VictoriaMetrics for metrics, logs, traces

Each directory contains its own `README.md` with detailed setup instructions.

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
helm package ./charts/go-app
helm package ./charts/go-app --destination ./.packages
```

**Push to an OCI registry**:

```bash
# Authenticate first (Docker creds also work for most registries)
helm registry login ghcr.io -u <user> --password-stdin <<< "$GHCR_TOKEN"

# Push the archive — the OCI path is the *namespace*, not the chart name
helm push go-app-0.1.0.tgz oci://ghcr.io/<org>/charts
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

## Conventions

- Files ending in `.example` require placeholder replacement before use
- Files ending in `.template` contain secret templates — fill in and apply separately
- All secrets use `secretKeyRef` or env var placeholders — no hardcoded credentials
- Container images are pinned to specific versions
