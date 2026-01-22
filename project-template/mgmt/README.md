# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
helm repo add heywood8 https://heywood8.github.io/helm-charts --force-update
kubectl create namespace mgmt
```

## kafka-ui

```bash
kubectl apply -n mgmt -f kafka-ui.yml
```

## redisinsight

```bash
helm upgrade --install \
  --namespace mgmt \
  redisinsight heywood8/redisinsight \
  --set nodeSelector.tier="mgmt"

kubectl apply -n mgmt -f redisinsight-virtualservice.yml
```

## Zookeeper

```bash
# get info
crane ls registry-1.docker.io/bitnamicharts/kafka
helm show chart oci://registry-1.docker.io/bitnamicharts/kafka
helm show manifest oci://registry-1.docker.io/bitnamicharts/kafka
helm show values oci://registry-1.docker.io/bitnamicharts/kafka

# latest release
helm show values oci://registry-1.docker.io/bitnamicharts/kafka > zookeeper-values.yaml
# specific version
helm show values oci://registry-1.docker.io/bitnamicharts/kafka --version=32.4.3 > zookeeper-values.yaml

# install
helm upgrade --install \
  --namespace mgmt \
  zookeeper oci://registry-1.docker.io/cloudpirates/zookeeper \
  -f zookeeper-values.yaml \
  --version=0.5.1
```
