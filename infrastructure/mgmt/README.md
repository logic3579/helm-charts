# Mgmt cluster — standalone helm fallback

> **Fallback path.** The canonical way to deploy these mgmt-tier components
> is ArgoCD — see `infrastructure/argocd/applications/{elasticvue,redisinsight,kafka-ui}.yaml`.
> The standalone `helm upgrade --install` commands below are a debug /
> disaster-recovery escape hatch (e.g. when ArgoCD itself is down or not
> yet bootstrapped on the mgmt cluster).
>
> **The values files in this directory are the single source of truth.**
> The existing ArgoCD Applications reference these same files via `$values`, so
> ArgoCD-managed and standalone-helm renders are identical. Edit
> `<PLACEHOLDER>` tokens in place before installing.
>
> `rocketmq-dashboard` is a standalone example with no ArgoCD Application.

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

## rocketmq-dashboard

Uses the in-repo `logic3579/rocketmq-dashboard` chart for **RocketMQ Studio
3.0.0**. It runs separate frontend/backend containers in one pod and deploys
a MySQL 8.0 StatefulSet with an 8Gi PVC by default, matching upstream Compose.
The default application images are public Docker Hub images
`logic3579/rocketmq-server:3.0.0` and `logic3579/rocketmq-web:3.0.0`, built from
the official v3.0.0 source; no local build or image pull Secret is needed. Edit
`rocketmq-dashboard-values.yaml` to set the NameServer address and HTTPS hostname,
and configure MySQL storage if needed. The example uses the internal Istio gateway.

MySQL creates the `rocketmq` database and application user automatically. Its
passwords are generated into a retained Secret and reused by Helm upgrades;
alternatively set `mysql.auth.existingSecret` to an existing Secret containing
`root-password` and `password`. Bootstrap the dashboard login Secret in `mgmt`
(or manage it through ESO / Sealed Secrets):

```bash
kubectl -n mgmt create secret generic rocketmq-dashboard-auth \
  --from-literal=password='<bootstrap-admin-password>'
```

Install locally before the chart's first publication, from the repository root:

```bash
helm dependency update charts/rocketmq-dashboard
helm upgrade --install rocketmq-dashboard charts/rocketmq-dashboard \
  --namespace mgmt \
  -f infrastructure/mgmt/rocketmq-dashboard-values.yaml
```

After publication, the standalone install from this directory is:

```bash
helm upgrade --install rocketmq-dashboard logic3579/rocketmq-dashboard \
  --version 3.0.0 --namespace mgmt \
  -f rocketmq-dashboard-values.yaml
```

The backend waits for MySQL and initializes the packaged schema by default;
it does not seed instances. Register RocketMQ instances through the UI after
login. Set `mysql.enabled: false` and configure `externalDatabase` to connect
to an existing MySQL database instead; the values file includes a commented
example. Keep retained MySQL PVCs and their credential Secret together when
reinstalling, and update accounts in MySQL before changing stored DB passwords.
The admin password Secret is a first-login bootstrap seed; later account changes
are stored in MySQL. HTTPS is required by default for session cookies. This
component is standalone-only here and is not part of the ArgoCD Applications.
