# infrastructure/app/

In-cluster **example applications** for the uat/prod ArgoCD ApplicationSets
(`infrastructure/argocd/applicationsets/{uat,prod}-apps.yaml`).

This subtree is intentionally separate from `charts/`:

| Aspect            | `charts/`                                          | `infrastructure/app/`                                |
| ----------------- | -------------------------------------------------- | ---------------------------------------------------- |
| Audience          | External Helm registry / OCI consumers             | This repo's uat/prod clusters only                   |
| Published         | Yes — `helm repo` + 3 OCI registries on every push | No — not packaged, never leaves the repo             |
| Deployed by       | ArgoCD on **mgmt only** (explicit `Application`s)  | ArgoCD on **uat / prod** (ApplicationSet generator)  |
| Versioning intent | Semver, public release cadence                     | Image-tag-tracking, internal example only            |

## Layout

```
infrastructure/app/
├── README.md
├── common/                 # Library chart (type: library, version 0.3.0)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/          # Copy of charts/common/templates/ — independent copy
│   └── README.md
├── nginx/                  # Front-end example — Docker Hardened nginx (dhi/nginx)
│   ├── Chart.yaml
│   ├── values.yaml         # Chart defaults
│   ├── values-uat.yaml     # UAT overrides (required by ApplicationSet)
│   ├── values-prod.yaml    # Prod overrides (required by ApplicationSet)
│   └── templates/
└── alpine/                 # Back-end example — alpine + BusyBox `nc` httpd loop
    ├── Chart.yaml
    ├── values.yaml
    ├── values-uat.yaml
    ├── values-prod.yaml
    └── templates/
```

## Conventions

- **Each app depends on `infrastructure/app/common`** via `file://../common`
  (NOT `charts/common`). The two `common` copies are pinned to the same
  version (`0.3.0`) but may diverge intentionally over time — a template
  change for an in-cluster example should not cascade out to external
  registry consumers.
- **Each app ships two env-specific values files** colocated with the chart:
  - `values-uat.yaml` — UAT cluster overrides
  - `values-prod.yaml` — Prod cluster overrides
  The uat/prod ApplicationSets pass both to `helm` via
  `valueFiles: [values.yaml, values-<env>.yaml]` with
  `ignoreMissingValueFiles: false`. New apps **must** ship both env files
  or syncing will fail loudly.
- **`common` is excluded** from the directory generator
  (`infrastructure/argocd/applicationsets/{uat,prod}-apps.yaml`) because
  it's a library chart (`type: library`) and has no installable resources.

## Adding a new example app

1. Create `infrastructure/app/<name>/` with:
   - `Chart.yaml` declaring a `file://../common` dependency on common 0.3.0.
   - `values.yaml` with the standard surface (`image`, `service`, `probes`,
     `autoscaling`, `virtualservice`, `podDisruptionBudget`, etc.).
   - `values-uat.yaml` and `values-prod.yaml` with the per-env overrides.
   - `templates/deployment.yaml` (chart-specific, supports `command`/`args`)
     and one-line `{{- include "common.<x>" . }}` wrappers for
     `service`/`serviceaccount`/`configmap`/`secret`/`hpa`/`pdb`/`virtualservice`,
     plus a `NOTES.txt`.
2. Run `helm dependency update infrastructure/app/<name>`.
3. Run `helm lint infrastructure/app/<name>` and a smoke
   `helm template smoke infrastructure/app/<name> -f infrastructure/app/<name>/values.yaml -f infrastructure/app/<name>/values-uat.yaml`.
4. Commit. The uat/prod ApplicationSets discover it automatically on the
   next sync — no changes needed in `infrastructure/argocd/`.

## Image-version policy

Image and chart `version` / `appVersion` track each upstream image's
**latest stable** at the time the chart was added:

| App     | `version` / `appVersion` | Image                |
| ------- | ------------------------ | -------------------- |
| `nginx` | `1.30.2`                 | `dhi/nginx:1.30.2`   |
| `alpine`| `3.23.4`                 | `alpine:3.23.4`      |

`dhi/nginx` is the Docker Hardened nginx image. The DHI catalog
currently publishes mainline-tagged images; if `dhi/nginx:1.30.2` 404s at
deploy time, switch to the actual catalog tag (e.g. `mainline`) and pin
to its digest with `crane digest`.
