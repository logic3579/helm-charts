## Install loki

```bash
helm upgrade --install loki grafana/loki -f loki-values.yaml -n logging --wait --create-namespace --version=6.34.0
```

## Install promtail

```bash
helm upgrade --install loki grafana/promtail -f promtail-values.yaml -n logging --wait --create-namespace
```
