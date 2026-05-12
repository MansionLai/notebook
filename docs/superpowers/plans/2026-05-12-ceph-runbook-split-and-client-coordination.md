# Ceph Runbook Split and Client Coordination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the Ceph cross-DC migration runbook into a MON-focused `detail_runbook.md` and a separate `osd-migration.md`, while updating the docs to reflect Rook-Ceph external mode and KubeVirt client coordination requirements.

**Architecture:** Keep the current landing page and strategy page as the navigation layer, but separate the execution layer into two documents with distinct responsibilities. `detail_runbook.md` becomes the control-plane and client-endpoint cutover guide; `osd-migration.md` becomes the rack-by-rack data-plane migration guide built from the existing OSD phase content.

**Tech Stack:** Markdown, Jekyll/Just-the-Docs front matter, git, grep

---

## File Structure

- Modify: `storage/ceph-cross-dc-migration/detail_runbook.md`
  - change the page from a mixed runbook into a MON migration runbook
  - add Rook external mode endpoint coordination and KubeVirt validation guidance
  - remove the detailed OSD phase body and replace it with links to the OSD runbook
- Create: `storage/ceph-cross-dc-migration/osd-migration.md`
  - move the existing rack-by-rack OSD execution flow into a dedicated page
  - preserve recovery throttling, gate criteria, and workload observation guidance
- Modify: `storage/ceph-cross-dc-migration/index.md`
  - update the reading guide so it links separately to the strategy page, MON runbook, and OSD runbook
- Modify: `storage/ceph-cross-dc-migration/solutions.md`
  - keep the scenario-specific recommendation
  - update related links so they point to the split runbook structure
- Verify: `docs/superpowers/specs/2026-05-12-ceph-runbook-split-and-client-coordination.md`

### Task 1: Create the dedicated OSD migration runbook

**Files:**
- Create: `storage/ceph-cross-dc-migration/osd-migration.md`
- Modify: `storage/ceph-cross-dc-migration/detail_runbook.md`
- Verify: `docs/superpowers/specs/2026-05-12-ceph-runbook-split-and-client-coordination.md`

- [ ] **Step 1: Confirm the current OSD phase content still lives in `detail_runbook.md`**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE '^## 3\\. Detailed Phase Runbook$|^### Phase 1: Add dc2 Rack o4 \\(First Batch\\)$|^### Phase 2: Remove dc1 Rack o1 \\(First Batch\\)$' storage/ceph-cross-dc-migration/detail_runbook.md
```

Expected:

- `## 3. Detailed Phase Runbook`
- `### Phase 1: Add dc2 Rack o4 (First Batch)`
- `### Phase 2: Remove dc1 Rack o1 (First Batch)`

- [ ] **Step 2: Create `osd-migration.md` with front matter and OSD-specific intro**

Create `storage/ceph-cross-dc-migration/osd-migration.md` with this opening structure:

```md
---
title: OSD Migration Runbook
parent: Ceph Cross-DC Migration
permalink: /storage/ceph-cross-dc-migration/osd-migration/
---

# OSD Migration Runbook

本文件提供跨資料中心 Ceph 遷移的 **OSD 資料面搬遷手冊**，聚焦於 rack-by-rack 的擴容、recovery、排空與移除流程。

本頁假設 MON migration 與 client endpoint coordination 由 [MON Migration Runbook](../detail_runbook/) 處理。關於遷移策略的分析與決策依據，請參考 [Solutions Overview](../solutions/)。關於場景與架構概述，請參考 [主文件](../)。

---

## 1. Migration Principles
```

- [ ] **Step 3: Move the existing OSD execution body into the new page**

Copy the current OSD-oriented sections from `detail_runbook.md` into `osd-migration.md`, keeping the OSD phases and workload observation sections. Preserve these section headings in the new page:

```md
## 1. Migration Principles
## 2. KubeVirt / RBD Notes
## 3. Detailed Phase Runbook
### Phase 0: Pre-Migration Preparation
### Phase 1: Add dc2 Rack o4 (First Batch)
### Phase 2: Remove dc1 Rack o1 (First Batch)
```

Also preserve the later rack phases already present in the source document:

```bash
grep -n '^### Phase ' storage/ceph-cross-dc-migration/detail_runbook.md
```

Expected: all existing OSD phase headings are moved into `osd-migration.md`.

- [ ] **Step 4: Add an OSD-specific closing links section**

End `osd-migration.md` with:

```md
---

## 相關連結

- **[← 回到主文件](../)**
  返回 Ceph Cross-DC Migration 主題入口，查看架構概述與場景說明

- **[← MON Migration Runbook](../detail_runbook/)**
  前往 MON runbook，處理 quorum 切換、Rook external mode 與 client endpoint coordination

- **[→ Migration Strategy Comparison](../solutions/)**
  回到策略比較頁，查看為何此場景建議先做 OSD migration，再處理 MON migration
```

