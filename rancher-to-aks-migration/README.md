# Rancher to AKS Migration Assessment
### Kubernetes Engineer Technical Assessment — Satappa Shiragave
**Senior DevOps/Platform Engineer | 10+ Years IT Experience | 7+ Years Kubernetes**

---

## Overview

This repository contains the complete technical assessment for a **Kubernetes Engineer** role, covering a full production migration from an on-premises Rancher-managed RKE2 cluster to **Azure Kubernetes Service (AKS)** with Azure CNI / Cilium.

**Primary Workload:** [spring-projects/spring-petclinic](https://github.com/spring-projects/spring-petclinic) (Java/Spring Boot monolith)  
**Secondary Workload:** [Azure-Samples/aks-store-demo](https://github.com/Azure-Samples/aks-store-demo) (Microservices)  
**Target Platform:** AKS with Azure CNI Overlay + Cilium eBPF

---

## Assessment Modules

| Module | Topic | Location |
|--------|-------|----------|
| 1 | On-Prem Rancher Workload Discovery & Inventory | [docs/module-1-inventory.md](docs/module-1-inventory.md) |
| 2 | Containerization & Image Hardening | [docs/module-2-containerization.md](docs/module-2-containerization.md) |
| 3 | Kubernetes Manifests, Helm & Kustomize | [kubernetes/](kubernetes/) |
| 4 | Ingress Migration: NGINX & HAProxy | [docs/module-4-ingress.md](docs/module-4-ingress.md) |
| 5 | Egress & Network Security with Cilium | [kubernetes/network/](kubernetes/network/) |
| 6 | Runtime Observability with Tetragon | [docs/module-6-tetragon.md](docs/module-6-tetragon.md) |
| 7 | AKS Target Architecture & Terraform IaC | [iac/terraform/](iac/terraform/) |
| 8 | CI/CD Pipeline: Build, Scan & Deploy | [cicd/github-actions-aks.yml](cicd/github-actions-aks.yml) |
| 9 | Migration Runbook & Cutover | [docs/module-9-runbook.md](docs/module-9-runbook.md) |

---

## Repository Structure

```
rancher-to-aks-migration/
├── README.md
├── docs/                          # Module documentation
│   ├── module-1-inventory.md
│   ├── module-2-containerization.md
│   ├── module-4-ingress.md
│   ├── module-6-tetragon.md
│   └── module-9-runbook.md
├── docker/
│   └── Dockerfile                 # Multi-stage hardened image
├── kubernetes/
│   ├── base/                      # Core manifests
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── serviceaccount.yaml
│   ├── ingress/
│   │   ├── nginx-ingress.yaml
│   │   └── haproxy-ingress.yaml
│   ├── network/
│   │   ├── default-deny.yaml
│   │   ├── allow-nginx-to-petclinic.yaml
│   │   ├── allow-petclinic-to-mysql.yaml
│   │   ├── cilium-fqdn-egress.yaml
│   │   └── tetragon-tracing-policy.yaml
│   ├── security/
│   │   └── workload-identity.yaml
│   └── hpa-pdb/
│       ├── hpa.yaml
│       └── pdb.yaml
├── helm/
│   ├── values-aks-prod.yaml
│   └── values-aks-nonprod.yaml
├── iac/
│   └── terraform/
│       └── main.tf
└── cicd/
    └── github-actions-aks.yml
```

---

## Key Technical Decisions

| Area | Choice | Rationale |
|------|--------|-----------|
| CNI | Azure CNI + Cilium Overlay | eBPF networking, FQDN policies, Hubble observability |
| Outbound | NAT Gateway | Static egress IP for partner allowlisting; no SNAT exhaustion |
| Secrets | Azure Key Vault + CSI + Workload Identity | No secrets in etcd; auto-rotation every 2 min |
| Database | Azure Database for MySQL Flexible Server | Eliminates hostPath PVC portability blocker |
| Ingress | NGINX (primary) + HAProxy (edge) | AKS-native routing + legacy edge gateway coexistence |
| CI/CD Auth | OIDC Workload Identity | No long-lived secrets in GitHub Actions |
| Runtime Security | Tetragon eBPF TracingPolicy | Kernel-level syscall enforcement; Sigkill on unexpected shell exec |

---

## Candidate Background

Satappa Shiragave is a Senior DevOps/Platform Engineer with 10+ years of IT experience (7+ years Kubernetes), currently managing enterprise Kubernetes platforms (VMware TKGi, TKGs, OpenShift) at CIMB Bank Berhad. His stack includes Kubernetes, Terraform, Helm, ArgoCD, Cilium, HashiCorp Vault, Prometheus/Grafana, Jenkins, GitLab CI, and GitHub Actions.

---

*Assessment completed: June 2025*
