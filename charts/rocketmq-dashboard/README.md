# rocketmq-dashboard

A Helm chart for [Apache RocketMQ Studio v3.0.0](https://github.com/apache/rocketmq-dashboard/tree/v3.0.0), the successor to RocketMQ Dashboard. The chart name remains `rocketmq-dashboard`.

Version 3 uses **two application images**, a React/Nginx frontend and a Java backend, plus MySQL. This chart runs the frontend and backend together in one pod, exposes the frontend Service on port `8080`, and deploys a separate **MySQL 8.0 StatefulSet by default**, matching the upstream Compose image. An external MySQL database is optional. The backend listens on `8888` and receives `/api/` requests over loopback. RocketMQ clusters are registered through the UI; the chart does not deploy RocketMQ or seed demo data.

## Prerequisites

- Helm 3 and Kubernetes
- Nodes can pull the public application and MySQL images from Docker Hub, or from your configured mirror
- A default StorageClass for the bundled MySQL's 8Gi PVC, or a configured StorageClass / existing PVC
- An existing Secret in the release namespace for the bootstrap admin password
- Only for external database mode: an existing MySQL 8 database/user with schema/migration permissions and a database password Secret
- Istio if enabling the optional VirtualService

## Application images

The chart defaults to the maintainer's public Docker Hub images built from the upstream **v3.0.0** source:

- Backend: [`logic3579/rocketmq-dashboard-server:3.0.0`](https://hub.docker.com/r/logic3579/rocketmq-dashboard-server)
- Frontend: [`logic3579/rocketmq-dashboard-web:3.0.0`](https://hub.docker.com/r/logic3579/rocketmq-dashboard-web)

No image pull Secret or local image build is required for these public images. Override `image.*` and `frontend.image.*` to use custom builds or mirrors. For custom builds, upstream uses `server/Dockerfile` with the repository-root context and `web/Dockerfile` with the `web/` context.

The backend Dockerfile supplies the runtime MySQL driver and launches Spring Boot with `PropertiesLauncher`. The chart retains that entrypoint; replacing it with `java -jar` loses the external driver. The upstream packaged image does not include H2, so this chart uses MySQL and the `prod` profile.

## Install

The bundled MySQL creates the `rocketmq` database/user and generates password credentials automatically. Create the dashboard bootstrap admin password Secret separately, for example using ESO, Sealed Secrets, or `kubectl`:

```bash
kubectl create namespace mgmt
kubectl -n mgmt create secret generic rocketmq-dashboard-auth \
  --from-literal=password='<bootstrap-admin-password>'
```

From this repository's root, review [`infrastructure/mgmt/rocketmq-dashboard-values.yaml`](../../infrastructure/mgmt/rocketmq-dashboard-values.yaml) to configure MySQL storage, NameServer address, and HTTPS hostname. The public application image repositories are already configured. Then install locally:

```bash
helm dependency update charts/rocketmq-dashboard
helm upgrade --install rocketmq-dashboard charts/rocketmq-dashboard \
  --namespace mgmt \
  -f infrastructure/mgmt/rocketmq-dashboard-values.yaml
```

After the chart is published, use the same values with the hosted Helm repository:

```bash
helm repo add logic3579 https://logic3579.github.io/helm-charts
helm repo update
helm upgrade --install rocketmq-dashboard logic3579/rocketmq-dashboard \
  --version 3.0.0 --namespace mgmt \
  -f infrastructure/mgmt/rocketmq-dashboard-values.yaml
```

The mgmt example is standalone; this repository does not include an ArgoCD Application for this component.

## Database and login

With `mysql.enabled: true` (default), a single-replica StatefulSet runs `mysql:8.0`, uses `utf8mb4` / `utf8mb4_unicode_ci`, and creates the configured database and non-root application user. A ClusterIP Service connects the backend to MySQL; MySQL is not exposed through the VirtualService. An init container waits for an authenticated database query to succeed before starting the backend. MySQL has separate health probes and resource/security settings.

Data persists in an 8Gi StatefulSet PVC by default. Configure `mysql.persistence.{size,storageClass,accessMode}` or `existingClaim`; reused claims store MySQL data in their `mysql/` subdirectory. `persistence.enabled: false` uses ephemeral storage unless `existingClaim` is set. StatefulSet PVCs are retained on uninstall.

When `mysql.auth.existingSecret` is unset, the chart creates a credential Secret with random `root-password` and `password` keys. Helm upgrades reuse its stored credentials through `lookup`; the generated Secret is retained on uninstall or when disabling bundled MySQL, alongside retained PVCs. Keep the Secret and data together when reinstalling. Offline `helm template` cannot read an existing Secret and generates fresh passwords each time; use a separately managed `mysql.auth.existingSecret` or explicit password values for deterministic rendering. MySQL password/database/user settings initialize an empty data directory; changing Helm values or Secret data does not rotate accounts in an existing database.

To provide MySQL credentials through a secret manager, create a Secret containing both configured password keys and set `mysql.auth.existingSecret`. For example:

```yaml
mysql:
  auth:
    existingSecret: rocketmq-dashboard-mysql-auth
    # Secret keys: root-password and password
```

`mysql.initializeSchema: true` tells the backend to execute the image's `classpath:db/schema.sql` before startup. It creates Studio tables without seeding instances or demo credentials. If you initialize the schema separately from [upstream SQL](https://github.com/apache/rocketmq-dashboard/blob/v3.0.0/server/src/main/resources/db/schema.sql), set `initializeSchema: false` in the selected database mode; upstream startup migrations still require DDL permissions.

### Optional external MySQL

Disable bundled MySQL and configure the existing database. Internal MySQL settings are ignored in this mode, and no MySQL StatefulSet, Services, credential Secret, or wait init container is rendered:

```yaml
mysql:
  enabled: false
externalDatabase:
  url: "jdbc:mysql://mysql.middleware.svc.cluster.local:3306/rocketmq?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&characterEncoding=UTF-8"
  username: rocketmq
  existingSecret: rocketmq-dashboard-db
  passwordKey: password
  initializeSchema: true
```

Create the `rocketmq` database with `utf8mb4`, grant the user schema/migration permissions, and provide the `password` key in `rocketmq-dashboard-db` in the release namespace. `externalDatabase.initializeSchema` controls schema initialization in this mode. Existing data is not migrated when switching database modes.

Login is required by default. `auth.existingSecret` supplies the initial admin password. Upstream bootstraps users lazily on the first login to an empty user table; subsequent account changes belong in the Studio UI and persist in MySQL. Updating the Secret does not reset an existing account. If the admin password Secret or external database password Secret is unset, the chart injects an empty password instead of falling back to upstream demo passwords.

Secure session cookies are enabled by default, so use HTTPS on the configured gateway. For HTTP-only local testing, set `auth.sessionCookieSecure: false`, then forward the frontend:

```bash
kubectl -n mgmt port-forward svc/rocketmq-dashboard 8080:8080
```

## Configuration

`values.yaml` is the full configuration reference. Common settings include:

| Parameter | Purpose | Default |
| --- | --- | --- |
| `image.*` | Backend image; tag defaults to appVersion | `logic3579/rocketmq-dashboard-server:3.0.0` |
| `frontend.image.*` | Frontend image; tag defaults to appVersion | `logic3579/rocketmq-dashboard-web:3.0.0` |
| `service.port` | Frontend Service and Nginx port | `8080` |
| `dashboard.port` | Backend port in the same pod; must differ from frontend | `8888` |
| `dashboard.namesrvAddr` | `STUDIO_ROCKETMQ_NAMESRV_ADDR` | `127.0.0.1:9876` |
| `dashboard.prometheusUrl` | Optional Prometheus query endpoint | empty |
| `dashboard.corsAllowedOrigins` | Comma-separated browser origins | empty (same origin) |
| `dashboard.javaToolOptions` | JDK options | 65% RAM limit, user home `/tmp` |
| `mysql.enabled` | Deploy bundled MySQL; false selects external database | `true` |
| `mysql.image.*` | Bundled MySQL image, matching upstream Compose | `mysql:8.0` |
| `mysql.auth.{database,username}` | Database and non-root application user | `rocketmq` / `rocketmq` |
| `mysql.auth.{existingSecret,rootPasswordKey,passwordKey}` | Optional existing credentials Secret and keys | empty / `root-password` / `password` |
| `mysql.auth.{rootPassword,password}` | Explicit credentials; generated when empty | empty |
| `mysql.initializeSchema` | Initialize Studio tables in bundled MySQL | `true` |
| `mysql.persistence.{enabled,size}` | StatefulSet data volume | `true` / `8Gi` |
| `mysql.persistence.{storageClass,accessMode,existingClaim}` | StorageClass, access mode, or reused PVC | empty / `ReadWriteOnce` / empty |
| `mysql.resources` | MySQL resource requests and limits | See values.yaml |
| `externalDatabase.{url,username}` | Optional external JDBC URL and DB username | See values.yaml |
| `externalDatabase.{existingSecret,passwordKey}` | External DB password Secret and key | empty / `password` |
| `externalDatabase.initializeSchema` | Initialize tables in external MySQL | `true` |
| `auth.{loginRequired,username}` | Require login and initial username | `true` / `admin` |
| `auth.{existingSecret,passwordKey}` | Bootstrap admin password Secret and key | empty / `password` |
| `auth.sessionCookieSecure` | Require HTTPS for browser cookies | `true` |
| `resources`, `frontend.resources` | Per-container requests and limits | See values.yaml |
| `env`, `envFrom` | Additional backend settings and Secret references | `[]` |
| `volumes`, `volumeMounts` | Extra pod volumes and backend mounts | `[]` |
| `virtualservice.*` | Shared Istio routing and CORS; SSE has no route deadline | disabled |

All three images support `digest` overrides. The chart reuses `common` for the application Service, ServiceAccount, HPA, PDB, generic ConfigMap/Secret, and VirtualService. MySQL has distinct selectors so its pods do not receive frontend traffic. A chart-specific ConfigMap supplies the Nginx configuration and triggers a rollout when it changes.

Backend startup/liveness use `/livez`, which excludes downstream dependencies. Readiness uses `/readyz`, which includes MySQL availability. Frontend probes check `/index.html`. Nginx forwards API, OpenAPI/Swagger, and health routes, preserves SSE streaming, and blocks other Actuator routes. Its original Docker/Podman DNS entrypoint is bypassed because the backend is on loopback.

Both application containers run as UID/GID 1000 with a read-only root filesystem; bundled MySQL uses UID/GID 999 with writable data/runtime directories. Writable `emptyDir` volumes cover backend `/tmp`, backend `/app/logs`, and frontend `/tmp`; both application `/tmp` mounts use tmpfs. Database-backed settings, accounts, and conversation history persist in MySQL. Application logs and AI CLI workspaces are ephemeral. Mount a persistent volume through `volumes`/`volumeMounts` and set `STUDIO_AI_CONVERSATION_WORKSPACE_DIR` if CLI session resume must survive pod replacement. Keep one application replica for hosted-agent sessions; review session routing and schema initialization before enabling HPA. The bundled MySQL always stays at one replica.

For optional AI features, supply `STUDIO_AI_TOKEN_SECRET` (base64 encoding of at least 32 random bytes), broker admin credential references through `SPRING_APPLICATION_JSON`, and any LLM tokens through Secret references in `env` or `envFrom`. See the upstream [environment reference](https://github.com/apache/rocketmq-dashboard/blob/v3.0.0/deploy/.env.example). Explicit `env` entries take precedence over `envFrom`; configure the selected database mode's password fields with its `existingSecret` setting.
