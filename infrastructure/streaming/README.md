# Streaming

Standalone infrastructure references for streaming components.

These configs are not ArgoCD-managed yet. They document the recommended
operator-based path for production-like Kubernetes deployments.

## Components

| Directory | Description |
| --- | --- |
| [kafka/](./kafka/) | Apache Kafka on Kubernetes with Strimzi, KRaft mode, node pools, topic/user CRs, and Cruise Control rebalance example |
| [flink/](./flink/) | Apache Flink on Kubernetes with the Apache Flink Kubernetes Operator and Application mode deployment example |
