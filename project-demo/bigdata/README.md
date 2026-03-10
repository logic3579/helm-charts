# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo add gradiant-bigdata https://gradiant.github.io/bigdata-charts --force-update
helm repo add community-charts https://community-charts.github.io/helm-charts --force-update
kubectl create namespace bigdata
```

## Flink

```bash
helm upgrade --install \
  --namespace bigdata \
  flink bitnami/flink \
  --set image.repository="bitnamilegacy/flink"

kubectl apply -n bigdata -f flink-virtualservice.yml
```

## HBase

```bash
helm upgrade --install \
  --namespace bigdata \
  hbase gradiant-bigdata/hbase

kubectl apply -n bigdata -f hbase-virtualservice.yml
```

## MLflow

```bash
helm upgrade --install \
  --namespace bigdata \
  mlflow community-charts/mlflow \
  --set strategy.type="Recreate" \
  --set artifactRoot.gcs.enabled="true" \
  --set artifactRoot.gcs.bucket="my-bucket" \
  --set auth.enabled="true" \
  --set auth.adminUsername="admin" \
  --set auth.adminPassword="my_password" \
  --version=1.8.1

kubectl apply -n bigdata -f mlflow-virtualservice.yml
```
