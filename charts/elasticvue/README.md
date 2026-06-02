# elasticvue

A Helm chart for [Elasticvue](https://github.com/cars10/elasticvue) — a web UI for Elasticsearch and OpenSearch.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.x
- (Optional) Istio for VirtualService traffic routing
- (Optional) An existing `Secret` if you want to keep cluster credentials out of plaintext values

## Install

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update

# Bring your own clusters at install time:
helm install elasticvue logic3579/elasticvue \
  --set 'elasticvue.clusters[0].name=local' \
  --set 'elasticvue.clusters[0].uri=http://elasticsearch.es.svc:9200'
```

Or install with no preset clusters — users add them in the browser at runtime:

```bash
helm install elasticvue logic3579/elasticvue
```

## Parameters

### Image

| Parameter          | Description                                 | Default            |
| ------------------ | ------------------------------------------- | ------------------ |
| `image.repository` | Container image repository                  | `cars10/elasticvue`|
| `image.tag`        | Image tag (defaults to `.Chart.AppVersion`) | `""`               |
| `image.pullPolicy` | Image pull policy                           | `IfNotPresent`     |

### Clusters

The chart injects the `ELASTICVUE_CLUSTERS` env var that Elasticvue reads at startup.

| Parameter                    | Description                                                                                  | Default |
| ---------------------------- | -------------------------------------------------------------------------------------------- | ------- |
| `elasticvue.clusters`        | List of preconfigured clusters — rendered as JSON into `ELASTICVUE_CLUSTERS`                 | `[]`    |
| `elasticvue.existingSecret`  | Use an existing Secret to supply `ELASTICVUE_CLUSTERS` (key: `ELASTICVUE_CLUSTERS`)          | `""`    |

`elasticvue.existingSecret` and `elasticvue.clusters` are mutually exclusive — **the Secret wins if both are set**. Prefer the Secret in production so cluster credentials are not stored in plaintext values.

Each cluster supports the fields documented in the [upstream API](https://github.com/cars10/elasticvue#preconfigured-clusters): `name`, `uri`, `username`, `password`, `apiKey`, and a few AWS-IAM fields.

### Common Parameters

| Parameter                   | Description              | Default     |
| --------------------------- | ------------------------ | ----------- |
| `replicaCount`              | Number of replicas       | `1`         |
| `service.type`              | Service type             | `ClusterIP` |
| `service.port`              | Service / container port | `8080`      |
| `resources.requests.cpu`    | CPU request              | `25m`       |
| `resources.requests.memory` | Memory request           | `32Mi`      |
| `resources.limits.cpu`      | CPU limit                | `100m`      |
| `resources.limits.memory`   | Memory limit             | `128Mi`     |
| `nodeSelector`              | Node selector            | `{}`        |
| `tolerations`               | Tolerations              | `[]`        |
| `affinity`                  | Affinity rules           | `{}`        |

### Istio VirtualService

| Parameter                 | Description                 | Default |
| ------------------------- | --------------------------- | ------- |
| `virtualservice.enabled`  | Enable Istio VirtualService | `false` |
| `virtualservice.gateways` | Istio gateway references    | `[]`    |
| `virtualservice.hosts`    | VirtualService hostnames    | `[]`    |

The upstream image is built on `nginxinc/nginx-unprivileged` (UID 101). Probes are TCP because there's no `/health` endpoint upstream. `readOnlyRootFilesystem` is intentionally `false` so the entrypoint can write `/usr/share/nginx/html/api/default_clusters.json` when `ELASTICVUE_CLUSTERS` is set, plus the temp files nginx writes to `/var/cache/nginx` and `/var/run`.

## Examples

### Preconfigured cluster, credentials inline (dev only)

```yaml
elasticvue:
  clusters:
    - name: local
      uri: http://elasticsearch.es.svc:9200
      username: viewer
      password: changeme
```

### Preconfigured cluster, credentials from an existing Secret

```yaml
# Create the secret separately (e.g. via ESO or kubectl):
#   kubectl create secret generic elasticvue-clusters \
#     --from-literal=ELASTICVUE_CLUSTERS='[{"name":"prod","uri":"http://es:9200","username":"viewer","password":"…"}]'
elasticvue:
  existingSecret: elasticvue-clusters
```

### With Istio VirtualService

```yaml
virtualservice:
  enabled: true
  gateways:
    - istio-ingress/internal-gateway
  hosts:
    - elasticvue.example.com
```
