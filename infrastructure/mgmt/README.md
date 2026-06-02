# README.md

## Prerequisites

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update
kubectl create namespace mgmt
```

## elasticvue

Uses the in-repo `logic3579/elasticvue` chart. Pre-configured clusters
(inline or from a Secret), VirtualService — all driven by values. Edit
`elasticvue-values.yaml` (VS host; optionally seed cluster entries) before
installing.

```bash
helm upgrade --install \
  --namespace mgmt \
  elasticvue logic3579/elasticvue \
  -f elasticvue-values.yaml
```

## kafka-ui

Uses the in-repo `logic3579/kafka-ui` chart. VirtualService is enabled
through values — no standalone manifest needed. Edit `<PLACEHOLDER>` tokens
in `kafka-ui-values.yaml` (kafka bootstrap servers, VS host) before installing.

```bash
helm upgrade --install \
  --namespace mgmt \
  kafka-ui logic3579/kafka-ui \
  -f kafka-ui-values.yaml
```

## redisinsight

Uses the in-repo `logic3579/redisinsight` chart (RedisInsight 3.4 from
Redis Inc.). Persistence and VirtualService are configured through values —
no standalone manifest needed.

```bash
helm upgrade --install \
  --namespace mgmt \
  redisinsight logic3579/redisinsight \
  -f redisinsight-values.yaml
```

## rocketmq-exporter

Uses the in-repo `logic3579/rocketmq-exporter` chart. NameServer address,
RocketMQ version, Prometheus scrape annotations, and VirtualService are all
configured through values — no standalone manifest needed.

```bash
helm upgrade --install \
  --namespace mgmt \
  rocketmq-exporter logic3579/rocketmq-exporter \
  -f rocketmq-exporter-values.yaml
```
