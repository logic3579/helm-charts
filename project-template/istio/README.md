# README.md

## Prerequisites

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
```

## Istio

```bash
# install istio crd
helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
helm install istiod istio/istiod -n istio-system --wait --set _internal_defaults_do_not_set.nodeSelector.tier=mgmt

# install internal gateway
helm upgrade --install \
  --create-namespace \
  --namespace istio-ingress \
  istio-ingress-internal istio/gateway \
  -f values-internal.yaml \
  --version=1.27.1
# install external gateway
helm upgrade --install \
  --create-namespace \
  --namespace istio-ingress \
  istio-ingress-external istio/gateway \
  -f values-external.yaml \
  --version=1.27.1

# create gateway resources
kubectl apply -n istio-ingress -f gateway-internal.yml
kubectl apply -n istio-ingress -f gateway-external.yml

# create authorizationpolicy(optional)
kubectl apply -n istio-ingress -f authorizationpolicy-allow-internal.yml
kubectl apply -n istio-ingress -f authorizationpolicy-allow-external.yml

# create envoyfilter(optional)
kubectl apply -n istio-ingress -f envoyfilter-internal.yml
kubectl apply -n istio-ingress -f envoyfilter-external.yml
```
