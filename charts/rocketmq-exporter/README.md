# rocketmq-exporter

A Helm chart for [Apache RocketMQ Exporter](https://github.com/apache/rocketmq-exporter) — a Prometheus exporter for Apache RocketMQ.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.x
- A reachable RocketMQ NameServer
- (Optional) Prometheus Operator — to use the bundled `ServiceMonitor`
- (Optional) Istio for VirtualService traffic routing

## Install

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update

helm install rocketmq-exporter logic3579/rocketmq-exporter \
  --set rocketmq.namesrvAddr=rocketmq-namesrv.streaming.svc:9876 \
  --set rocketmq.rocketmqVersion=4_9_4
```

## Parameters

### Image

| Parameter          | Description                                 | Default                   |
| ------------------ | ------------------------------------------- | ------------------------- |
| `image.repository` | Container image repository                  | `apache/rocketmq-exporter`|
| `image.tag`        | Image tag (defaults to `.Chart.AppVersion`) | `""`                      |
| `image.pullPolicy` | Image pull policy                           | `IfNotPresent`            |

### RocketMQ exporter settings

Each key below is injected as `ROCKETMQ_CONFIG_<UPPER_KEY>` via Spring Boot's relaxed binding.

| Parameter                   | Description                                                                              | Default            |
| --------------------------- | ---------------------------------------------------------------------------------------- | ------------------ |
| `rocketmq.namesrvAddr`      | NameServer address(es). Comma/semicolon-separated for clusters (e.g. `ns-a:9876;ns-b:9876`) | `127.0.0.1:9876`   |
| `rocketmq.rocketmqVersion`  | Broker version (`4_3_2`, `4_4_0`, `4_9_4`, …)                                            | `4_9_4`            |
| `rocketmq.webTelemetryPath` | Prometheus metrics path                                                                  | `/metrics`         |
| `rocketmq.enableCollect`    | Actively collect metrics                                                                 | `true`             |
| `rocketmq.outOfTimeSeconds` | Cache clear timeout when no broker updates received (seconds)                            | `60`               |
| `rocketmq.extraConfig`      | Free-form extra exporter settings → `ROCKETMQ_CONFIG_<UPPER_KEY>`                        | `{}`               |

```yaml
rocketmq:
  extraConfig:
    taskCount: 10        # → ROCKETMQ_CONFIG_TASKCOUNT=10
```

### Authentication (RocketMQ ACL)

For RocketMQ ≥4.4.0 with ACL enabled, credentials come from a Kubernetes Secret.

| Parameter             | Description                                                                                  | Default |
| --------------------- | -------------------------------------------------------------------------------------------- | ------- |
| `auth.enabled`        | Enable ACL (sets `ROCKETMQ_CONFIG_ENABLEACL=true`, injects `accessKey` / `secretKey`)        | `false` |
| `auth.existingSecret` | Existing Secret with keys `accessKey` and `secretKey`                                        | `""`    |

When `auth.enabled=true` and `auth.existingSecret` is empty, the chart-managed Secret (`{{ include "common.fullname" . }}`) is used — also set `secret.enabled=true` with `secret.data.{accessKey,secretKey}` in that case.

### Common Parameters

| Parameter                   | Description                                | Default     |
| --------------------------- | ------------------------------------------ | ----------- |
| `replicaCount`              | Number of replicas                         | `1`         |
| `service.type`              | Service type                               | `ClusterIP` |
| `service.port`              | Service / container port (also SERVER_PORT)| `5557`      |
| `resources.requests.cpu`    | CPU request                                | `100m`      |
| `resources.requests.memory` | Memory request                             | `256Mi`     |
| `resources.limits.cpu`      | CPU limit                                  | `500m`      |
| `resources.limits.memory`   | Memory limit                               | `512Mi`     |
| `nodeSelector`              | Node selector                              | `{}`        |
| `tolerations`               | Tolerations                                | `[]`        |
| `affinity`                  | Affinity rules                             | `{}`        |

### Prometheus Operator ServiceMonitor

| Parameter                       | Description                                                              | Default |
| ------------------------------- | ------------------------------------------------------------------------ | ------- |
| `serviceMonitor.enabled`        | Create a `ServiceMonitor` for this exporter                              | `false` |
| `serviceMonitor.labels`         | Extra labels (e.g. `{ release: kube-prometheus-stack }` for selector match)| `{}`    |
| `serviceMonitor.interval`       | Scrape interval                                                          | `30s`   |
| `serviceMonitor.scrapeTimeout`  | Scrape timeout                                                           | `10s`   |
| `serviceMonitor.path`           | Metrics path (defaults to `rocketmq.webTelemetryPath`)                   | `""`    |
| `serviceMonitor.relabelings`    | Prometheus relabeling rules applied before scrape                        | `[]`    |
| `serviceMonitor.metricRelabelings` | Prometheus relabeling rules applied to scraped metrics                | `[]`    |

### Istio VirtualService

| Parameter                 | Description                 | Default |
| ------------------------- | --------------------------- | ------- |
| `virtualservice.enabled`  | Enable Istio VirtualService | `false` |
| `virtualservice.gateways` | Istio gateway references    | `[]`    |
| `virtualservice.hosts`    | VirtualService hostnames    | `[]`    |

Probes are TCP — actuator endpoints on the exporter are not guaranteed. A `startupProbe` is enabled by default because the Spring Boot app is slow to start.

## Examples

### Scraped by a Prometheus Operator stack

```yaml
rocketmq:
  namesrvAddr: rocketmq-namesrv.streaming.svc:9876
  rocketmqVersion: 4_9_4

serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
```

### With ACL credentials from an existing Secret

```yaml
auth:
  enabled: true
  existingSecret: rocketmq-acl

rocketmq:
  namesrvAddr: rocketmq-namesrv.streaming.svc:9876
```

### Multi-NameServer cluster

```yaml
rocketmq:
  namesrvAddr: "ns-a.streaming.svc:9876;ns-b.streaming.svc:9876"
  rocketmqVersion: 4_9_4
  extraConfig:
    taskCount: 20
```
