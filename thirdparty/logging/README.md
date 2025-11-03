## Install loki

```bash
helm upgrade --install loki grafana/loki -f values-loki.yaml -n logging --wait --create-namespace --version=6.34.0
```

## Install promtail

```bash
helm upgrade --install loki grafana/promtail -f values-promtail.yaml -n logging --wait --create-namespace
```
