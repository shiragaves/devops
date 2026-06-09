README.md                          ← Professional landing page with module table
docs/
  module-1-inventory.md           ← Workload discovery, ADDM crawler, wave plan
  module-2-containerization.md    ← Hardening summary, Trivy results
  module-4-ingress.md             ← NGINX vs HAProxy decision, DNS cutover
  module-6-tetragon.md            ← eBPF runtime enforcement, escalation rules
  module-9-runbook.md             ← Full cutover runbook + hypercare plan
  attachments/                    ← Your original .docx and .pptx files
docker/
  Dockerfile                      ← Multi-stage hardened image
  docker-compose.onprem.yml
kubernetes/
  base/ ingress/ network/         ← All K8s manifests (deployment, HPA, PDB,
  security/ hpa-pdb/                 NetworkPolicy, Cilium, Tetragon, Workload Identity)
helm/
  values-aks-prod.yaml
  values-aks-nonprod.yaml
iac/terraform/main.tf             ← Full AKS Terraform (private cluster, Cilium, ACR, KV)
cicd/github-actions-aks.yml       ← 3-job pipeline with Trivy gate + prod approval
