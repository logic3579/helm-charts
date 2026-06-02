# streaming

Kafka and ZooKeeper installed from upstream OCI Helm charts — no `helm repo add` required.

| Component | Chart                                                                                       | Chart version | App version |
| --------- | ------------------------------------------------------------------------------------------- | ------------- | ----------- |
| Kafka     | [`kubelauncher/kafka`][kafka-ah] (`oci://ghcr.io/kubelauncher/charts/kafka`)                | `0.1.20`      | `3.9.0`     |
| ZooKeeper | [`cloudpirates/zookeeper`][zk-ah] (`oci://registry-1.docker.io/cloudpirates/zookeeper`)     | `0.10.3`      | `3.9.5`     |

[kafka-ah]: https://artifacthub.io/packages/helm/kubelauncher/kafka
[zk-ah]:    https://artifacthub.io/packages/helm/cloudpirates-zookeeper/zookeeper

## Prerequisites

```bash
kubectl create namespace streaming
```

## Kafka

Inspect the chart's default values to author your overrides:

```bash
helm show values oci://ghcr.io/kubelauncher/charts/kafka --version 0.1.20
```

Install / upgrade (pass your own values file with `-f`):

```bash
helm upgrade --install \
  --namespace streaming \
  kafka oci://ghcr.io/kubelauncher/charts/kafka --version 0.1.20 \
  -f my-kafka-values.yaml
```

## ZooKeeper

Inspect the chart's default values to author your overrides:

```bash
helm show values oci://registry-1.docker.io/cloudpirates/zookeeper --version 0.10.3
```

Install / upgrade (pass your own values file with `-f`):

```bash
helm upgrade --install \
  --namespace streaming \
  zookeeper oci://registry-1.docker.io/cloudpirates/zookeeper --version 0.10.3 \
  -f my-zookeeper-values.yaml
```
