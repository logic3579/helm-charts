# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add neo4j-helm-charts https://neo4j.github.io/helm-charts
helm repo update
kubectl create namespace database
```

## ClickHouse

```bash
helm show values bitnami/clickhouse > clickhouse-values.yaml
helm upgrade --install \
  --namespace database \
  clickhouse bitnami/clickhouse \
  -f clickhouse-values.yaml \
  --set image.repository="bitnamilegacy/clickhouse"

kubectl apply -n database -f clickhouse-virtualservice.yaml
```

## Neo4j

```bash
helm show values neo4j-helm-charts/neo4j > neo4j-values.yaml
helm upgrade --install \
  --namespace database \
  neo4j neo4j-helm-charts/neo4j \
  -f neo4j-values.yaml \
  --set neo4j.name="neo4j_name" \
  --set neo4j.password="neo4j_password"

kubectl apply -n database -f neo4j-virtualservice.yaml
```
