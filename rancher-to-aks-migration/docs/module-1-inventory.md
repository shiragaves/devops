# Module 1 — On-Prem Rancher Workload Discovery and Inventory

**Objective:** Demonstrate ability to discover, classify, and prepare workloads for migration before touching AKS.

---

## 1.1 — Source Environment Simulation and Deployment

Environment simulated using Rancher Desktop with k3d. Spring PetClinic monolith deployed alongside MySQL StatefulSet, NGINX Ingress Controller, and HAProxy gateway into a dedicated namespace. The simulation mirrors an on-prem Rancher-managed RKE2 cluster.

- **Cluster:** k3d local (simulates Rancher RKE2 on-prem)
- **Tool:** kubectl v1.28 + Rancher Desktop
- **Namespaces:** `petclinic` | `ingress-nginx` | `haproxy` | `kube-system`

### kubectl get all -A — Evidence Summary

```
NAMESPACE       NAME                                  READY   STATUS    RESTARTS   AGE
petclinic       pod/petclinic-7d6f9b5c4-xzk9q        1/1     Running   0          12m
petclinic       pod/petclinic-7d6f9b5c4-m2p7r        1/1     Running   0          12m
petclinic       pod/mysql-0                           1/1     Running   0          15m
ingress-nginx   pod/nginx-ingress-controller-4ts8b    1/1     Running   0          20m
haproxy         pod/haproxy-ingress-7bc4d-lp9xr       1/1     Running   0          20m

petclinic       service/petclinic   ClusterIP   10.43.211.5   <none>   8080/TCP   12m
petclinic       service/mysql       ClusterIP   10.43.100.2   <none>   3306/TCP   15m
ingress-nginx   service/ingress-nginx  LoadBalancer  10.43.0.1  192.168.5.1  80:31080/TCP,443:31443/TCP
```

### URL Validation

```bash
curl -H "Host: petclinic.example.com" http://192.168.5.1/
# HTTP 200 OK — PetClinic welcome page returned
```

---

## 1.2 — ADDM-Style Inventory Crawler

The following Python crawler iterates all namespaces, extracts resource kinds, and generates structured JSON and CSV output for migration planning. This mirrors ADDM (Application Dependency and Discovery Management) tooling patterns used in enterprise migrations.

```python
#!/usr/bin/env python3
"""k8s_inventory_crawler.py - ADDM-style workload inventory for Rancher/K3s to AKS migration"""

import subprocess, json, csv, sys
from datetime import datetime

RESOURCE_KINDS = ["deployments","statefulsets","daemonsets","services",
                  "ingresses","configmaps","persistentvolumeclaims",
                  "serviceaccounts","networkpolicies","horizontalpodautoscalers"]

def run(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_namespaces():
    out = run("kubectl get ns -o jsonpath='{.items[*].metadata.name}'")
    return out.split()

def crawl_namespace(ns):
    records = []
    for kind in RESOURCE_KINDS:
        raw = run(f"kubectl get {kind} -n {ns} -o json 2>/dev/null")
        if not raw: continue
        try:
            items = json.loads(raw).get("items", [])
        except json.JSONDecodeError:
            continue
        for item in items:
            meta = item.get("metadata", {})
            spec = item.get("spec", {})
            containers = []
            for c in spec.get("template", {}).get("spec", {}).get("containers", []):
                containers.append({
                    "name": c.get("name"),
                    "image": c.get("image"),
                    "ports": [p.get("containerPort") for p in c.get("ports", [])],
                    "env_vars": [e.get("name") for e in c.get("env", [])],
                    "resources": c.get("resources", {})
                })
            records.append({
                "namespace": ns, "kind": kind,
                "name": meta.get("name"),
                "labels": meta.get("labels", {}),
                "annotations": meta.get("annotations", {}),
                "containers": containers,
                "replicas": spec.get("replicas", "N/A"),
                "timestamp": datetime.utcnow().isoformat()
            })
    return records

def write_outputs(all_records):
    with open("workload_inventory.json", "w") as f:
        json.dump(all_records, f, indent=2)
    with open("workload_inventory.csv", "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["namespace","kind","name","replicas","timestamp"])
        writer.writeheader()
        for r in all_records:
            writer.writerow({k: r.get(k,"") for k in writer.fieldnames})
    print(f"Exported {len(all_records)} resources to workload_inventory.json/csv")

if __name__ == "__main__":
    namespaces = get_namespaces()
    all_records = []
    for ns in namespaces:
        print(f"Crawling namespace: {ns}")
        all_records.extend(crawl_namespace(ns))
    write_outputs(all_records)
```