- [ ] **Step 5: Verify the new OSD page contains the extracted execution flow**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE '^title: OSD Migration Runbook$|^## 3\\. Detailed Phase Runbook$|^### Phase 1: Add dc2 Rack o4 \\(First Batch\\)$|^## 相關連結$' storage/ceph-cross-dc-migration/osd-migration.md
```

Expected:

- the new title is present
- the detailed phase runbook section is present
- the first OSD phase heading is present
- the related links section is present

- [ ] **Step 6: Commit the extracted OSD runbook**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/ceph-cross-dc-migration/osd-migration.md
git commit -m "docs: add ceph osd migration runbook"
```

### Task 2: Rewrite `detail_runbook.md` as the MON migration runbook

**Files:**
- Modify: `storage/ceph-cross-dc-migration/detail_runbook.md`
- Verify: `storage/ceph-cross-dc-migration/osd-migration.md`
- Verify: `docs/superpowers/specs/2026-05-12-ceph-runbook-split-and-client-coordination.md`

- [ ] **Step 1: Confirm the current page still uses the mixed runbook title**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE '^title: Cross-DC Migration Detail Runbook$|^# Cross-DC Migration Detail Runbook$' storage/ceph-cross-dc-migration/detail_runbook.md
```

Expected:

- both the front matter title and H1 still show the old generic runbook wording

- [ ] **Step 2: Replace the page header and intro with a MON-focused version**

Rewrite the top of `storage/ceph-cross-dc-migration/detail_runbook.md` to:

```md
---
title: MON Migration Runbook
parent: Ceph Cross-DC Migration
permalink: /storage/ceph-cross-dc-migration/detail_runbook/
---

# MON Migration Runbook

本文件提供跨資料中心 Ceph 遷移的 **MON / control-plane 切換手冊**，聚焦於 quorum 驗證、Rook external mode client endpoint coordination，以及 KubeVirt / ceph-csi 在 MON endpoint 變更期間的驗證。

關於遷移策略的分析與決策依據，請參考 [Solutions Overview](../solutions/)。關於 OSD bulk data migration 的詳細步驟，請參考 [OSD Migration Runbook](../osd-migration/)。關於場景與架構概述，請參考 [主文件](../)。

---
```

- [ ] **Step 3: Replace the mixed content body with MON-specific sections**

Rebuild the document body so it uses these top-level sections:

```md
## 1. MON Migration Principles
## 2. Rook-Ceph External Mode / KubeVirt Notes
## 3. Detailed MON Migration Runbook
## 4. Gate Criteria and Rollback
## 相關連結
```

Within those sections, include these exact operational bullets:

```md
- `rook-ceph-mon-endpoints` 採先加後減
- `rook-ceph-config` 的 `mon_host` 必須包含新 MON endpoint 集合
- `csi-rbdplugin` 預設先觀察，自動吸收失敗時才分批重啟
- KubeVirt VM 驗證重點是 RBD I/O 是否持續正常，而非預設要求修改 timeout
```

- [ ] **Step 4: Add the MON sequence and client-coordination checkpoints**

In `## 3. Detailed MON Migration Runbook`, include this sequence in order:

```md
1. 備份現有 Ceph 與 Rook MON endpoint 設定
2. 新增 dc2 MON
3. 驗證新 MON 進入 quorum
4. 更新 `rook-ceph-mon-endpoints`，同時保留 dc1 + dc2 MON
5. 驗證 `rook-ceph-config` / `mon_host`
6. 檢查 `csi-rbdplugin` 與 KubeVirt VM I/O
7. 必要時分批重啟 CSI Pod
8. 確認新 endpoint 集合穩定後再移除 dc1 MON
```

- [ ] **Step 5: Add MON-specific related links**

End `detail_runbook.md` with:

```md
## 相關連結

- **[← 回到主文件](../)**
  返回 Ceph Cross-DC Migration 主題入口，查看架構概述與場景說明

- **[→ OSD Migration Runbook](../osd-migration/)**
  前往 OSD runbook，執行 rack-by-rack 的資料搬遷、recovery 與移除流程

- **[→ Migration Strategy Comparison](../solutions/)**
  回到策略比較頁，查看為何此場景建議先做 OSD migration，再處理 MON migration
```

- [ ] **Step 6: Verify the MON page no longer contains the OSD phase body**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE '^title: MON Migration Runbook$|^## 2\\. Rook-Ceph External Mode / KubeVirt Notes$|rook-ceph-mon-endpoints|csi-rbdplugin|^### Phase 1: Add dc2 Rack o4 \\(First Batch\\)$' storage/ceph-cross-dc-migration/detail_runbook.md
```

Expected:

- the MON title is present
- the Rook / KubeVirt section is present
- `rook-ceph-mon-endpoints` and `csi-rbdplugin` are present
- `### Phase 1: Add dc2 Rack o4 (First Batch)` is **absent**

