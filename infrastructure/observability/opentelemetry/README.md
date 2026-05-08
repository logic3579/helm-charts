# OpenTelemetry — Collection Layer

OpenTelemetry sits **upstream of** [grafana-lgtm/](../grafana-lgtm/) and [victoriametrics/](../victoriametrics/) — it isn't a third storage stack. Apps push OTLP into a per-node agent, the agent forwards to a central gateway, and the gateway multiplexes/samples/exports to whichever backend you wire up.

```
┌────────────┐  OTLP gRPC  ┌──────────────┐  OTLP gRPC  ┌──────────────┐  Tempo / Loki / Mimir
│  app pods  ├────────────►│ otel-agent   ├────────────►│ otel-gateway ├──────────►  (default)
│  (Java/Py) │             │  DaemonSet   │             │ Deployment×2 │              OR
└────────────┘             └──────────────┘             └──────────────┘  VictoriaTraces / Logs / Metrics
                                                                          (commented in gateway config)
```

The chart picks `opentelemetry-operator` over `opentelemetry-kube-stack` so the agent and gateway are explicit `OpenTelemetryCollector` CRs you can read as plain YAML.

| Layer | Component | Source | Version |
|-------|-----------|--------|---------|
| Operator | `opentelemetry-operator` Helm chart | `open-telemetry/opentelemetry-operator` | chart `0.112.1` / app `0.150.0` |
| Agent | `OpenTelemetryCollector` CR (mode: daemonset) | this dir | image `0.150.1` |
| Gateway | `OpenTelemetryCollector` CR (mode: deployment, 2 replicas) | this dir | image `0.150.1` |
| Auto-instrumentation | `Instrumentation` CR | this dir | Java 2.13.3, Python 0.55b1 |

## Prerequisites

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
kubectl create namespace otel
```

The operator's mutating admission webhook needs TLS — `operator-values.yaml` enables `cert-manager`-issued certs (default `selfsigned-issuer`). The repo already runs cert-manager (see [../../cert-manager/](../../cert-manager/)).

## Operator

```bash
helm upgrade --install \
  --namespace otel \
  opentelemetry-operator open-telemetry/opentelemetry-operator \
  -f operator-values.yaml \
  --version=0.112.1
```

Installs the operator (2 replicas, anti-affinity) plus the `OpenTelemetryCollector`, `Instrumentation`, and `OpAMPBridge` CRDs.

## Agent (DaemonSet, per-node)

```bash
kubectl apply -n otel -f collector-agent.yaml
```

Receives OTLP gRPC/HTTP from local pods on `4317`/`4318`, scrapes hostmetrics, enriches with `k8sattributes`, and forwards to the gateway via the headless Service `gateway-collector-headless.otel.svc.cluster.local:4317`.

> Kubelet/cAdvisor scraping is **not** enabled here — that's vmagent's / Alloy's job. OTel agent only handles OTLP push paths to avoid double-scrape.

## Gateway (Deployment×2, central)

```bash
kubectl apply -n otel -f collector-gateway.yaml
```

Tail-samples traces (100% of errors + slow requests, 10% of the rest), batches every signal, and exports to **grafana-lgtm by default**:

| Signal | Default exporter | Endpoint |
|--------|------------------|----------|
| Traces | `otlp/tempo` | `tempo-distributor.lgtm.svc.cluster.local:4317` |
| Logs | `otlphttp/loki` | `http://loki-gateway.lgtm.svc.cluster.local/otlp` |
| Metrics | `prometheusremotewrite/mimir` | `http://mimir-gateway.lgtm.svc.cluster.local/api/v1/push` |

To switch to **VictoriaMetrics**:

1. In `collector-gateway.yaml`, uncomment the `otlphttp/victoriatraces`, `otlphttp/victorialogs`, and `prometheusremotewrite/victoriametrics` exporter blocks.
2. In each pipeline under `service.pipelines.{traces,metrics,logs}`, swap the `exporters:` line to the commented VM alternative (already present, just toggle which line is commented).
3. `kubectl apply` the file — the operator will roll the gateway Deployment.

## Auto-instrumentation

```bash
kubectl apply -n otel -f instrumentation.yaml
```

The CR is named `default`. Apps opt in by annotating their pods:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java:   "otel/default"
    instrumentation.opentelemetry.io/inject-python: "otel/default"
```

The operator's mutating webhook injects an init container with the agent JAR / Python autoinstrumentation, plus the right `OTEL_*` env vars so the app emits OTLP to `agent-collector.otel.svc.cluster.local:4318` automatically — no code change required.

Languages enabled in this Instrumentation CR: **Java**, **Python**. To add Node/.NET/Go, append the corresponding `nodejs:` / `dotnet:` / `go:` blocks (see [Operator Instrumentation reference](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api/instrumentations.md)).

## Relationship to Alloy / vmagent / vlagent

OTel collector is **complementary**, not a replacement:

| Path | Tool |
|------|------|
| App SDK push (OTLP) | OTel agent → OTel gateway → backend |
| Prometheus scrape (kubelet, services) | vmagent (vm stack) / Alloy (lgtm stack) |
| Pod log file tail (`/var/log/pods`) | vlagent (vm stack) / Promtail or Alloy (lgtm stack) |

You don't have to pick one. Apps that emit native OTLP go through OTel; everything else continues to use the existing collectors.

## Out of scope this round

- VirtualService for cross-cluster OTLP push (OTLP gRPC and Istio's HTTP gateway don't fit cleanly — same call as Tempo / VictoriaTraces)
- `OpAMPBridge` for fleet management
- Go auto-instrumentation (eBPF-based, separate enablement path)
- `targetallocator` for sharded Prometheus scrape (we delegate metrics to vmagent/Alloy)
