# Kustomize Quickstart

A ready-to-use Kustomize template for Kubernetes application deployment using the **base / components / overlays** pattern.

## Structure

```
kustomize-example/
├── base/                               # Shared base manifests
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   └── secret.env.example              # Copy to secret.env before use
├── components/
│   └── resource-standard/              # Reusable Kustomize Component (dev/stg)
│       ├── kustomization.yaml
│       └── patch_resources.yaml
└── overlays/
    ├── dev/                            # Dev environment
    │   └── kustomization.yaml
    ├── stg/                            # Staging environment (shares component with dev)
    │   └── kustomization.yaml
    └── prod/                           # Production (higher resources, more replicas)
        ├── kustomization.yaml
        └── patch_deployment.yaml
```

## Quick Start

```bash
# 1. Prepare secrets
cp base/secret.env.example base/secret.env
# Edit base/secret.env with real credentials

# 2. Preview rendered manifests
kustomize build overlays/dev

# 3. Deploy to a specific environment
kubectl apply -k overlays/dev
kubectl apply -k overlays/stg
kubectl apply -k overlays/prod
```

## How to Customize

1. **Replace the app**: Edit `base/deployment.yaml` — change the image, ports, and volume mounts
2. **Add resources**: Create new manifests in `base/` and reference them in `base/kustomization.yaml`
3. **Tune per-env**: Add patches in the overlay directories or create new components
4. **Add an environment**: Copy an overlay directory and adjust namespace/labels/patches

## Key Design Decisions

- **Components over duplicated patches**: dev and stg share `components/resource-standard/` instead of copying the same patch file
- **Secrets via envs file**: `secretGenerator` references `secret.env` (gitignored) instead of inline literals
- **Security by default**: Pod security context (runAsNonRoot, drop ALL capabilities) is set in base
- **NetworkPolicy included**: Ingress limited to port 80 from same namespace; egress limited to DNS + same namespace