- [ ] **Step 7: Commit the MON runbook rewrite**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/ceph-cross-dc-migration/detail_runbook.md
git commit -m "docs: convert detail runbook to mon migration guide"
```

### Task 3: Update landing-page and strategy-page navigation

**Files:**
- Modify: `storage/ceph-cross-dc-migration/index.md`
- Modify: `storage/ceph-cross-dc-migration/solutions.md`
- Verify: `storage/ceph-cross-dc-migration/detail_runbook.md`
- Verify: `storage/ceph-cross-dc-migration/osd-migration.md`

- [ ] **Step 1: Update the landing-page reading guide**

Replace the single runbook block in `storage/ceph-cross-dc-migration/index.md` with separate runbook entries:

```md
### 📋 Runbooks

- **[MON Migration Runbook](detail_runbook/)**
  - quorum 切換與 MON relocation
  - Rook external mode endpoint coordination
  - ceph-csi / KubeVirt 驗證與 cutover gate

- **[OSD Migration Runbook](osd-migration/)**
  - rack-by-rack OSD 擴容與移除
  - recovery / backfill 觀察與節流
  - RBD workload 影響與 gate criteria
```

- [ ] **Step 2: Update the strategy page related links**

Replace the single runbook link block at the end of `storage/ceph-cross-dc-migration/solutions.md` with:

```md
## 相關連結

- **[← 回到主文件](../)**
  返回 Ceph Cross-DC Migration 主題入口，查看架構概述與場景說明

- **[→ MON Migration Runbook](../detail_runbook/)**
  前往 MON runbook，處理 quorum 切換、Rook external mode 與 client endpoint coordination

- **[→ OSD Migration Runbook](../osd-migration/)**
  前往 OSD runbook，執行 rack-by-rack 的資料搬遷、recovery、節流與 gate 驗證
```

- [ ] **Step 3: Verify both documents expose the split navigation**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE 'MON Migration Runbook|OSD Migration Runbook|Runbooks' storage/ceph-cross-dc-migration/index.md
grep -nE 'MON Migration Runbook|OSD Migration Runbook' storage/ceph-cross-dc-migration/solutions.md
```

Expected:

- the landing page shows a `### 📋 Runbooks` block
- both the landing page and strategy page link to MON and OSD runbooks separately

- [ ] **Step 4: Commit the navigation updates**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/ceph-cross-dc-migration/index.md storage/ceph-cross-dc-migration/solutions.md
git commit -m "docs: split ceph runbook navigation"
```

### Task 4: Run final verification and publish the doc set

**Files:**
- Verify: `storage/ceph-cross-dc-migration/detail_runbook.md`
- Verify: `storage/ceph-cross-dc-migration/osd-migration.md`
- Verify: `storage/ceph-cross-dc-migration/index.md`
- Verify: `storage/ceph-cross-dc-migration/solutions.md`
- Modify: `docs/superpowers/plans/2026-05-12-ceph-runbook-split-and-client-coordination.md`

- [ ] **Step 1: Verify the key content split across all four docs**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -nE '^title: MON Migration Runbook$|rook-ceph-mon-endpoints|csi-rbdplugin|KubeVirt' storage/ceph-cross-dc-migration/detail_runbook.md
grep -nE '^title: OSD Migration Runbook$|^### Phase 1: Add dc2 Rack o4 \\(First Batch\\)$|osd_recovery_max_active|VM I/O latency' storage/ceph-cross-dc-migration/osd-migration.md
grep -nE 'MON Migration Runbook|OSD Migration Runbook' storage/ceph-cross-dc-migration/index.md
grep -nE 'MON Migration Runbook|OSD Migration Runbook' storage/ceph-cross-dc-migration/solutions.md
```

Expected:

- the MON page contains endpoint-coordination content
- the OSD page contains the extracted rack-by-rack content
- the landing page and strategy page both point to the split runbook structure

- [ ] **Step 2: Verify no stale single-runbook wording remains in the strategy and landing pages**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -n 'Detail Runbook' storage/ceph-cross-dc-migration/index.md storage/ceph-cross-dc-migration/solutions.md || true
```

Expected:

- no stale single-runbook wording remains, or any remaining match is intentional and immediately reviewed

- [ ] **Step 3: Commit the final plan file update if it changed during execution**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add docs/superpowers/plans/2026-05-12-ceph-runbook-split-and-client-coordination.md
git commit -m "docs: add ceph runbook split implementation plan"
```

- [ ] **Step 4: Push the completed documentation changes**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git push origin main
```
