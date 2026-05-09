# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
kubectl create namespace streaming
```

## Kafka

```bash
helm show values bitnami/kafka > kafka-values.yaml
helm upgrade --install \
  --namespace streaming \
  kafka bitnami/kafka \
  -f kafka-values.yaml \
  --set image.repository="bitnamilegacy/kafka"
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
  --set image.repository="bitnamilegacy/zookeeper"
```
