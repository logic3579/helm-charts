# README.md

## Prerequisites

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
kubectl create namespace monitoring
```

## kube-state-metrics

```bash
# Install
helm upgrade --install \
  --namespace monitoring \
  kube-state-metrics prometheus-community/kube-state-metrics
```

## prometheus-mysql-exporter

```bash
# Install
helm upgrade --install \
  --namespace monitoring \
  prometheus-mysql-exporter prometheus-community/prometheus-mysql-exporter \
  --set mysql.host="mysql.database.svc.cluster.local" \
  --set mysql.user="your_user" \
  --set mysql.password="your_password"
```

## prometheus-redis-exporter

```bash
# Install
helm upgrade --install \
  --namespace monitoring \
  prometheus-redis-exporter prometheus-community/prometheus-redis-exporter \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=512Mi \
  --set nodeSelector.tier=mgmt \
```

## Grafana

```bash
# Install
helm upgrade --install \
  --namespace monitoring \
  grafana grafana/grafana \
  --set persistence.type="pvc" \
  --set persistence.enabled="true" \
  --set persistence.storageClassName="standard-rwo" \
  --set useStatefulSet="true"
kubectl apply -f grafana-virtualservice.yaml
```

## Nightingale

```bash
# Get helm-charts
git clone http://github.com/flashcatcloud/n9e-helm.git nightingale
cd nightingale

# Set timezone(optional)
grep "name: TZ" ./ -r

# Configure categraf plugins and n9e
vim categraf/conf/input.cadvisor/cadvisor.toml
vim categraf/conf/input.prometheus/prometheus.toml
vim values.yaml

# Install nightingale and categraf(daemonset)
helm upgrade --install \
  --namespace monitoring \
  nightingale . \
  -f values.yaml
kubectl apply -n monitoring -f nightingale-virtualservice.yaml

# Install categraf(deployment) for collect metrics
# kube-state-metrics, prometheus-mysql-exporter, clickhouse
kubectl apply -n monitoring -f categraf/deployment.yaml
# kubernetes services metrics with prometheus-agent scape
kubectl apply -n monitoring -f categraf/prometheus-agent.yaml

# Optional: other cluster install categraf(daemonset and deployment) for collect metrics
kubectl apply -n monitoring -f categraf/daemonset.yaml
kubectl apply -n monitoring -f categraf/deployment.yaml
kubectl apply -n monitoring -f categraf/prometheus-agent.yaml
```
