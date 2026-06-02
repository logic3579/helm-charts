# Mgmt cluster — standalone helm fallback

> **Fallback path.** The canonical way to deploy these mgmt-tier components
> is ArgoCD — see `infrastructure/argocd/applications/{elasticvue,redisinsight,kafka-ui}.yaml`.
> The standalone `helm upgrade --install` commands below are a debug /
> disaster-recovery escape hatch (e.g. when ArgoCD itself is down or not
> yet bootstrapped on the mgmt cluster).
>
> **The values files in this directory are the single source of truth.**
> The ArgoCD Applications reference these same files via `$values`, so
> ArgoCD-managed and standalone-helm renders are identical. Edit
> `<PLACEHOLDER>` tokens in place before installing.

All components land in the shared `mgmt` namespace — both the ArgoCD
Applications (`destination.namespace: mgmt`) and the standalone helm
commands below.

## Prerequisites

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo add kafbat https://kafbat.github.io/helm-charts   # upstream kafka-ui
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

Uses the upstream `kafbat/kafka-ui` chart (the official chart published at
[artifacthub.io/packages/helm/kafka-ui/kafka-ui](https://artifacthub.io/packages/helm/kafka-ui/kafka-ui)) —
this repo no longer ships an in-house kafka-ui chart. The upstream chart
only ships an Ingress template, so the VirtualService is applied as a
companion manifest from `kafka-ui-manifests/` (also rendered by ArgoCD's
multi-source Application so both paths apply the same VS).

Bootstrap the login password Secret once (or manage it via ESO / Sealed
Secrets):

```bash
kubectl -n mgmt create secret generic kafka-ui-auth \
  --from-literal=password='<choose-a-strong-password>'
```

Install / upgrade + apply the VS:

```bash
helm upgrade --install \
  --namespace mgmt \
  kafka-ui kafbat/kafka-ui --version 1.6.4 \
  -f kafka-ui-values.yaml

kubectl apply -f kafka-ui-manifests/virtualservice.yaml
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

Not ArgoCD-managed — this is a standalone-only component. Uses the in-repo
`logic3579/rocketmq-exporter` chart. NameServer address, RocketMQ version,
Prometheus scrape annotations, and VirtualService are all configured
through values — no standalone manifest needed.

```bash
helm upgrade --install \
  --namespace mgmt \
  rocketmq-exporter logic3579/rocketmq-exporter \
  -f rocketmq-exporter-values.yaml
```
