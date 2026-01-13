# README.md

## Prerequisites

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update
kubectl create namespace streaming
```

## Kafka

```bash
helm upgrade --install \
  --namespace streaming \
  kafka bitnami/kafka \
  --set image.repository="bitnamilegacy/kafka"

# optional: custom service name
kubectl apply -n streaming -f service-kafka.yml
```
