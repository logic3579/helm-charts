# Kafka on Kubernetes with Strimzi

This directory is a standalone infrastructure reference for running Apache
Kafka on Kubernetes with Strimzi.

It intentionally replaces the old direct Helm chart approach. For production,
Kafka should be managed by a Kubernetes operator that understands Kafka
lifecycle, broker identity, persistent volumes, topic/user resources, and
rebalance operations.

## Recommendation

- Use Strimzi Operator for self-managed Kafka on Kubernetes.
- Use KRaft mode. Do not create new ZooKeeper-based Kafka clusters.
- Use `KafkaNodePool` resources to separate controller and broker roles.
- Keep Kafka topics and users declarative with `KafkaTopic` and `KafkaUser`.
- Use Cruise Control through Strimzi for rebalance operations.
- Keep this directory standalone until an explicit ArgoCD integration is added.

## Files

| File | Purpose |
| --- | --- |
| `strimzi-operator-values.yaml` | Minimal values override for the Strimzi Helm chart |
| `kafka.yaml` | KRaft Kafka cluster definition |
| `kafka-nodepool-controller.yaml` | Dedicated controller node pool |
| `kafka-nodepool-broker.yaml` | Dedicated broker node pool |
| `kafka-topic-example.yaml` | Example managed topic |
| `kafka-user-example.yaml` | Example SCRAM user and ACLs |
| `kafka-rebalance-example.yaml` | Example Cruise Control full rebalance request |

## Prerequisites

```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
kubectl create namespace kafka
```

Use a storage class with predictable latency and zone topology. Edit the
`storage.class` values in the node pool manifests before applying.

## Install Strimzi Operator

```bash
helm upgrade --install \
  --namespace kafka \
  --create-namespace \
  strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 1.1.0 \
  -f strimzi-operator-values.yaml

kubectl wait --timeout=5m \
  --namespace kafka \
  deployment/strimzi-cluster-operator \
  --for=condition=Available
```

## Deploy Kafka

Apply node pools before the Kafka resource:

```bash
kubectl apply -f kafka-nodepool-controller.yaml
kubectl apply -f kafka-nodepool-broker.yaml
kubectl apply -f kafka.yaml
```

Wait for the cluster:

```bash
kubectl wait --timeout=15m \
  --namespace kafka \
  kafka/kafka \
  --for=condition=Ready
```

Internal bootstrap endpoints:

```text
PLAINTEXT: kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
TLS/SCRAM: kafka-kafka-bootstrap.kafka.svc.cluster.local:9093
```

Prefer the TLS/SCRAM listener for applications. The plaintext listener is kept
only for simple in-cluster smoke tests and should be removed for stricter
environments.

## Manage Topics and Users

```bash
kubectl apply -f kafka-topic-example.yaml
kubectl apply -f kafka-user-example.yaml
```

Strimzi writes SCRAM credentials into a Secret named after the `KafkaUser`:

```bash
kubectl -n kafka get secret app-producer -o yaml
```

## Rebalance

Cruise Control is enabled in `kafka.yaml`. Create a rebalance proposal:

```bash
kubectl apply -f kafka-rebalance-example.yaml
kubectl -n kafka describe kafkarebalance kafka-full-rebalance
```

Review the proposal before approving it. Follow the Strimzi status conditions
and annotations for approval and execution.

## Production Notes

- Use at least 3 controllers and 3 brokers.
- Set topic replication factors to 3 and `min.insync.replicas` to 2 for normal
  production topics.
- Keep `deleteClaim: false` on persistent storage.
- Use rack awareness / topology spread when the cluster spans zones.
- Avoid exposing brokers externally unless clients require it. If external
  access is needed, configure Strimzi listeners deliberately and verify
  advertised addresses.
- Keep `auto.create.topics.enable` disabled and manage topics through
  `KafkaTopic`.
- Use `KafkaUser` and ACLs rather than shared credentials.
- Treat broker storage expansion and node pool scaling as planned operations,
  followed by Cruise Control rebalance.

## References

- Strimzi documentation: https://strimzi.io/documentation/
- Strimzi deploying and KRaft docs: https://strimzi.io/docs/operators/latest/deploying.html
- Apache Kafka KRaft docs: https://kafka.apache.org/43/operations/kraft/
- Apache Kafka KRaft vs ZooKeeper: https://kafka.apache.org/43/getting-started/zk2kraft/

