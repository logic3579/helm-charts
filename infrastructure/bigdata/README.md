# README.md

## Prerequisites

```bash
helm repo add gradiant-bigdata https://gradiant.github.io/bigdata-charts
helm repo add community-charts https://community-charts.github.io/helm-charts
helm repo update
kubectl create namespace bigdata
```

## HBase

```bash
helm show values gradiant-bigdata/hbase > hbase-values.yaml
helm upgrade --install \
  --namespace bigdata \
  hbase gradiant-bigdata/hbase \
  -f hbase-values.yaml

kubectl apply -n bigdata -f hbase-virtualservice.yaml
```

## MLflow

```bash
helm show values community-charts/mlflow > mlflow-values.yaml
helm upgrade --install \
  --namespace bigdata \
  mlflow community-charts/mlflow \
  -f mlflow-values.yaml \
  --set strategy.type="Recreate" \
  --set artifactRoot.gcs.enabled="true" \
  --set artifactRoot.gcs.bucket="my-bucket" \
  --set auth.enabled="true" \
  --set auth.adminUsername="admin" \
  --set auth.adminPassword="my_password" \
  --version=1.8.1

kubectl apply -n bigdata -f mlflow-virtualservice.yaml
```
