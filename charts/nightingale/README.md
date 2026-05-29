# Nightingale Helm Chart

[Nightingale (n9e)](https://github.com/ccfos/nightingale) — an enterprise-grade cloud-native monitoring system,
packaged as a Helm chart.

This chart is repackaged from upstream [`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm), which
does not publish to Artifact Hub. It is published from `logic3579/helm-charts` so the chart is discoverable as
`logic-charts/nightingale` on [Artifact Hub](https://artifacthub.io/packages/helm/logic-charts/nightingale).

For application-level (n9e UI / agent / alerting) issues, file them on
[`ccfos/nightingale`](https://github.com/ccfos/nightingale) instead of this chart.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.2.0+
- A default `StorageClass` (or override `persistence.persistentVolumeClaim.<comp>.storageClass` per component)

## Install

```bash
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm repo update

helm install nightingale logic-charts/nightingale \
  --namespace nightingale --create-namespace
```

Pin to a specific chart version:

```bash
helm search repo logic-charts/nightingale --versions
helm install nightingale logic-charts/nightingale --version 0.3.0 \
  --namespace nightingale --create-namespace
```

## Configure

Pull the upstream `values.yaml` as the configuration reference:

```bash
helm show values logic-charts/nightingale > nightingale-values.yaml
# edit nightingale-values.yaml
helm upgrade --install nightingale logic-charts/nightingale \
  --namespace nightingale --create-namespace \
  -f nightingale-values.yaml
```

A production-leaning example values file lives at
[`infrastructure/observability/nightingale/nightingale-values.yaml`](../../infrastructure/observability/nightingale/nightingale-values.yaml).

### Key value groups

| Group               | Purpose                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------- |
| `expose.type`       | `ingress` / `clusterIP` / `nodePort` / `loadBalancer`. Pick `clusterIP` if routing via Istio / external LB.    |
| `expose.tls`        | TLS for the built-in ingress. `auto`, `secret`, or `none`.                                                     |
| `externalURL`       | External URL for the n9e web UI (used by NOTES.txt only — actual routing is per `expose.type`).                |
| `persistence`       | PVC sizes / storage class for `database`, `redis`, `prometheus`.                                               |
| `database`          | `type: internal` to deploy the bundled MySQL StatefulSet; `external` to point at an existing MySQL.            |
| `redis`             | `type: internal` to deploy the bundled Redis; `external` for a managed instance.                                |
| `prometheus`        | `type: internal` to deploy the bundled Prometheus as remote-write target; `external` to plug in your own.       |
| `n9e.victoriaMetrics` | Set `enabled: true` + `url` to remote-write to a VictoriaMetrics cluster instead of the bundled Prometheus.   |
| `categraf`          | `type: internal` deploys a Categraf DaemonSet (host metrics) wired to the n9e server.                          |
| `nginx`             | Front-end nginx that reverse-proxies the n9e API and serves the web UI.                                        |

### Default credentials

- Web UI default user: `root` / password: `root.2020` — change immediately after first login.

## Upgrade

```bash
helm repo update
helm upgrade nightingale logic-charts/nightingale \
  --namespace nightingale \
  -f nightingale-values.yaml
```

## Uninstall

```bash
helm uninstall nightingale -n nightingale
# PVCs use resourcePolicy: "keep" by default — delete them manually if you want to drop data:
kubectl delete pvc -n nightingale -l app=n9e
```

## Source & changes

- Chart source: [`charts/nightingale/`](https://github.com/logic3579/helm-charts/tree/main/charts/nightingale)
- Companion infra refs (Categraf, dashboards, alert rules, Istio VirtualService):
  [`infrastructure/observability/nightingale/`](https://github.com/logic3579/helm-charts/tree/main/infrastructure/observability/nightingale)
- Upstream chart: [`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm)
- Nightingale: [`ccfos/nightingale`](https://github.com/ccfos/nightingale)
