# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
kubectl create namespace database
```

## ClickHouse

```bash
helm upgrade --install \
  --namespace database \
  clickhouse bitnami/clickhouse \
  --set image.repository="bitnamilegacy/clickhouse"

kubectl apply -n database -f virtualservice-clickhouse.yml
```
