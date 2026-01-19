# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo add gradiant-bigdata https://gradiant.github.io/bigdata-charts --force-update
kubectl create namespace bigdata
```

## Flink

```bash
helm upgrade --install \
  --namespace bigdata \
  flink bitnami/flink \
  --set image.repository="bitnamilegacy/flink"

kubectl apply -n monitoring -f flink-virtualservice.yml
```

## HBase

```bash
helm upgrade --install \
  --namespace bigdata \
  hbase gradiant-bigdata/hbase

kubectl apply -n monitoring -f hbase-virtualservice.yml
```
