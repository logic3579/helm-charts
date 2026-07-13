# Flink on Kubernetes

This directory is a standalone infrastructure reference for running Apache
Flink on Kubernetes with the Apache Flink Kubernetes Operator.

It intentionally avoids a direct JobManager/TaskManager Helm chart. For
production, Flink jobs should be managed by the operator through
`FlinkDeployment` custom resources so upgrades, savepoints, high availability,
and job status are reconciled declaratively.

## Recommendation

- Use Apache Flink Kubernetes Operator.
- Use `FlinkDeployment` in Application mode for production jobs.
- Package each production job into its own image and reference the JAR with
  `local://`.
- Use Kubernetes HA plus object storage for HA metadata, checkpoints, and
  savepoints.
- Use Session clusters only for development, SQL/ad-hoc, or low-risk shared
  environments.
- Keep this directory standalone until an explicit ArgoCD integration is added.

## Files

| File | Purpose |
| --- | --- |
| `flink-operator-values.yaml` | Minimal values override for the Apache Flink Kubernetes Operator Helm chart |
| `flinkdeployment-example.yaml` | Example production-style Application mode deployment |
| `flink-virtualservice-example.yaml` | Optional Istio VirtualService for the Flink Web UI |

## Prerequisites

```bash
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.15.0/
helm repo update
kubectl create namespace flink
```

Object storage is expected for HA/checkpoint/savepoint paths. Edit the
`gs://example-flink/...` placeholders in `flinkdeployment-example.yaml` before
applying.

## Install Flink Kubernetes Operator

```bash
helm upgrade --install \
  --namespace flink \
  --create-namespace \
  flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
  --version 1.15.0 \
  -f flink-operator-values.yaml

kubectl wait --timeout=5m \
  --namespace flink \
  deployment/flink-kubernetes-operator \
  --for=condition=Available
```

The values file restricts the operator to the `flink` namespace. If you need
multi-namespace job ownership, update `watchNamespaces` and RBAC deliberately.

## Deploy an Application Job

Build and push an image that contains the job artifact, then update
`spec.image`, `spec.flinkVersion`, and `spec.job.jarURI`:

```bash
kubectl apply -f flinkdeployment-example.yaml
kubectl -n flink get flinkdeployment example-application
```

The example uses Application mode, where the job lifecycle belongs to the
`FlinkDeployment`. This is the preferred production model for isolated,
repeatable jobs.

## Expose the Web UI

The operator creates a REST service for each deployment. For the example
deployment, apply the optional VirtualService after the deployment is ready:

```bash
kubectl apply -f flink-virtualservice-example.yaml
```

Edit the host and gateway before applying. Do not use Ingress resources in this
repository.

## Production Notes

- Use `upgradeMode: savepoint` or `last-state` for stateful jobs.
- Keep checkpoint and savepoint paths outside the pod filesystem.
- Set JobManager and TaskManager CPU/memory requests to match workload needs.
- Use pod templates for node placement, sidecars, labels, and secret mounts.
- Keep credentials in Secrets or workload identity, not inline in
  `FlinkDeployment`.
- Tune checkpoint interval, timeout, min pause, and tolerable failures per job.
- Monitor operator metrics and Flink metrics through the observability stack.

## References

- Flink Kubernetes Operator docs: https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/
- Flink Operator CR overview: https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.15/docs/custom-resource/overview/
- Flink Operator Helm install: https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/docs/operations/helm/

