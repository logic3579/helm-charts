# Infrastructure Reference Configs

Production-ready reference configurations for Kubernetes cluster infrastructure components.

## Components

| Directory                          | Description                                                                                  |
| ---------------------------------- | -------------------------------------------------------------------------------------------- |
| [app/](./app/)                     | In-cluster example apps (nginx + alpine) for the uat/prod ApplicationSets, plus a private `common` library copy |
| [argocd/](./argocd/)               | Multi-cluster GitOps — per-component Applications on mgmt + ApplicationSets on uat/prod, Workload Identity, Slack notifications |
| [bigdata/](./bigdata/)             | Flink, HBase, MLflow VirtualService configs                                                  |
| [cert-manager/](./cert-manager/)   | TLS automation via Let's Encrypt + GCP Cloud DNS                                             |
| [database/](./database/)           | ClickHouse (with GCS backup), Elasticsearch, Neo4j                                           |
| [istio/](./istio/)                 | Service mesh gateways, AuthorizationPolicy, EnvoyFilter access logging                       |
| [mgmt/](./mgmt/)                   | Shared values files for mgmt-tier UIs + rocketmq-exporter — consumed by both ArgoCD Applications (`argocd/applications/`) and the standalone helm fallback documented in `mgmt/README.md` |
| [observability/](./observability/) | Observability stacks — Grafana LGTM, VictoriaMetrics, Prometheus, OpenTelemetry, Nightingale |
| [streaming/](./streaming/)         | Kafka broker service aliases                                                                 |

## Quick Start

1. Start with [argocd/](./argocd/) for GitOps-based deployments
2. Set up [istio/](./istio/) gateways for traffic management
3. Configure [cert-manager/](./cert-manager/) for TLS
4. Add an [observability/](./observability/) stack — pick Grafana LGTM or VictoriaMetrics for metrics, logs, traces

Each directory contains its own `README.md` with detailed setup instructions.

## Conventions

- Files ending in `.example` require placeholder replacement before use
- Files ending in `.template` contain secret templates — fill in and apply separately
- All secrets use `secretKeyRef` or env var placeholders — no hardcoded credentials
- Container images are pinned to specific versions
