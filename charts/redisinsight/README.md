# redisinsight

A Helm chart for [RedisInsight](https://github.com/redis/RedisInsight) — Redis Inc.'s official web UI for Redis.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.x
- (Optional) A `StorageClass` if you want a persistent `/data` directory
- (Optional) Istio for VirtualService traffic routing

> RedisInsight is **stateful** — it writes SQLite, saved connections, and logs to `/data`.
> Without `persistence.enabled=true`, the chart mounts an `emptyDir` and your state is lost on pod restart.

## Install

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update

# Ephemeral (state lost on restart):
helm install redisinsight logic3579/redisinsight

# With a 5Gi PVC for persistent /data:
helm install redisinsight logic3579/redisinsight \
  --set persistence.enabled=true \
  --set persistence.size=5Gi
```

## Parameters

### Image

| Parameter          | Description                                                                            | Default            |
| ------------------ | -------------------------------------------------------------------------------------- | ------------------ |
| `image.repository` | Container image repository (use `redis/redisinsight` — `redislabs/` is a legacy mirror)| `redis/redisinsight`|
| `image.tag`        | Image tag (defaults to `.Chart.AppVersion`, a floating tag like `3.4`)                 | `""`               |
| `image.pullPolicy` | Image pull policy                                                                      | `IfNotPresent`     |

### RedisInsight configuration

`RI_APP_HOST=0.0.0.0` and `RI_APP_PORT` (from `service.port`) are injected automatically. Anything else is free-form:

| Parameter                     | Description                                                                  | Default |
| ----------------------------- | ---------------------------------------------------------------------------- | ------- |
| `redisinsight.extraConfig`    | Map of extra `RI_*` env vars, rendered as `RI_<UPPER_KEY>`                   | `{}`    |

```yaml
redisinsight:
  extraConfig:
    EXTERNAL_URL: "https://ri.example.com"   # → RI_EXTERNAL_URL
```

### Persistence

| Parameter                  | Description                                                       | Default          |
| -------------------------- | ----------------------------------------------------------------- | ---------------- |
| `persistence.enabled`      | Mount a PVC at `/data`                                            | `false`          |
| `persistence.size`         | Volume size                                                       | `1Gi`            |
| `persistence.storageClass` | StorageClass (empty = cluster default)                            | `""`             |
| `persistence.accessMode`   | Access mode — RWO is the only safe default                        | `ReadWriteOnce`  |
| `persistence.existingClaim`| Reuse an existing PVC instead of creating one                     | `""`             |
| `persistence.annotations`  | PVC annotations                                                   | `{}`             |

With `persistence.enabled=true`, the Deployment uses `strategy: Recreate` so a `ReadWriteOnce` volume can detach cleanly between rollouts.

### Common Parameters

| Parameter                   | Description                                  | Default     |
| --------------------------- | -------------------------------------------- | ----------- |
| `replicaCount`              | Number of replicas (keep at 1 unless RWX)    | `1`         |
| `service.type`              | Service type                                 | `ClusterIP` |
| `service.port`              | Service / container port (also `RI_APP_PORT`)| `5540`      |
| `resources.requests.cpu`    | CPU request                                  | `100m`      |
| `resources.requests.memory` | Memory request                               | `256Mi`     |
| `resources.limits.cpu`      | CPU limit                                    | `500m`      |
| `resources.limits.memory`   | Memory limit                                 | `512Mi`     |
| `nodeSelector`              | Node selector                                | `{}`        |
| `tolerations`               | Tolerations                                  | `[]`        |
| `affinity`                  | Affinity rules                               | `{}`        |

### Istio VirtualService

| Parameter                 | Description                 | Default |
| ------------------------- | --------------------------- | ------- |
| `virtualservice.enabled`  | Enable Istio VirtualService | `false` |
| `virtualservice.gateways` | Istio gateway references    | `[]`    |
| `virtualservice.hosts`    | VirtualService hostnames    | `[]`    |

Probes are TCP — RedisInsight has no documented HTTP health endpoint. Autoscaling is only safe with an RWX PVC; otherwise replicas can't share `/data`.

## Examples

### Persistent install with Istio VirtualService

```yaml
persistence:
  enabled: true
  size: 5Gi
  storageClass: premium-rwo

virtualservice:
  enabled: true
  gateways:
    - istio-ingress/internal-gateway
  hosts:
    - redisinsight.example.com
```

### External URL behind a reverse proxy

```yaml
redisinsight:
  extraConfig:
    EXTERNAL_URL: "https://ri.example.com"

virtualservice:
  enabled: true
  gateways:
    - istio-ingress/external-gateway
  hosts:
    - ri.example.com
```

### Reuse an existing PVC

```yaml
persistence:
  enabled: true
  existingClaim: my-redisinsight-data
```
