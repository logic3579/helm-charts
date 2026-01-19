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
  -f loki-values.yaml \
  --version=6.34.0

kubectl apply -n monitoring -f loki-virtualservice.yml
```

## Promtail

```bash
helm upgrade --install \
  --namespace logging \
  loki grafana/promtail
```
