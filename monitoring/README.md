# Monitoring (Prometheus + Grafana)

Cluster and application monitoring via the `kube-prometheus-stack` Helm chart
(Prometheus, Grafana, node-exporter, kube-state-metrics). The application is
monitored at the pod level (CPU/RAM) — it exposes no app metrics, so no
ServiceMonitor is needed.

## Files

- `values.yaml` — chart overrides: Alertmanager disabled, Grafana exposed via a
  Classic Load Balancer (HTTP :80), Prometheus retention 3 days on a 10Gi gp3 PVC.
- `storageclass-gp3.yaml` — a `gp3` StorageClass (backed by the EBS CSI driver)
  for the Prometheus volume.

## Configuration

Overrides set in `values.yaml` on top of the chart defaults:

- Chart: `prometheus-community/kube-prometheus-stack`.
- Alertmanager: disabled.
- Grafana: `Service` type `LoadBalancer` (an internet-facing Classic LB on HTTP port 80); admin password supplied at install time, not stored in the file.
- Prometheus: 3-day retention; requests `cpu 100m` / `memory 350Mi`, limit `memory 650Mi`; 10Gi `gp3` volume.
- node-exporter and kube-state-metrics: chart defaults (they provide the node and pod metrics).

## Install

```bash
# 1. gp3 StorageClass (so the Prometheus PVC can bind)
kubectl apply -f monitoring/storageclass-gp3.yaml

# 2. install the stack (password passed at install, never committed)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/values.yaml \
  --set grafana.adminPassword='<PASSWORD>'
```

## Access Grafana

```bash
kubectl get svc -n monitoring monitoring-grafana   # wait for the LoadBalancer EXTERNAL-IP/DNS
```

Open `http://<EXTERNAL-DNS>/` in a browser and log in as `admin` with the password
set above. Use the bundled dashboards (e.g. "Kubernetes / Compute Resources /
Cluster" and "... / Namespace (Pods)") to see node and pod CPU/RAM, including the
hello-world pod.

## Verify

```bash
kubectl -n monitoring get pods
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
# then open http://localhost:9090/targets and confirm targets are "up"
```

## Teardown

```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
# this removes the Grafana Classic LB; the Prometheus EBS PVC is deleted with the namespace
```
