# Infrastructure Reference Configs

Production-ready reference configurations for Kubernetes cluster infrastructure components.

## Components

| Directory | Description |
|-----------|-------------|
| [argocd/](./argocd/) | Multi-cluster GitOps (ApplicationSets, GKE Workload Identity, Slack notifications) |
| [istio/](./istio/) | Service mesh gateways, AuthorizationPolicy, EnvoyFilter access logging |
| [cert-manager/](./cert-manager/) | TLS automation via Let's Encrypt + GCP Cloud DNS |
| [monitoring/](./monitoring/) | Nightingale + Categraf + Grafana (dashboards, alert rules) |
| [logging/](./logging/) | Loki for centralized log aggregation |
| [database/](./database/) | ClickHouse (with GCS backup), Elasticsearch, Neo4j |
| [streaming/](./streaming/) | Kafka broker service aliases |
| [bigdata/](./bigdata/) | Flink, HBase, MLflow VirtualService configs |
| [mgmt/](./mgmt/) | Management UIs (Kafka-UI, Cerebro, RedisInsight, RocketMQ Exporter) |

## Quick Start

1. Start with [argocd/](./argocd/) for GitOps-based deployments
2. Set up [istio/](./istio/) gateways for traffic management
3. Configure [cert-manager/](./cert-manager/) for TLS
4. Add [monitoring/](./monitoring/) and [logging/](./logging/) for observability

Each directory contains its own `README.md` with detailed setup instructions.

## Conventions

- Files ending in `.example` require placeholder replacement before use
- Files ending in `.template` contain secret templates — fill in and apply separately
- All secrets use `secretKeyRef` or env var placeholders — no hardcoded credentials
- Container images are pinned to specific versions
