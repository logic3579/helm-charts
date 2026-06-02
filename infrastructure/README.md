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
| [mgmt/](./mgmt/)                   | Management UIs (Elasticvue, Kafka-UI, RedisInsight, RocketMQ Exporter) via `logic3579`    |
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
