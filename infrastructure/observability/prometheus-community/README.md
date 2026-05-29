# prometheus-community charts

Reference installs for charts from the `prometheus-community` Helm repo:

| Chart                                         | Chart version | App version | Purpose |
|-----------------------------------------------|---------------|-------------|---------|
| `prometheus-community/prometheus`             | `29.9.0`      | `v3.12.0`   | TSDB + query API (server-only here — subcharts disabled) |
| `prometheus-community/kube-state-metrics`     | `7.4.0`       | `v2.19.0`   | Cluster-object metrics (Deployments, Pods, etc.) |
| `prometheus-community/prometheus-mysql-exporter` | `2.13.1`   | `v0.19.0`   | MySQL replication / InnoDB / query metrics on :9104 |
| `prometheus-community/prometheus-redis-exporter` | `6.24.0`   | `v1.84.0`   | Redis instrumentation on :9121 |

The Prometheus server is a minimal, single-replica TSDB alternative to the horizontally-scaled [grafana-lgtm/](../grafana-lgtm/) (Mimir) and [victoriametrics/](../victoriametrics/) (VMCluster) tiers. The three exporters are deployed alongside it so the server's annotation-driven `kubernetes-pods` scrape job picks them up automatically — Operator-free, no ServiceMonitor required.

The `prometheus` chart bundles `alertmanager` / `prometheus-node-exporter` / `kube-state-metrics` / `prometheus-pushgateway` subcharts, but this values file sets `<subchart>.enabled: false` on all of them. KSM is installed separately (see below) so it can also be scraped by Categraf, vmagent, or any other consumer.

## Prerequisites

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
kubectl create namespace prom
```

Installs into the `prom` namespace; the VirtualService references `prom.svc.cluster.local`.

## Install — Prometheus server

```bash
helm show values prometheus-community/prometheus --version=29.9.0 > prometheus-values.yaml
helm upgrade --install \
  --namespace prom \
  prometheus prometheus-community/prometheus \
  -f prometheus-values.yaml \
  --version=29.9.0

kubectl apply -n prom -f prometheus-virtualservice.yaml
```

Renders one workload:

- `prometheus-server` Deployment (1 replica, 50Gi `premium-rwo` PVC, 15d retention, non-root + readOnlyRootFilesystem)

Plus the chart's standard configmap-reload sidecar and a ConfigMap holding `prometheus.yml`.

## Install — kube-state-metrics

```bash
helm upgrade --install \
  --namespace prom \
  kube-state-metrics prometheus-community/kube-state-metrics \
  -f kube-state-metrics-values.yaml \
  --version=7.4.0
```

Deployment on `tier: mgmt` exposing `:8080/metrics`. Service carries `prometheus.io/scrape="true"` so the Prometheus server picks it up via the chart's default `kubernetes-pods` scrape job. The bundled ServiceMonitor is off (`prometheus.monitor.enabled: false`) — annotation-based scrape only, matching the rest of this stack.

## Install — prometheus-mysql-exporter

```bash
helm upgrade --install \
  --namespace prom \
  prometheus-mysql-exporter prometheus-community/prometheus-mysql-exporter \
  -f prometheus-mysql-exporter-values.yaml \
  --version=2.13.1
```

Targets `mysql.database.svc.cluster.local:3306` with user `exporter`. Inline `mysql.pass: "<REPLACE_ME>"` is a dev placeholder — for production, point `mysql.existingPasswordSecret.{name,key}` at a Kubernetes Secret (preferred) or `mysql.existingConfigSecret` at a full `my.cnf` Secret. Service exposes `:9104` with `prometheus.io/scrape` annotations.

## Install — prometheus-redis-exporter

```bash
helm upgrade --install \
  --namespace prom \
  prometheus-redis-exporter prometheus-community/prometheus-redis-exporter \
  -f prometheus-redis-exporter-values.yaml \
  --version=6.24.0
```

Targets `redis://redis.database.svc.cluster.local:6379` (override `redisAddress` for your cluster). When Redis requires auth, set `auth.enabled: true` and reference a Secret via `auth.secret.{name,key}` — avoid inline `auth.redisPassword`. Service exposes `:9121` with `prometheus.io/scrape` annotations.

## Scrape configuration

