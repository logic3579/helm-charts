# README.md

## Prerequisites

```bash
kubectl create namespace mgmt
helm repo add kafbat-ui https://kafbat.github.io/helm-charts --force-update
helm repo add heywood8 https://heywood8.github.io/helm-charts --force-update
```

## kafka-ui

```bash
#kubectl apply -n mgmt -f kafka-ui.yaml
helm show values kafbat-ui/kafka-ui > kafka-ui-values.yaml
helm upgrade --install \
  --namespace mgmt \
  kafbat-ui kafbat-ui/kafka-ui \
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
