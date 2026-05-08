# VictoriaMetrics Stack

Metrics + Logs + Traces on the VictoriaMetrics suite — a parallel alternative to the Grafana LGTM stack.

| Layer    | Component   | Chart                            | Chart version | App version |
|----------|-------------|----------------------------------|---------------|-------------|
| Metrics  | VMCluster   | `vm/victoria-metrics-cluster`    | `0.41.2`      | `1.142.0`   |
| Metrics  | vmagent     | `vm/victoria-metrics-agent`      | `0.38.0`      | `1.141.0`   |
| Metrics  | vmalert     | `vm/victoria-metrics-alert`      | `0.39.0`      | `1.141.0`   |
| Gateway  | vmauth      | bundled in `victoria-metrics-cluster` | —        | `1.142.0`   |
| Logs     | VictoriaLogs | `vm/victoria-logs-single`       | `0.12.4`      | `1.50.0`    |
| Logs     | vlagent     | `vm/victoria-logs-collector`     | `0.3.3`       | `v1.50.0`   |
| Traces   | VictoriaTraces | `vm/victoria-traces-single`   | `0.0.7`       | `0.7.0`     |

## Prerequisites

```bash
helm repo add vm https://victoriametrics.github.io/helm-charts --force-update
kubectl create namespace vm
```

All releases install into the `vm` namespace; VirtualServices reference `vm.svc.cluster.local` service hosts.

## VMCluster (with bundled vmauth)

```bash
helm upgrade --install \
  --namespace vm \
  vmcluster vm/victoria-metrics-cluster \
  -f vmcluster-values.yaml \
  --version=0.41.2

kubectl apply -n vm -f vmauth-virtualservice.yaml
```

Renders four workloads: vmstorage StatefulSet (2 × 100Gi premium-rwo), vmselect Deployment (2), vminsert Deployment (2), vmauth Deployment (2). vmauth fronts `/insert/*` → vminsert and `/select|/api|/vmui|/prometheus` → vmselect using the chart's built-in `{{ .vm.read }}` / `{{ .vm.write }}` template helpers.

## vmagent

```bash
helm upgrade --install \
  --namespace vm \
  vmagent vm/victoria-metrics-agent \
  -f vmagent-values.yaml \
  --version=0.38.0
```

Two-replica Deployment, scrapes the chart's default targets (apiserver, kubelet, cAdvisor, k8s services), and `prometheus.remote_write`s to vmauth at `/insert/0/prometheus/api/v1/write`. Both replicas push duplicates; vmstorage dedupes via `dedup.minScrapeInterval`.

## vmalert

```bash
helm upgrade --install \
  --namespace vm \
  vmalert vm/victoria-metrics-alert \
  -f vmalert-values.yaml \
  --version=0.39.0
```

Evaluates rules against vmselect (read path) and pushes recording-rule output back through vmauth (write path). Bundled Alertmanager is **disabled** — bring your own (Slack/PagerDuty etc.) and fill in `server.notifier.url` plus rule groups.

## VictoriaLogs

```bash
helm upgrade --install \
  --namespace vm \
  victorialogs vm/victoria-logs-single \
  -f victorialogs-values.yaml \
  --version=0.12.4

kubectl apply -n vm -f victorialogs-virtualservice.yaml
```

Single-node StatefulSet (50Gi premium-rwo, 30d retention). The VS exposes the full HTTP API on port 9428 — `/insert/loki/api/v1/push`, `/insert/jsonline`, `/select/logsql/query`.

## vlagent (logs collector)

```bash
helm upgrade --install \
  --namespace vm \
  vlagent vm/victoria-logs-collector \
  -f vlagent-values.yaml \
  --version=0.3.3
```

DaemonSet using `vlagent` with `-kubernetesCollector` enabled. Tails `/var/log/pods/*.log` on each node and writes to `victorialogs-server.vm.svc.cluster.local:9428`.

For HTTP relay / cross-cluster forwarding instead of file tailing, use `vm/victoria-logs-agent` (different chart, Deployment shape).

## VictoriaTraces

```bash
helm upgrade --install \
  --namespace vm \
  victoriatraces vm/victoria-traces-single \
  -f victoriatraces-values.yaml \
  --version=0.0.7
```

> **No VirtualService** — same call as Tempo: trace push uses OTLP/HTTP at `/api/v1/otlp/v1/traces` on the distributor Service directly (port 10428). Native gRPC OTLP isn't supported; use Alloy or an OpenTelemetry Collector to bridge gRPC → HTTP if your SDKs only emit gRPC.

## Storage prerequisites

VictoriaMetrics components keep hot data on **local PVCs**, not object storage — so values files don't have a `gcs:` block like the LGTM stack does. Each stateful workload binds a `premium-rwo` PVC:

| Component      | Volume size | Retention |
|----------------|-------------|-----------|
| vmstorage      | 100Gi × 2   | 3 months (`retentionPeriod: "3"`) |
| VictoriaLogs   | 50Gi        | 30d (`retentionPeriod: 30d`) |
| VictoriaTraces | 50Gi        | 30d |

For long-term backup to S3/GCS, enable `vmstorage.vmbackupmanager` (commented in `vmcluster-values.yaml`) — it requires the **VictoriaMetrics enterprise** image. The OSS path is the standalone `vmbackup` CronJob, not bundled in this round.

The `serviceAccount.annotations` block in each values file ships commented-out **AWS IRSA** and **GCP Workload Identity** examples — uncomment one and fill in once you wire up vmbackup or any S3/GCS-bound feature.
