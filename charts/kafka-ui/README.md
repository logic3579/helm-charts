# kafka-ui

A Helm chart for [UI for Apache Kafka](https://github.com/kafbat/kafka-ui) — a web UI for monitoring and managing Apache Kafka clusters.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.x
- (Optional) Istio for VirtualService traffic routing

## Install

```bash
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm repo update
helm install kafka-ui logic-charts/kafka-ui \
  --set secret.enabled=true \
  --set secret.data.username=admin \
  --set secret.data.password=changeme \
  --set kafkaClusters[0].bootstrapServers=kafka:9092
```

## Parameters

### Image

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `provectuslabs/kafka-ui` |
| `image.tag` | Image tag (defaults to `.Chart.AppVersion`) | `""` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Authentication

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auth.type` | Auth type: `LOGIN_FORM`, `DISABLED`, `LDAP`, `OAUTH2` | `LOGIN_FORM` |
| `auth.existingSecret` | Use an existing secret for credentials (keys: `username`, `password`) | `""` |

When `auth.type` is not `DISABLED`, the chart reads credentials from a Kubernetes Secret. Either:
- Set `secret.enabled=true` and provide `secret.data.username` / `secret.data.password` to create a chart-managed secret, or
- Set `auth.existingSecret` to reference a pre-existing secret

### Kafka Clusters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafkaClusters[].name` | Display name for the cluster | `""` |
| `kafkaClusters[].bootstrapServers` | Kafka bootstrap servers address | `kafka:9092` |
| `kafkaClusters[].readonly` | Enable read-only mode | `false` |
| `kafkaClusters[].schemaRegistry` | Schema Registry URL | `""` |
| `kafkaClusters[].ksqldbServer` | ksqlDB server URL | `""` |
| `kafkaClusters[].properties` | Additional properties as `KAFKA_CLUSTERS_N_<KEY>` env vars | `{}` |

Multiple clusters can be configured by adding entries to the `kafkaClusters` list.

### Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service / container port | `8080` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `1Gi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `1Gi` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

### Istio VirtualService

| Parameter | Description | Default |
|-----------|-------------|---------|
| `virtualservice.enabled` | Enable Istio VirtualService | `false` |
| `virtualservice.gateways` | Istio gateway references | `[]` |
| `virtualservice.hosts` | VirtualService hostnames | `[]` |

## Examples

### Single cluster with read-only access

```yaml
auth:
  type: "LOGIN_FORM"
  existingSecret: "my-kafka-ui-credentials"

kafkaClusters:
  - name: production
    bootstrapServers: kafka.middleware.svc:9092
    readonly: true
```

### Multiple clusters with Schema Registry

```yaml
kafkaClusters:
  - name: production
    bootstrapServers: prod-kafka:9092
    readonly: true
    schemaRegistry: http://schema-registry:8081
  - name: staging
    bootstrapServers: staging-kafka:9092
    readonly: false
```

### With Istio VirtualService

```yaml
virtualservice:
  enabled: true
  gateways:
    - istio-ingress/internal-gateway
  hosts:
    - kafka-ui.example.com
```
