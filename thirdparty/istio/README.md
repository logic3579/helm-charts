## Install istio

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update

helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
helm install istiod istio/istiod -n istio-system --wait

# internal gateway
helm upgrade --install istio-ingress-internal istio/gateway -f values-internal.yaml -n istio-ingress --wait --create-namespace --version=1.27.1
# external gateway
helm upgrade --install istio-ingress-external istio/gateway -f values-external.yaml -n istio-ingress --wait --create-namespace --version=1.27.1
```

## Install Gateway resources

```bash
kubectl apply -f gateway-internal.yaml
kubectl apply -f gateway-external.yaml
```

## Install Virtualservice

```bash
kubectl apply -f virtualservice.yaml
```
