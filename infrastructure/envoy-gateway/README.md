# Envoy Gateway

Envoy Gateway is the Envoy project implementation for Kubernetes Gateway API.
This directory keeps infrastructure reference manifests only. It is not wired
into ArgoCD yet, and this repo does not publish a wrapper chart for Envoy
Gateway.

Gateway API models ingress traffic with these resources:

- `GatewayClass`: cluster-scoped class handled by a Gateway controller.
- `Gateway`: namespaced listener configuration and load balancer intent.
- `HTTPRoute`: HTTP host/path/header routing to Kubernetes Services.
- `ReferenceGrant`: explicit cross-namespace permission for references such as
  a Gateway in one namespace using a TLS Secret from another namespace.

## Status and Boundaries

- Envoy Gateway is a Gateway API controller implementation. The Gateway API
  implementation list currently marks Envoy Gateway as partially conformant, so
  validate required features before replacing Istio traffic rules.
- This is a parallel Gateway API reference path. It does not replace the
  current Istio `VirtualService` convention used by existing charts and
  infrastructure manifests.
- Do not add Ingress resources for this stack.
- Keep install and route manifests in this directory until we intentionally add
  an ArgoCD Application.

## Files

| File | Purpose |
| --- | --- |
| `envoy-gateway-values.yaml` | Minimal values override for the official Envoy Gateway Helm chart |
| `gatewayclass.yaml` | `GatewayClass` handled by Envoy Gateway |
| `gateway-external.yaml` | External Gateway API entry point, analogous to the existing external Istio gateway |
| `gateway-internal.yaml` | Internal Gateway API entry point, analogous to the existing internal Istio gateway |
| `httproute-example.yaml` | Example application route bound to the external Gateway |
| `referencegrant-example.yaml` | Example grant for cross-namespace TLS Secret references |

## Prerequisites

```bash
kubectl create namespace envoy-gateway-system
```

The cluster must provide a `LoadBalancer` implementation. On managed clusters
this is usually provided by the cloud controller. On local or bare-metal
clusters, install MetalLB or an equivalent load balancer first.

Envoy Gateway can install Gateway API CRDs by default. If the Kubernetes
provider already manages Gateway API CRDs, check the installed Gateway API
bundle version and channel before installing Envoy Gateway:

```bash
kubectl get crd gateways.gateway.networking.k8s.io \
  -o go-template='version={{ index .metadata.annotations "gateway.networking.k8s.io/bundle-version" }} channel={{ index .metadata.annotations "gateway.networking.k8s.io/channel" }}{{ "\n" }}'
```

If the provider-managed CRDs are compatible with the Envoy Gateway release and
the resources used here, keep the provider as the CRD owner and install Envoy
Gateway with CRD installation disabled. Otherwise let the Envoy Gateway Helm
chart install the CRDs.

## Install Envoy Gateway

```bash
helm upgrade --install \
  --namespace envoy-gateway-system \
  --create-namespace \
  eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.2 \
  -f envoy-gateway-values.yaml

kubectl wait --timeout=5m \
  --namespace envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available
```

If Gateway API CRDs are provider-managed and compatible, disable chart-managed
CRDs:

```bash
helm upgrade --install \
  --namespace envoy-gateway-system \
  --create-namespace \
  eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.8.2 \
  --set crds.enabled=false \
  -f envoy-gateway-values.yaml
```

## Create Gateways

Create the GatewayClass and the two shared Gateway resources:

```bash
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway-external.yaml
kubectl apply -f gateway-internal.yaml
```

Both Gateways live in `envoy-gateway-system` and allow `HTTPRoute` attachment
from all namespaces. This mirrors the current shared Istio gateway model. Use
route review and namespace ownership to prevent accidental public exposure.

The internal Gateway includes GKE internal load balancer annotations under
`spec.infrastructure.annotations`, matching the existing GKE-oriented Istio
values. Change those annotations for AWS, Azure, or another load balancer
provider before applying.

## TLS

The Gateway manifests expect a wildcard TLS Secret named
`example-wildcard-secret`.

The simplest path is to create the Secret in the same namespace as the Gateway:

```bash
kubectl -n envoy-gateway-system create secret tls example-wildcard-secret \
  --cert=./tls.crt \
  --key=./tls.key
```

If cert-manager stores the certificate in another namespace, do not reference it
directly until the target namespace grants access. Edit and apply
`referencegrant-example.yaml` in the certificate namespace, then add
`namespace: <certificate-namespace>` to the `certificateRefs` entry in the
Gateway.

## HTTPRoute Example

`httproute-example.yaml` routes `app.example.com` to a Service named `app` on
port `80` in the route's namespace:

```bash
kubectl apply -n default -f httproute-example.yaml
```

Adapt these fields for each service:

- `metadata.namespace`
- `spec.parentRefs[].name`
- `spec.parentRefs[].namespace`
- `spec.hostnames`
- `spec.rules[].matches`
- `spec.rules[].backendRefs`

Prefer one `HTTPRoute` per host or app. That keeps ownership obvious and avoids
large shared route manifests.

## Verify

Check Gateway status and the managed Envoy service:

```bash
kubectl get gateway -n envoy-gateway-system
kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-name=external-gateway
```

Get the Gateway address:

```bash
kubectl get gateway external-gateway -n envoy-gateway-system \
  -o jsonpath='{.status.addresses[0].value}{"\n"}'
```

Then test a routed host:

```bash
curl -v -H 'Host: app.example.com' http://<GATEWAY_ADDRESS>/
```

For HTTPS:

```bash
curl -v --resolve app.example.com:443:<GATEWAY_ADDRESS> \
  https://app.example.com/
```

## Notes

- Gateway listeners on privileged ports such as `80` and `443` can be mapped by
  Envoy Gateway to unprivileged container ports internally. Keep that in mind
  when debugging generated Envoy deployments.
- `spec.infrastructure.annotations` is Gateway API extended support. Confirm the
  Envoy Gateway version and cloud provider support the desired annotation before
  relying on it for production traffic.
- If this stack is later added to ArgoCD, use the official OCI chart as the
  source and keep `ServerSideApply=true` because Gateway API CRDs can exceed
  client-side apply annotation limits.

## References

- Gateway API overview: https://gateway-api.sigs.k8s.io/concepts/api-overview/
- Gateway API HTTP routing: https://gateway-api.sigs.k8s.io/guides/user-guides/http-routing/
- Gateway API TLS: https://gateway-api.sigs.k8s.io/guides/user-guides/tls/
- Gateway API implementations list: https://gateway-api.sigs.k8s.io/docs/implementations/list/#envoy-gateway
- Envoy Gateway quickstart: https://gateway.envoyproxy.io/docs/tasks/quickstart/
- Envoy Gateway Helm install: https://gateway.envoyproxy.io/docs/install/install-helm/
- Envoy Gateway ArgoCD install notes: https://gateway.envoyproxy.io/docs/install/install-argocd/
