# README.md

## Prerequisites

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
kubectl create namespace monitoring
```

## kube-state-metrics

```bash
helm upgrade --install \
  --namespace monitoring \
  kube-state-metrics prometheus-community/kube-state-metrics
```

## prometheus-mysql-exporter

```bash
helm upgrade --install \
  --namespace monitoring \
  prometheus-mysql-exporter prometheus-community/prometheus-mysql-exporter \
  --set mysql.host="mysql.database.svc.cluster.local" \
  --set mysql.user="your_user" \
  --set mysql.password="your_password"
```

## Grafana

```bash
helm upgrade --install \
  --namespace monitoring \
  grafana grafana/grafana \
  --set persistence.type="pvc" \
  --set persistence.enabled="true" \
  --set persistence.storageClassName="standard-rwo" \
  --set useStatefulSet="true"

kubectl apply -f virtualservice-grafana.yml
```

## Nightingale

```bash
# get helm-charts
git clone http://github.com/flashcatcloud/n9e-helm.git nightingale
cd nightingale

# timezone(optional)
grep "name: TZ" ./ -r

# configure categraf
vim categraf/conf/input.cadvisor/cadvisor.toml
vim categraf/conf/input.prometheus/prometheus.toml

# configure values.yaml
vim values.yaml

# Install
helm upgrade --install \
  --namespace monitoring \
  nightingale . \
  -f values.yaml

kubectl apply -n monitoring -f virtualservice-n9e.yml
# collect kube-state-metrics, prometheus-mysql-exporter, clickhouse and so on.
kubectl apply -n monitoring -f deployment-categraf.yml

# optional: for other cluster
kubectl apply -n monitoring -f daemonset-categraf.yml
```
