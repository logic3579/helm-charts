# common

Shared Helm **library chart** (`type: library`) used by every app chart in this repository.
It is not installable on its own — application charts depend on it via `file://../common`:

```yaml
# charts/<app>/Chart.yaml
dependencies:
  - name: common
    version: "0.2.0"
    repository: "file://../common"
```

`common` is intentionally not published to the `logic3579/helm-charts` repo or to OCI registries.

## What it provides

### Named helpers (`_helpers.tpl`)

| Template                       | Returns                                              |
| ------------------------------ | ---------------------------------------------------- |
| `common.name`                  | Chart name, override-aware                           |
| `common.fullname`              | Release fullname (release + chart, override-aware)   |
| `common.chart`                 | `chart-version` label value                          |
| `common.labels`                | Standard Kubernetes recommended labels               |
| `common.selectorLabels`        | Subset of labels usable as a Deployment selector     |
| `common.serviceAccountName`    | Effective ServiceAccount name                        |
| `common.image`                 | Fully-qualified image string (repo + tag fallback)   |
| `common.podLabels`             | `selectorLabels` + `values.podLabels`                |

### Reusable templates

| Include                        | Renders                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------ |
| `common.service`               | `Service` shaped by `values.service.{type,port}`                                     |
| `common.serviceaccount`        | `ServiceAccount` gated on `values.serviceAccount.create`, with parameterized `automountServiceAccountToken` |
| `common.configmap`             | `ConfigMap` gated on `values.configMap.enabled` (data from `values.configMap.data`)  |
| `common.secret`                | `Secret` gated on `values.secret.enabled` (base64-encoded; see WARNING)              |
| `common.hpa`                   | `HorizontalPodAutoscaler` gated on `values.autoscaling.enabled` (CPU + optional memory) |
| `common.pdb`                   | `PodDisruptionBudget` gated on `values.podDisruptionBudget.enabled` (fails if both `minAvailable` and `maxUnavailable` are set) |
| `common.virtualservice`        | Istio `VirtualService` gated on `values.virtualservice.enabled`, with CORS support (`exact` / `prefix` / `regex`) |

### Conventions consumers rely on

App charts that depend on `common` are expected to expose at minimum:

- `image.{repository,tag,pullPolicy}`, `imagePullSecrets`
- `replicaCount`, `nameOverride`, `fullnameOverride`
- `service.{type,port}`
- `resources`, `nodeSelector`, `tolerations`, `affinity`
- `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`
- `serviceAccount.{create,name,annotations,automountServiceAccountToken}`
- `livenessProbe`, `readinessProbe`, (optional) `startupProbe`
- `volumes`, `volumeMounts`, `env`, `envFrom`
- `configMap`, `secret`, `autoscaling`, `podDisruptionBudget`, `virtualservice`

Only `deployment.yaml`, `NOTES.txt`, and the occasional chart-specific add-on (e.g. a `pvc.yaml` for
stateful charts, a `servicemonitor.yaml` for metrics exporters) need to be chart-specific. Everything
else should be a one-line include of a `common.*` template.

## Versioning

Consumers pin to an exact version (e.g. `"0.2.0"`), not a range — ranges have caused surprise
template churn in the past. Bump `common`'s `version` whenever a template's rendered output changes,
and bump every consuming chart's pinned version in the same change set.

## License

Apache-2.0.
