# README.md

## Prerequisites

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
kubectl create ns cert-manager
```

## cert-manager

```bash
helm show values jetstack/cert-manager > cert-manager-values.yaml
helm upgrade --install \
  --namespace cert-manager \
  cert-manager jetstack/cert-manager \
  -f cert-manager-values.yaml \
  --set crds.enabled=true

# GCP
# Create gcp iam serviceaccount key to secret
kubectl create -n cert-manager secret generic gcp-dns-key --from-file=./dns01-solver.json
# Create gcp clusterissuer
kubectl apply -f gcp-clusterissuer.yaml
# Create certificate
kubectl apply -n istio-ingress -f certificate.yaml
```
