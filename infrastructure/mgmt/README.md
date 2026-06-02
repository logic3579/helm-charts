# README.md

## Prerequisites

```bash
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm repo add wiremind https://wiremind.github.io/wiremind-helm-charts
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

Uses the in-repo `logic-charts/kafka-ui` chart. VirtualService is enabled
through values — no standalone manifest needed. Edit `<PLACEHOLDER>` tokens
in `kafka-ui-values.yaml` (kafka bootstrap servers, VS host) before installing.

```bash
helm upgrade --install \
  --namespace mgmt \
  kafka-ui logic-charts/kafka-ui \
  -f kafka-ui-values.yaml
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

Uses the in-repo `logic-charts/rocketmq-exporter` chart. NameServer address,
RocketMQ version, Prometheus scrape annotations, and VirtualService are all
configured through values — no standalone manifest needed.

```bash
helm upgrade --install \
  --namespace mgmt \
  rocketmq-exporter logic-charts/rocketmq-exporter \
  -f rocketmq-exporter-values.yaml
```
