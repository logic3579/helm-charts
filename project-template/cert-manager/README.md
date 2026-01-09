# README.md

## Prerequisites

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
```

## cert-manager

```bash
helm install \
  --create-namespace \
  --namespace cert-manager \
  cert-manager jetstack/cert-manager \
  --set crds.enabled=true

# create gcp iam serviceaccount key to secret
kubectl create -n cert-manager secret generic gcp-dns-key --from-file=./dns01-solver.json
# create gcp clusterissuer
kubectl apply -f clusterissuer-gcp.yaml

# create certificate
kubectl apply -n istio-ingress -f certificate.yaml
```
