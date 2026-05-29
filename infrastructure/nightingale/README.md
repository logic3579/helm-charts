# README.md

## Prerequisites

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
kubectl create namespace nightingale
```

> kube-state-metrics, prometheus-mysql-exporter, and prometheus-redis-exporter
> moved to [`../observability/prometheus-community/`](../observability/prometheus-community/).
> Install them from there before continuing — Categraf scrapes the same endpoints.

## Nightingale

```bash
git clone http://github.com/flashcatcloud/n9e-helm.git nightingale
cd nightingale

helm upgrade --install \
  --namespace nightingale \
  nightingale . \
  -f nightingale-values.yaml

kubectl apply -n nightingale -f nightingale-virtualservice.yaml

# Install categraf(deployment) for collect metrics
kubectl apply -n nightingale -f categraf-deployment.yaml # kube-state-metrics, prometheus-mysql-exporter, clickhouse
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml # kubernetes services metrics with prometheus-agent scape

# Optional: other cluster install categraf(daemonset and deployment) for collect metrics
kubectl apply -n nightingale -f categraf-daemonset.yaml
kubectl apply -n nightingale -f categraf-deployment.yaml
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml
```
