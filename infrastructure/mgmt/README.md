# README.md

## Prerequisites

```bash
helm repo add logic-charts https://logic3579.github.io/helm-charts
helm repo update
kubectl create namespace mgmt
```

## elasticvue

Uses the in-repo `logic-charts/elasticvue` chart. Pre-configured clusters
(inline or from a Secret), VirtualService — all driven by values. Edit
`elasticvue-values.yaml` (VS host; optionally seed cluster entries) before
installing.

```bash
helm upgrade --install \
  --namespace mgmt \
  elasticvue logic-charts/elasticvue \
  -f elasticvue-values.yaml
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

Uses the in-repo `logic-charts/redisinsight` chart (RedisInsight 3.4 from
Redis Inc.). Persistence and VirtualService are configured through values —
no standalone manifest needed.

```bash
helm upgrade --install \
  --namespace mgmt \
  redisinsight logic-charts/redisinsight \
  -f redisinsight-values.yaml
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
