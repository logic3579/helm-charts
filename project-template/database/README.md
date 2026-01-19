# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo add neo4j-helm-charts https://neo4j.github.io/helm-charts/ --force-update
kubectl create namespace database
```

## ClickHouse

```bash
helm upgrade --install \
  --namespace database \
  clickhouse bitnami/clickhouse \
  --set image.repository="bitnamilegacy/clickhouse"

kubectl apply -n database -f clickhouse-virtualservice.yml
```

## Neo4j

```bash
helm upgrade --install \
  --namespace database \
  neo4j neo4j-helm-charts/neo4j \
  --set neo4j.name="my-neo4j" \
  --set neo4j.password="my-password"

kubectl apply -n database -f neo4j-virtualservice.yml
```