The chart's top-level `scrapeConfigs` map ships defaults for apiserver, kubelet, cAdvisor, kubernetes-pods (annotation-discovered), and kubernetes-services. The bundled `prometheus.yml` is assembled by the chart from `server.global` + `scrapeConfigs` + `serverFiles.{alerting_rules,recording_rules}.yml` — this values file overrides only `server.global` to add `external_labels.cluster=example-cluster` and a 30s scrape interval, leaving every default scrape job intact.

To add jobs, append entries under `scrapeConfigs:` (each map key becomes the `job_name`). To disable a default job, set its `enabled: false`. The configmap-reload sidecar picks up edits without a pod restart — `web.enable-lifecycle` is in the chart's default `server.extraFlags`.

For ServiceMonitor-style declarative scrape config, use `kube-prometheus-stack` instead — this chart is intentionally Operator-free.

## Alerting rules

Drop alerting and recording rule groups into `serverFiles.alerting_rules.yml` / `recording_rules.yml` — empty by default. Alertmanager is disabled here, so rule alerts won't go anywhere until you either (a) flip `alertmanager.enabled: true` and add an `alertmanagerFiles.alertmanager.yml` config, or (b) point `server.alertmanagers` at an existing Alertmanager elsewhere.

## Enabling the disabled prometheus subcharts

The `prometheus` chart bundles Alertmanager, node-exporter, and pushgateway subcharts that this stack leaves off. KSM is intentionally not enabled here either — it's installed standalone above so non-Prometheus consumers (Categraf, vmagent) can also scrape it. To turn any of these on as bundled subcharts of the `prometheus` release instead, patch `prometheus-values.yaml`:

```yaml
# Alertmanager — adds StatefulSet + Service + headless gossip service.
alertmanager:
  enabled: true
  replicaCount: 2
  persistence:
    storageClass: premium-rwo
    size: 5Gi

# node-exporter — DaemonSet exposing host metrics on every node.
prometheus-node-exporter:
  enabled: true

# Pushgateway — only for batch jobs that can't be scraped.
prometheus-pushgateway:
  enabled: true
```

When enabling Alertmanager, also drop in an `alertmanager-virtualservice.yaml` (mirror the existing `prometheus-virtualservice.yaml`, swap the service host to `prometheus-alertmanager.prom.svc.cluster.local`).

## High availability

This values file runs **1 Prometheus replica**. Prometheus has no built-in dedup, so HA requires:

- **Option A** — flip `server.statefulSet.enabled: true` and set `server.replicaCount: 2`; both pods scrape independently with PVCs per replica. Pair with a downstream dedup layer (Thanos sidecar, or `remoteWrite` to Mimir / VictoriaMetrics which dedupe natively). The commented `server.remoteWrite` block in the values file points at both backends — uncomment to forward.
- **Option B** — keep 1 replica and rely on PVC durability. Acceptable for non-critical environments.

> If you need horizontal scale-out with no external dedup, switch stacks to [victoriametrics/](../victoriametrics/) (VMCluster) or [grafana-lgtm/](../grafana-lgtm/) (Mimir). Prometheus alone does not shard.

## Storage prerequisites

Prometheus keeps hot data on **local PVCs** (same model as VictoriaMetrics — no object-storage hot tier). The `serviceAccounts.server.annotations` block ships commented-out **AWS IRSA** and **GCP Workload Identity** examples; uncomment one only if you later add Thanos block upload or cross-cloud remote_write that needs cloud IAM.

| Component | Volume size | Retention |
|-----------|-------------|-----------|
| server    | 50Gi        | 15d (`retention: 15d`) |

## Wiring into Grafana

Grafana (in the `lgtm` namespace) reads Prometheus via the in-cluster service URL `http://prometheus-server.prom.svc.cluster.local`. A pre-wired datasource example is in [`../grafana-lgtm/grafana-values.yaml`](../grafana-lgtm/grafana-values.yaml) — uncomment the `Prometheus` block under `datasources`.

## When to pick Prometheus over Mimir / VictoriaMetrics

| Need | Pick |
|------|------|
| Smallest moving-parts metrics setup | **Prometheus** (this stack) |
| Horizontal write/read scale, multi-tenant | Mimir (`grafana-lgtm/`) or VMCluster (`victoriametrics/`) |
| Long-term object storage (GCS/S3) | Mimir |
| Cheapest single-node TSDB with high compression | VictoriaMetrics (`vm-single` — different chart) or this stack |
| ServiceMonitor / PodMonitor CRDs | Switch to `kube-prometheus-stack` (Operator-based) |
