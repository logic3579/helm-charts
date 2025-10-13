## cert-manager

install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true
```

install clusterissuer and certifacate

```bash
kubectl create -n cert-manager secret generic gcp-dns-key --from-file=./dns01-solver.json

kubectl apply -f gcp-clusterissuer.yaml
kubectl apply -f certificate.yaml
```
