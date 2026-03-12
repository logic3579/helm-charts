# Helm Quickstart

Example values files for deploying applications using the [charts/](../charts/) Helm charts.

## Structure

```
helm-example/
├── backend-example/
│   └── values.yaml         # Values for charts/go-app (Java backend)
└── frontend-example/
    └── values.yaml         # Values for charts/frontend-app (nginx SPA)
```

## Quick Start

```bash
# 1. Update chart dependencies
helm dependency update ../charts/go-app
helm dependency update ../charts/frontend-app

# 2. Preview rendered manifests
helm template backend ../charts/go-app -f backend-example/values.yaml
helm template frontend ../charts/frontend-app -f frontend-example/values.yaml

# 3. Deploy
helm install backend ../charts/go-app -f backend-example/values.yaml
helm install frontend ../charts/frontend-app -f frontend-example/values.yaml
```

## How to Customize

1. **New app**: Copy `backend-example/` or `frontend-example/`, rename, and edit `values.yaml`
2. **Choose chart**: Use `go-app` for Go/Java backends, `python-app` for Python, `frontend-app` for nginx SPA
3. **Enable features**: Set `virtualservice.enabled: true` for Istio routing, `podDisruptionBudget.enabled: true` for HA
4. **Per-env overrides**: Create `values-dev.yaml` / `values-prod.yaml` and pass multiple `-f` flags

## Available Charts

| Chart | Best For | Default Port |
|-------|----------|-------------|
| [go-app](../charts/go-app) | Go, Java, compiled backends | 8080 |
| [python-app](../charts/python-app) | Python (FastAPI, Django, Flask) | 8000 |
| [frontend-app](../charts/frontend-app) | nginx-based SPA (React, Vue, Angular) | 80 |

All charts share a [common](../charts/common) library for consistent labels, VirtualService, and PDB support.
