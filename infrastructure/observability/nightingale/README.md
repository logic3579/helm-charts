# Nightingale

[Nightingale (n9e)](https://github.com/ccfos/nightingale) deployment reference: Helm chart for the server side, plus
Categraf manifests, dashboards, and alert rules for the agent / content side.

The Helm chart is published from this repo (`charts/nightingale/`) — upstream
[`flashcatcloud/n9e-helm`](https://github.com/flashcatcloud/n9e-helm) does not push to Artifact Hub, so
`logic3579/nightingale` is a repackaged mirror tracking upstream.

> **Dual-purpose values file.** `nightingale-values.yaml` in this directory is
> consumed by **both** the ArgoCD Application at
> [`infrastructure/argocd/applications/nightingale.yaml`](../../argocd/applications/nightingale.yaml)
> (via a multi-source `$values` ref) **and** the standalone `helm upgrade --install`
> commands below. ArgoCD is the canonical mgmt-cluster deployment route; the
> standalone helm path is a fallback / debug escape hatch (e.g. when ArgoCD
> itself is down or not yet bootstrapped). Edit `<PLACEHOLDER>` tokens in
> place — both paths render the same config.

## Layout

| File / dir                        | Purpose                                                                             |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| `nightingale-values.yaml`         | Override values for `logic3579/nightingale` (ingress, persistence, externalURL)  |
| `nightingale-virtualservice.yaml` | Istio VirtualService (external gateway → `nightingale.<ns>.svc`)                    |
| `categraf-daemonset.yaml`         | Categraf DaemonSet — per-node host metrics                                          |
| `categraf-deployment.yaml`        | Categraf Deployment — scrapes kube-state-metrics, MySQL/Redis exporters, ClickHouse |
| `categraf-prometheus-agent.yaml`  | Categraf Deployment in Prometheus-agent mode — Kubernetes service discovery         |
| `n9e-ui/dashboards/`              | Curated dashboard JSON (MySQL, Redis, Kafka, ClickHouse, Istio, K8s, Loki)          |
| `n9e-ui/alert-rules/`             | Curated alert rule JSON (common / k8s / istio / middleware)                         |
| `n9e-ui/SlackBot*.json`           | Slack notification template payloads                                                |

## Prerequisites

Categraf scrapes the same exporters as the Prometheus stack. Install them once from the sibling stack:

```bash
# kube-state-metrics, prometheus-mysql-exporter, prometheus-redis-exporter
# See ../prometheus-community/README.md
```

Add the chart repo and create the namespace:

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update
kubectl create namespace nightingale
```

## Install Nightingale server

```bash
helm upgrade --install nightingale logic3579/nightingale \
  --namespace nightingale \
  -f nightingale-values.yaml

kubectl apply -n nightingale -f nightingale-virtualservice.yaml
```

Pin to a specific chart version with `--version <x.y.z>`. See available versions:
[Artifact Hub](https://artifacthub.io/packages/helm/logic3579/nightingale) or
`helm search repo logic3579/nightingale --versions`.

## Install Categraf (this cluster)

```bash
kubectl apply -n nightingale -f categraf-deployment.yaml         # kube-state-metrics + MySQL + ClickHouse
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml   # Kubernetes service-discovery scrape
```

## Install Categraf (remote clusters)

For each additional cluster that should ship metrics into this Nightingale instance:

```bash
kubectl apply -n nightingale -f categraf-daemonset.yaml          # per-node host metrics
kubectl apply -n nightingale -f categraf-deployment.yaml
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml
```

Point the categraf `nserver_url` / writer addresses at this Nightingale's gateway service before applying.

## Import dashboards & alert rules

After Nightingale comes up, import the curated JSON via the UI:
**Explorer → Dashboards / Monitors → Rules**, then upload files from `n9e-ui/`.

## Notes

- Namespace is `nightingale` (chart default and where Categraf manifests target).
- The chart is vendored from upstream and does NOT use the `common` library chart — `values.yaml` schema follows
  upstream `flashcatcloud/n9e-helm`, not the conventions of `common`-based app charts (e.g. elasticvue).
- For an external-only deployment (no in-cluster scrape), skip the Categraf manifests entirely.
