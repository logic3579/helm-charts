# README.md

## Prerequisites

```bash
helm repo add grafana https://grafana.github.io/helm-charts --force-update
kubectl create namespace logging
```

## Loki

```bash
helm upgrade --install \
  --namespace logging \
  loki grafana/loki \
  -f values-loki.yaml \
  --version=6.34.0

kubectl apply -n monitoring -f virtualservice-loki.yml
```

## Promtail

```bash
helm upgrade --install \
  --namespace logging \
  loki grafana/promtail
```
