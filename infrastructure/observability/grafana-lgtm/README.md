# Grafana LGTM Stack

Loki + Grafana + Tempo + Mimir — Grafana Labs' open-source observability stack.

| Layer    | Component | Chart                          | Chart version | App version |
|----------|-----------|--------------------------------|---------------|-------------|
| Logs     | Loki      | `grafana/loki`                 | `6.34.0`      | `3.5.3`     |
| Logs     | Promtail  | `grafana/promtail`             | `6.17.0`      | `3.5.1`     |
| Telemetry collector | Alloy | `grafana/alloy`           | `1.8.1`       | `v1.16.1`   |
| Metrics  | Mimir     | `grafana/mimir-distributed`    | `6.0.6`       | `3.0.4`     |
| Traces   | Tempo     | `grafana/tempo-distributed`    | `1.61.2`      | `2.9.0`     |
| UI       | Grafana   | `grafana/grafana`              | `10.5.14`     | `12.3.1`    |

## Prerequisites

```bash
helm repo add grafana https://grafana.github.io/helm-charts --force-update
kubectl create namespace lgtm
```

All Helm releases below install into the `lgtm` namespace, and VirtualServices reference `lgtm.svc.cluster.local` service hosts.

## Loki

```bash
helm show values grafana/loki --version=6.34.0 > loki-values.yaml
helm upgrade --install \
  --namespace lgtm \
  loki grafana/loki \
  -f loki-values.yaml \
  --version=6.34.0

kubectl apply -n lgtm -f loki-virtualservice.yaml
```

## Mimir

```bash
helm show values grafana/mimir-distributed --version=6.0.6 > mimir-values.yaml
helm upgrade --install \
  --namespace lgtm \
  mimir grafana/mimir-distributed \
  -f mimir-values.yaml \
  --version=6.0.6

kubectl apply -n lgtm -f mimir-virtualservice.yaml
```

## Tempo

```bash
helm show values grafana/tempo-distributed --version=1.61.2 > tempo-values.yaml
helm upgrade --install \
  --namespace lgtm \
  tempo grafana/tempo-distributed \
  -f tempo-values.yaml \
  --version=1.61.2
```

> No VirtualService for Tempo: trace ingestion uses OTLP gRPC/HTTP directly against the distributor Service (port `4317`/`4318`); the nginx gateway is only needed for the query API, which Grafana hits intra-cluster.

## Grafana

```bash
helm show values grafana/grafana --version=10.5.14 > grafana-values.yaml
helm upgrade --install \
  --namespace lgtm \
  grafana grafana/grafana \
  -f grafana-values.yaml \
  --version=10.5.14

kubectl apply -n lgtm -f grafana-virtualservice.yaml
```

The values file pre-wires Loki, Mimir, and Tempo as datasources via in-cluster service URLs (`{loki,mimir,tempo}-gateway.lgtm.svc.cluster.local`). Grafana is exposed via the **external** Istio gateway; Loki and Mimir gateways stay on the **internal** gateway.

## Telemetry collection — pick one

### Alloy (recommended)

Modern unified collector for logs, metrics, and traces. Replaces Promtail + Grafana Agent.

```bash
helm show values grafana/alloy --version=1.8.1 > alloy-values.yaml
helm upgrade --install \
  --namespace lgtm \
  alloy grafana/alloy \
  -f alloy-values.yaml \
  --version=1.8.1
```

Runs as a DaemonSet, tails pod logs to Loki, scrapes kubelet metrics to Mimir, and accepts OTLP traces on `:4317` (gRPC) / `:4318` (HTTP) forwarded to Tempo.

### Promtail (logs only, legacy)

Promtail is in maintenance mode upstream — prefer Alloy for new deployments.

```bash
helm show values grafana/promtail --version=6.17.0 > promtail-values.yaml
helm upgrade --install \
  --namespace lgtm \
  promtail grafana/promtail \
  -f promtail-values.yaml \
  --version=6.17.0
```

## Storage prerequisites

Loki, Mimir, and Tempo all default to **GCS** in this configuration. Create the buckets before installing, then grant access by attaching IAM credentials to each component's ServiceAccount:

| Component | Bucket placeholders |
|-----------|---------------------|
| Loki      | `example-loki-chunks`, `example-loki-ruler`, `example-loki-admin` |
| Mimir     | `example-mimir`, `example-mimir-blocks`, `example-mimir-ruler`, `example-mimir-alertmanager` |
| Tempo     | `example-tempo-traces` |

Each values file's `serviceAccount.annotations` block carries example annotations for both **AWS IRSA** and **GCP Workload Identity** — uncomment and fill in the one matching your platform. For S3 / Azure Blob, replace the `gcs:` storage block with the upstream chart's `s3:` / `azure:` equivalent.