---

## 1.3 — Workload Inventory (Summary Table)

| Workload | Namespace | Type | Image | Replicas |
|----------|-----------|------|-------|----------|
| petclinic | petclinic | Deployment | petclinic:3.2.0 | 2 |
| mysql | petclinic | StatefulSet | mysql:8.0 | 1 |
| nginx-ingress | ingress-nginx | DaemonSet | ingress-nginx:1.9 | 1 |
| haproxy-gw | haproxy | Deployment | haproxytech/kubernetes-ingress:1.28 | 2 |

### Dependency Classification

| Source | Destination | Type | Port | Notes |
|--------|-------------|------|------|-------|
| petclinic pod | mysql svc | Database | 3306 | Spring DataSource URL env var |
| petclinic pod | partner-api.ext | External API | 443 | FQDN egress, requires allowlist |
| nginx-ingress | petclinic svc:8080 | Ingress | 80/443 | Host: petclinic.example.com |
| haproxy-gw | nginx-ingress | Edge LB | 80/443 | HAProxy fronts NGINX |
| petclinic pod | kube-dns (CoreDNS) | DNS | 53/UDP | Service discovery |

**Dependency Architecture Summary:**

```
HAProxy (Edge) → NGINX (Ingress Controller) → PetClinic (ClusterIP:8080) → MySQL (StatefulSet:3306)
PetClinic → external partner API (TCP 443) — FQDN: api.partner.example.com
PetClinic → CoreDNS (UDP 53) for service discovery
PetClinic reads DB credentials from Kubernetes Secret (mysql-credentials)
TLS certificate stored as tls-petclinic-secret in petclinic namespace
```

---

## 1.4 — Migration Blockers

| Blocker | Owner | Risk | Remediation |
|---------|-------|------|-------------|
| MySQL PVC (hostPath) not portable to AKS | Platform Eng. | HIGH | Migrate to Azure Database for MySQL Flexible Server |
| Secrets stored in plaintext K8s Secrets | Security | HIGH | Migrate to Azure Key Vault + CSI Secret Store driver |
| NGINX config uses Rancher-specific annotations | App Team | MEDIUM | Remap annotations to AKS NGINX Ingress equivalents |
| No resource requests/limits defined | App Team | MEDIUM | Add requests/limits in Helm values before AKS deploy |
| HAProxy references static IP not available in AKS | Network | LOW | Use Azure Load Balancer static IP annotation on AKS |

---

## 1.5 — Migration Wave Plan

| Wave | App/Service | Namespace | Dependencies | Cutover Window | Risk |
|------|-------------|-----------|--------------|----------------|------|
| 1 | MySQL (Azure DB) | petclinic-db | None | Weekend 00:00-04:00 | LOW |
| 2 | petclinic app | petclinic | MySQL (Wave 1) | Weekend 00:00-04:00 | MEDIUM |
| 3 | NGINX Ingress | ingress-nginx | petclinic svc | Weekday 22:00-24:00 | LOW |
| 4 | HAProxy edge GW | haproxy | NGINX (Wave 3) | Weekday 22:00-24:00 | MEDIUM |
| 5 | DNS cutover | N/A | All waves complete | Weekend 02:00-03:00 | LOW |
