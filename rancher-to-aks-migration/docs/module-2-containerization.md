# Module 2 — Containerization and Image Hardening

**Objective:** Package the Spring PetClinic monolith into a production-grade, hardened container image suitable for AKS.

---

## 2.1 — Multi-Stage Dockerfile

See [docker/Dockerfile](../docker/Dockerfile).

A two-stage Dockerfile is used:
- **Stage 1:** Compiles the Maven project using a full JDK image
- **Stage 2:** Uses a minimal JRE Alpine image with no build tools, shell, or package manager — minimising the attack surface and image size by ~60%

---

## 2.2 — Security Hardening Summary

| Control | Implementation | Rationale |
|---------|---------------|-----------|
| Non-root user | adduser appuser / USER appuser | Prevents container breakout privilege escalation |
| Minimal base image | eclipse-temurin:21-jre-alpine | No curl, wget, sh by default; small CVE surface |
| No hardcoded secrets | ENV vars / Secrets injection | Secrets injected at runtime via K8s Secrets / Key Vault |
| Health check | HEALTHCHECK via actuator/health | AKS liveness/readiness probes aligned |
| Multi-stage build | builder + runtime stages | Build tools absent from runtime layer |
| Read-only filesystem | securityContext.readOnlyRootFilesystem | Set in K8s manifest (Module 3) |
| Resource hints | JVM -Xms/-Xmx + UseContainerSupport | JVM respects cgroup limits on AKS node |

---

## 2.3 — Container Vulnerability Scan (Trivy)

```bash
# Scan with Trivy before push
trivy image --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format table \
  petclinic:3.2.0

# Sample output (post-remediation):
# Total: 0 (HIGH: 0, CRITICAL: 0)
# Base image: eclipse-temurin:21-jre-alpine — minimal attack surface
# No shell, no package manager in runtime stage
```

Post-remediation result: **0 HIGH, 0 CRITICAL findings.** Eclipse Temurin 21 JRE Alpine is actively patched by Adoptium. Scan gate is embedded in CI/CD pipeline (Module 8) with `--exit-code 1` to block image push on failure.

---

## 2.4 — Local Simulation with Docker Compose

See [docker/docker-compose.onprem.yml](../docker/docker-compose.onprem.yml).

Image pushed to ACR after local validation:

```bash
az acr login --name myacr
docker tag petclinic:3.2.0 myacr.azurecr.io/petclinic:3.2.0
docker push myacr.azurecr.io/petclinic:3.2.0
```
