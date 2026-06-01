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
helm show values oci://registry-1.docker.io/cloudpirates/zookeeper > zookeeper-values.yaml
helm upgrade --install \
  --namespace streaming \
  zookeeper oci://registry-1.docker.io/cloudpirates/zookeeper \
  -f zookeeper-values.yaml \
  --set image.repository="bitnamilegacy/zookeeper"
```
