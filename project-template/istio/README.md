# README.md

## Prerequisites

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
kubectl create ns istio-system
kubectl create ns istio-ingress
```

## Istio

```bash
# install istio crd
helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
helm install istiod istio/istiod -n istio-system --wait --set _internal_defaults_do_not_set.nodeSelector.tier=mgmt

# install external gateway
helm upgrade --install \
  --create-namespace \
  --namespace istio-ingress \
  external-istio-ingress istio/gateway \
  -f external-values.yaml \
  --version=1.27.1

# install internal gateway
helm upgrade --install \
  --create-namespace \
  --namespace istio-ingress \
  internal-istio-ingress istio/gateway \
  -f internal-values.yaml \
  --version=1.27.1

# create gateway resources
kubectl apply -n istio-ingress -f external-gateway.yml
kubectl apply -n istio-ingress -f internal-gateway.yml

# create authorizationpolicy(optional)
kubectl apply -n istio-ingress -f allow-external-authorizationpolicy.yml
kubectl apply -n istio-ingress -f deny-external-authorizationpolicy.yml

# create envoyfilter(optional)
kubectl apply -n istio-ingress -f external-envoyfilter.yml
kubectl apply -n istio-ingress -f internal-envoyfilter.yml
```
