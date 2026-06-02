# common (infrastructure/app)

Shared Helm **library chart** (`type: library`) for the example apps under
`infrastructure/app/*`. This is a **separate copy** of the templates in
`charts/common/` so the `app/` subtree can evolve independently of the
published `charts/` registry. Both copies currently pin to version `0.3.0`.

Not installable on its own. Consumed via `file://../common`:

```yaml
# infrastructure/app/<name>/Chart.yaml
dependencies:
  - name: common
    version: "0.3.0"
    repository: "file://../common"
```

Provided templates mirror `charts/common/` exactly — same helpers
(`common.{name,fullname,labels,…}`) and the same includable templates
(`common.service`, `common.serviceaccount`, `common.configmap`,
`common.secret`, `common.hpa`, `common.pdb`, `common.virtualservice`).
See `charts/common/README.md` for the full reference.

## Why a separate copy?

`charts/` ships publishable Helm charts; consumers outside this repo pin
to `charts/common` versions on the registry. `infrastructure/app/` is the
internal cluster-side example tree — uat/prod ApplicationSet auto-discovery
target. Keeping a parallel `common` here means a template change made for
an in-cluster example never accidentally rolls out to external consumers.

When a template change applies to both sides, copy the change deliberately
to keep them in sync.
