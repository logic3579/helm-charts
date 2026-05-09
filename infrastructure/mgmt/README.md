# README.md

## Prerequisites

```bash
helm repo add wiremind https://wiremind.github.io/wiremind-helm-charts
helm repo add kafbat-ui https://kafbat.github.io/helm-charts
helm repo add heywood8 https://heywood8.github.io/helm-charts
helm repo update
kubectl create namespace mgmt
```

## cerebro

```bash
helm show values wiremind/cerebro > cerebro-values.yaml
helm upgrade --install \
  --namespace mgmt \
  cerebro wiremind/cerebro \
  -f cerebro-values.yaml

kubectl apply -n mgmt -f cerebro-virtualservice.yaml
```

## kafka-ui

```bash
helm show values kafbat-ui/kafka-ui > kafka-ui-values.yaml
helm upgrade --install \
  --namespace mgmt \
  kafbat-ui kafbat-ui/kafka-ui \
  -f kafka-ui-values.yaml

kubectl apply -n mgmt -f kafka-ui-virtualservice.yaml
```

## redisinsight

```bash
helm show values heywood8/redisinsight > redisinsight-values.yaml
helm upgrade --install \
  --namespace mgmt \
  redisinsight heywood8/redisinsight \
  -f redisinsight-values.yaml

kubectl apply -n mgmt -f redisinsight-virtualservice.yaml
```

## rocketmq-exporter

```bash
kubectl apply -n mgmt -f rocketmq-exporter.yaml
kubectl apply -n mgmt -f rocketmq-exporter-virtualservice.yaml
```
