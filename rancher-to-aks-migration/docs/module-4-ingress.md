# Module 4 — Ingress Migration: NGINX and HAProxy

**Objective:** Design and implement external traffic management, TLS termination, host/path routing, and ingress controller migration.

---

## 4.1 — NGINX vs HAProxy — Decision Comparison

| Dimension | NGINX Ingress | HAProxy Ingress |
|-----------|---------------|-----------------|
| Primary use | General-purpose HTTP(S) ingress, AKS native (app-routing) | High-performance TCP/HTTP LB, edge gateway scenarios |
| Protocol support | HTTP, HTTPS, gRPC, WebSocket | TCP, HTTP, HTTPS, WebSocket, gRPC |
| TLS termination | cert-manager integration, auto-renewal | Manual cert or cert-manager, SNI passthrough supported |
| Load balancing | Round-robin, IP hash, least-conn (annotation) | leastconn, roundrobin, source — native HAProxy algorithms |
| Rate limiting | Annotation-based, limited granularity | HAProxy ACLs, stick tables — fine-grained control |
| AKS support | First-class: managed addon (app routing) | Community operator; manual Helm install required |
| Recommended for | Standard AKS ingress; green-field AKS workloads | Migrating existing HAProxy edge gateways; high-traffic TCP |

**Decision:** NGINX Ingress (AKS App Routing) is the primary ingress controller for AKS workloads. HAProxy is retained at the edge for TCP-level load balancing and existing on-prem integrations that require HAProxy ACL capabilities.

---

## 4.2 — DNS Cutover Design

```bash
# Step 1: Reduce DNS TTL 48 hours before cutover
#   Current: petclinic.mycompany.com → 192.168.5.1 (on-prem LB) TTL 3600
#   Action: Set TTL to 60 seconds

# Step 2: Deploy AKS NGINX ingress, validate internally
kubectl apply -f kubernetes/ingress/nginx-ingress.yaml
curl -H "Host: petclinic.mycompany.com" https://<AKS-LB-IP>/ --resolve petclinic.mycompany.com:443:<AKS-LB-IP>
# Expected: HTTP 200 + valid TLS certificate

# Step 3: Blue/Green DNS switch (low-traffic window)
# Update DNS A record: petclinic.mycompany.com → <AKS-LB-IP>

# Step 4: Validate
curl https://petclinic.mycompany.com/actuator/health
# Expected: {"status":"UP"}

# Step 5: Monitor for 30 minutes, then decommission on-prem ingress
```

---

## 4.3 — Validation Evidence

```
kubectl describe ingress petclinic-ingress -n petclinic

Name:             petclinic-ingress
Namespace:        petclinic
Address:          20.x.x.x
Ingress Class:    nginx
Rules:
  Host                      Path  Backends
  petclinic.mycompany.com   /     petclinic:8080 (10.244.1.5:8080,10.244.2.3:8080)
TLS: petclinic-tls terminates petclinic.mycompany.com

curl -I https://petclinic.mycompany.com/
HTTP/2 200
server: nginx
strict-transport-security: max-age=15724800; includeSubDomains
```

See manifests: [kubernetes/ingress/](../kubernetes/ingress/)
