# README.md

## Prerequisites

```bash
kubectl create namespace mgmt
helm repo add kafbat-ui https://kafbat.github.io/helm-charts --force-update
helm repo add heywood8 https://heywood8.github.io/helm-charts --force-update
```

## Install

```bash
# Install cerebro
kubectl apply -n mgmt -f cerebro.yaml

# Install rocketmq-exporter
kubectl apply -n mgmt -f rocketmq-exporter.yaml

# Install kafka-ui
#kubectl apply -n mgmt -f kafka-ui.yaml
helm show values kafbat-ui/kafka-ui > kafka-ui-values.yaml
helm upgrade --install \
  --namespace mgmt \
  kafbat-ui kafbat-ui/kafka-ui \
  -f kafka-ui-values.yaml

# Install redisinsight
helm show values heywood8/redisinsight > redisinsight-values.yaml
helm upgrade --install \
  --namespace mgmt \
  redisinsight heywood8/redisinsight \
  -f redisinsight-values.yaml
```

## External Access

```bash
# Apply istio virtualservice resource
kubectl apply -n mgmt -f kafka-ui-virtualservice.yaml
kubectl apply -n mgmt -f redisinsight-virtualservice.yaml

# Istio whitelist
```
