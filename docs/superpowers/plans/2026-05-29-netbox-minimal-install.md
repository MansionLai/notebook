# NetBox 3-Node Minimal Resource Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Minimize local Mac mini resource usage for the existing 3-node NetBox lab by shrinking VM sizes (via recreate, not in-place resize) and updating deployment docs to a low-resource profile.

**Architecture:** Keep the same topology (1 control-plane + 2 workers) and only change sizing defaults and deployment guidance. VM disk reduction is achieved by recreating nodes with smaller disks. NetBox Helm guidance is adjusted to lower requests/limits and single-replica defaults suitable for local development.

**Tech Stack:** Markdown docs, Multipass, K3s, kubectl, Helm

---

## File Structure and Responsibilities

- `netbox/multipass-k3s-setup.md`  
  Owns VM creation defaults and K3s node bootstrap flow.
- `netbox/deployment-steps.md`  
  Owns NetBox Helm values guidance and deployment/verification steps.
- `netbox/README.md`  
  Owns top-level requirements and guide entry-point summary.

### Task 1: Update VM sizing defaults in Multipass guide

**Files:**
- Modify: `netbox/multipass-k3s-setup.md`
- Test: `netbox/multipass-k3s-setup.md` (manual doc validation)

- [ ] **Step 1: Write the failing check (current values too large)**

Run:
```bash
rg -n -- "--cpus 4|--memory 8G|--disk 50G|100GB" netbox/multipass-k3s-setup.md
```
Expected: matches exist for old large defaults.

- [ ] **Step 2: Update control-plane VM command to minimal target**

Replace the launch snippet with:
```bash
multipass launch --name k3s-control \
  --cpus 2 \
  --memory 4G \
  --disk 20G
```

- [ ] **Step 3: Update worker VM commands to minimal target**

Replace both worker launch snippets with:
```bash
multipass launch --name k3s-worker-1 \
  --cpus 1 \
  --memory 2G \
  --disk 15G

multipass launch --name k3s-worker-2 \
  --cpus 1 \
  --memory 2G \
  --disk 15G
```

- [ ] **Step 4: Add explicit note that disk shrink requires VM recreation**

Add a short warning near VM creation section:
```markdown
> 注意：Multipass 既有 VM 磁碟通常不支援原地縮小；若要縮小 disk，請刪除並以較小 `--disk` 參數重建 VM。
```

- [ ] **Step 5: Run check to verify old defaults are removed**

Run:
```bash
rg -n -- "--cpus 4|--memory 8G|--disk 50G" netbox/multipass-k3s-setup.md
```
Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add netbox/multipass-k3s-setup.md
git commit -m "docs(netbox): minimize multipass vm sizing defaults"
```

### Task 2: Update NetBox deployment values to low-resource profile

**Files:**
- Modify: `netbox/deployment-steps.md`
- Test: `netbox/deployment-steps.md` (manual doc validation)

- [ ] **Step 1: Write the failing check (HA-heavy defaults present)**

Run:
```bash
rg -n -- "replicaCount: 3|postgresql:|replicaCount: 2|size: 20Gi|cpu: 1000m|memory: 1Gi" netbox/deployment-steps.md
```
Expected: matches exist showing high-resource defaults.

- [ ] **Step 2: Replace NetBox values snippet with minimal profile**

Update values example to:
```yaml
replicaCount: 1

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

postgresql:
  enabled: true
  architecture: standalone
  primary:
    persistence:
      enabled: true
      size: 5Gi
      storageClassName: local-path

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: false
```

- [ ] **Step 3: Align deployment verification output with minimal profile**

Adjust expected pod output section to reflect single replica components (no PostgreSQL/Redis replicas):
```text
# netbox-xxx                      1/1 Running
# netbox-worker-xxx               1/1 Running
# postgresql-0                    1/1 Running
# redis-master-0                  1/1 Running
```

- [ ] **Step 4: Add low-resource troubleshooting guidance**

Add a short subsection:
```markdown
### 資源不足時的優先調整順序
1. 先下調 NetBox requests/limits
2. 再檢查 worker 可用記憶體
3. 最後才增加 VM 規格
```

- [ ] **Step 5: Run check to verify HA-heavy defaults are gone**

Run:
```bash
rg -n -- "replicaCount: 3|replicaCount: 2|size: 20Gi" netbox/deployment-steps.md
```
Expected: no matches in active example configuration.

- [ ] **Step 6: Commit**

```bash
git add netbox/deployment-steps.md
git commit -m "docs(netbox): add minimal helm resource profile"
```

### Task 3: Align top-level README requirements

**Files:**
- Modify: `netbox/README.md`
- Test: `netbox/README.md` (manual doc validation)

- [ ] **Step 1: Write the failing check (resource expectations outdated)**

Run:
```bash
rg -n -- "系統要求|3 節點|高可用|最後更新" netbox/README.md
```
Expected: existing requirements do not mention minimal local profile.

- [ ] **Step 2: Add explicit "minimal local profile" note**

Add under system requirements:
```markdown
> 本指南提供「3 節點最小化安裝」預設：Control Plane 2C/4G/20G，Workers 1C/2G/15G，適用本地開發與測試。
```

- [ ] **Step 3: Update summary wording to avoid implying production HA defaults**

Change introductory wording from HA-focused phrasing to local-lab phrasing:
```markdown
# Netbox 多節點本地部署指南
```

- [ ] **Step 4: Refresh last updated date**

Set:
```markdown
**最後更新:** 2026-05-29
```

- [ ] **Step 5: Validate README consistency**

Run:
```bash
rg -n -- "最小化安裝|2C/4G/20G|1C/2G/15G|2026-05-29" netbox/README.md
```
Expected: all new markers present.

- [ ] **Step 6: Commit**

```bash
git add netbox/README.md
git commit -m "docs(netbox): align readme with minimal 3-node profile"
```

### Task 4: End-to-end docs sanity validation

**Files:**
- Test: `netbox/multipass-k3s-setup.md`
- Test: `netbox/deployment-steps.md`
- Test: `netbox/README.md`

- [ ] **Step 1: Confirm no conflicting VM defaults remain**

Run:
```bash
rg -n -- "--cpus 4|--memory 8G|--disk 50G|100GB 可用磁盤" netbox/*.md
```
Expected: no conflicting defaults in active setup/deployment docs.

- [ ] **Step 2: Confirm minimal profile appears across all docs**

Run:
```bash
rg -n -- "2C/4G/20G|1C/2G/15G|disk.*重建|requests|limits" netbox/*.md
```
Expected: consistent minimal profile and disk-recreate guidance present.

- [ ] **Step 3: Final commit**

```bash
git add netbox/multipass-k3s-setup.md netbox/deployment-steps.md netbox/README.md
git commit -m "docs(netbox): standardize minimal 3-node install profile"
```
