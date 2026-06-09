# Module 9 — Rancher-to-AKS Migration Runbook and Cutover

**Objective:** Production-ready migration runbook with source-to-target mapping, wave plan, cutover procedure, rollback, and hypercare.

---

## 9.1 — Source-to-Target Resource Mapping

| Resource | On-Prem (Rancher) | AKS Target | Migration Pattern |
|----------|-------------------|------------|-------------------|
| Namespace | petclinic (k3d) | petclinic (AKS) | Rehost |
| Deployment | petclinic (NGINX) 2 replicas | petclinic (AKS) 3 replicas + HPA | Replatform |
| Database | MySQL StatefulSet + hostPath PVC | Azure Database for MySQL Flexible Server | Replatform |
| Secrets | Kubernetes Secrets (base64) | Azure Key Vault + CSI Secret Store | Refactor |
| Ingress | HAProxy edge + NGINX Ingress | Azure LB + NGINX Ingress (app routing) | Replatform |
| TLS Cert | Manual cert in tls-petclinic-secret | cert-manager + Let's Encrypt | Refactor |
| Service Account | Default SA (over-privileged) | petclinic-sa with Workload Identity | Refactor |
| Network Policy | None (open by default) | Default deny + explicit Cilium policies | Refactor |
| RBAC | Rancher project RBAC | Azure RBAC + K8s RBAC (namespace-scoped) | Replatform |
| CI/CD | Manual kubectl/Helm deploys | GitHub Actions + ArgoCD (GitOps) | Refactor |

---

## 9.2 — Migration Pattern Classification

- **Rehost (Lift & Shift):** Namespace, ConfigMaps, RBAC — same structure, new platform
- **Replatform:** Deployment, Ingress, Database — structure preserved, platform service replaces on-prem equivalent
- **Refactor:** Secrets (Key Vault), Network Policy (Cilium), CI/CD (GitOps), TLS (cert-manager) — fundamentally improved
- **Retire:** HAProxy as standalone Deployment — replaced by Azure Load Balancer + NGINX app routing

---

## 9.3 — Cutover Runbook

```
# ════════════════════════════════════════════════════════════════
# RANCHER → AKS CUTOVER RUNBOOK — Spring PetClinic
# Owner: Platform Engineering | Approver: CTO
# Cutover Window: Saturday 00:00–04:00 AEST
# ════════════════════════════════════════════════════════════════
```

### PRE-CUTOVER CHECKLIST (T-48h)

- [ ] AKS cluster provisioned and validated (`kubectl cluster-info`)
- [ ] ACR image `petclinic:3.2.0` pushed and verified
- [ ] Azure Database for MySQL seeded with data dump from on-prem
- [ ] Key Vault secrets (`db-password`, `tls-cert`) loaded and verified
- [ ] NGINX ingress deployed; AKS LB IP confirmed
- [ ] DNS TTL reduced to 60 seconds for `petclinic.mycompany.com`
- [ ] Tetragon + Hubble deployed; TracingPolicy applied
- [ ] GitHub Actions pipeline successful run on non-prod
- [ ] Smoke test checklist prepared and tested on non-prod
- [ ] Rollback plan reviewed with team; contact list confirmed
- [ ] On-prem cluster snapshots (etcd + PVC backup) completed

### CUTOVER STEPS (T=0)

```bash
# T+0:00 — Freeze on-prem traffic
kubectl scale deployment petclinic -n petclinic --replicas=0 \
  --context=rancher-cluster

# T+0:05 — Final MySQL dump and import
mysqldump -h mysql.petclinic.svc -u petclinic -p petclinic > final_dump.sql
mysql -h petclinic-db.mysql.database.azure.com -u petclinic -p petclinic < final_dump.sql

# T+0:15 — Deploy petclinic to AKS
helm upgrade --install petclinic ./helm/petclinic \
  --namespace petclinic \
  --values helm/values-aks-prod.yaml \
  --set image.tag=3.2.0 \
  --wait --timeout 10m

# T+0:20 — Validate AKS deployment
kubectl get pods -n petclinic
kubectl rollout status deploy/petclinic -n petclinic
curl -sf https://<AKS-IP>/actuator/health   # returns {"status":"UP"}

# T+0:25 — DNS switch
# Update DNS A record: petclinic.mycompany.com → <AKS-LB-IP>

# T+0:30 — Validate DNS propagation
dig petclinic.mycompany.com +short          # should return AKS IP
curl -sf https://petclinic.mycompany.com/actuator/health

# T+0:35 — Business validation
# Run functional smoke tests from smoke_test_checklist
# Confirm CRUD operations on PetClinic (owners, pets, visits)
# Confirm response times < 2s (p95)
```

### ROLLBACK STEPS (if needed within T+2h)

```bash
helm rollback petclinic -n petclinic --kube-context aks-prod-cluster
# OR
kubectl scale deployment petclinic --replicas=2 --context=rancher-cluster  # restore on-prem
# Revert DNS A record to on-prem LB IP
# Set DNS TTL back to 3600
```

---

## 9.4 — Smoke Test Checklist

| Test | Method | Expected | Owner |
|------|--------|----------|-------|
| Application health endpoint | curl /actuator/health | HTTP 200, status UP | Platform |
| TLS certificate valid | openssl s_client verify | Valid cert, correct CN | Platform |
| Create owner (CRUD) | Browser + curl POST | Owner saved in MySQL | App Dev |
| List pets / visits | Browser + curl GET | Correct data returned | App Dev |
| Response time p95 < 2s | k6 load test (100 VU) | p95 < 2000ms | SRE |
| HPA scales up under load | kubectl get hpa -w | Replicas increase to 4+ | Platform |
| Blocked egress denied | kubectl exec curl unapproved | Connection timed out | Security |
| Tetragon events flowing | tetra getevents --namespace | Process events visible | Platform |

---

## 9.5 — Hypercare Plan

- **Duration:** 72 hours post-cutover
- **Dashboard:** Azure Monitor workbook (`petclinic-migration-hypercare`) — pod health, request rate, error rate, DB connections
- **Alerting:** PagerDuty — Error rate > 1% (P1), p95 latency > 3s (P2), pod restarts > 3 in 5min (P2)
- **Escalation:** L1 On-call SRE → L2 Platform Eng → L3 App Dev Lead → CTO
- **Decommission:** On-prem Rancher resources retired after 72h clean hypercare; DNS TTL restored to 3600
