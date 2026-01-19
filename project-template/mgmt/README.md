# README.md

## Prerequisites

```bash
#helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
kubectl create namespace mgmt
```

## Zookeeper

```bash
crane ls registry-1.docker.io/bitnamicharts/kafka
helm show chart oci://registry-1.docker.io/bitnamicharts/kafka
helm show values oci://registry-1.docker.io/bitnamicharts/kafka

helm show values oci://registry-1.docker.io/bitnamicharts/kafka > zookeeper-values.yaml
helm upgrade --install \
  --namespace mgmt \
  zookeeper oci://registry-1.docker.io/cloudpirates/zookeeper \
  -f zookeeper-values.yaml \
  --version=0.5.1
```
