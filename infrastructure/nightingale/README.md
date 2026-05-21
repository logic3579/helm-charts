# README.md

## Prerequisites

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
kubectl create namespace nightingale
```

## kube-state-metrics

```bash
helm upgrade --install \
  --namespace nightingale \
  kube-state-metrics prometheus-community/kube-state-metrics
```

## prometheus-mysql-exporter

```bash
helm upgrade --install \
  --namespace nightingale \
  prometheus-mysql-exporter prometheus-community/prometheus-mysql-exporter \
  --set mysql.host="mysql.database.svc.cluster.local" \
  --set mysql.user="your_user" \
  --set mysql.password="your_password"
```

## prometheus-redis-exporter

```bash
helm upgrade --install \
  --namespace nightingale \
  prometheus-redis-exporter prometheus-community/prometheus-redis-exporter \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=512Mi \
  --set nodeSelector.tier=mgmt \
```

## Nightingale

```bash
git clone http://github.com/flashcatcloud/n9e-helm.git nightingale
cd nightingale

helm upgrade --install \
  --namespace nightingale \
  nightingale . \
  -f nightingale-values.yaml

kubectl apply -n nightingale -f nightingale-virtualservice.yaml

# Install categraf(deployment) for collect metrics
kubectl apply -n nightingale -f categraf-deployment.yaml # kube-state-metrics, prometheus-mysql-exporter, clickhouse
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml # kubernetes services metrics with prometheus-agent scape

# Optional: other cluster install categraf(daemonset and deployment) for collect metrics
kubectl apply -n nightingale -f categraf-daemonset.yaml
kubectl apply -n nightingale -f categraf-deployment.yaml
kubectl apply -n nightingale -f categraf-prometheus-agent.yaml
```
