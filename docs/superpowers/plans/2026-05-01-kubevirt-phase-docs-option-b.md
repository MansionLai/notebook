# KubeVirt Phase Docs + Option B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `kubernetes/3node-kubevirt/buildup.md` into phase-based documents, add Phase 0 Option B documentation, and turn `index.md` into an agenda-style landing page while preserving existing reference docs.

**Architecture:** Treat `kubernetes/3node-kubevirt/` as two parallel reading modes: a phase-by-phase build path and a reference path. Keep `architecture.md`, `commands.md`, and `flowchart.md` as horizontal references, add `phase-0.md` through `phase-6.md` as the primary build path, and convert `buildup.md` into a transitional summary page that links readers to the new structure.

**Tech Stack:** Markdown, Jekyll front matter, Just the Docs navigation, grep, git

---

## File Structure

- Modify: `kubernetes/3node-kubevirt/index.md`
  - Replace the thin landing page with an agenda page that links to all phase documents and reference docs.
- Create: `kubernetes/3node-kubevirt/phase-0.md`
  - Phase 0 only; same page contains Option A and Option B.
- Create: `kubernetes/3node-kubevirt/phase-1.md`
  - Existing Phase 1 content from `buildup.md`.
- Create: `kubernetes/3node-kubevirt/phase-2.md`
  - Existing Phase 2 content from `buildup.md`.
- Create: `kubernetes/3node-kubevirt/phase-3.md`
  - Existing Phase 3 and Phase 3.5 content from `buildup.md`, because the target navigation must stay Phase 0~6.
- Create: `kubernetes/3node-kubevirt/phase-4.md`
  - Existing Phase 4a, 4b, and 4c content from `buildup.md`, merged into one phase page.
- Create: `kubernetes/3node-kubevirt/phase-5.md`
  - Existing Phase 5 content from `buildup.md`.
- Create: `kubernetes/3node-kubevirt/phase-6.md`
  - Existing Phase 6 content from `buildup.md`.
- Modify: `kubernetes/3node-kubevirt/buildup.md`
  - Replace the full long-form guide with a transitional overview and phase links.

## Phase Mapping

- `phase-0.md` ← `## Phase 0：Azure VM 建立（Portal GUI）`
- `phase-1.md` ← `## Phase 1：OS 基礎 + kubeadm + Cilium`
- `phase-2.md` ← `## Phase 2：Multus CNI`
- `phase-3.md` ← `## Phase 3：local-path-provisioner` + `## Phase 3.5：MetalLB + Istio（Service Mesh + Ingress Gateway）`
- `phase-4.md` ← `## Phase 4a：Prometheus Stack（kube-prometheus-stack）` + `## Phase 4b：OpenSearch + OpenSearch Dashboards` + `## Phase 4c：Fluent Bit`
- `phase-5.md` ← `## Phase 5：KubeVirt + Multus NAD + multus-networkpolicy`
- `phase-6.md` ← `## Phase 6：建立 KubeVirt VM（ub24-01）並解決外網連線`

### Task 1: Create the new agenda page and phase file scaffolds

**Files:**
- Modify: `kubernetes/3node-kubevirt/index.md`
- Create: `kubernetes/3node-kubevirt/phase-0.md`
- Create: `kubernetes/3node-kubevirt/phase-1.md`
- Create: `kubernetes/3node-kubevirt/phase-2.md`
- Create: `kubernetes/3node-kubevirt/phase-3.md`
- Create: `kubernetes/3node-kubevirt/phase-4.md`
- Create: `kubernetes/3node-kubevirt/phase-5.md`
- Create: `kubernetes/3node-kubevirt/phase-6.md`

- [ ] **Step 1: Check the current baseline**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
ls kubernetes/3node-kubevirt
```

Expected:

- `phase-0.md` through `phase-6.md` do not exist yet.
- `index.md` and `buildup.md` already exist.

- [ ] **Step 2: Replace `index.md` with an agenda-style landing page**

Write this content into `kubernetes/3node-kubevirt/index.md`:

```md
---
title: 3-Node KubeVirt (Azure)
parent: Kubernetes
nav_order: 1
has_children: true
permalink: /kubernetes/3node-kubevirt/
---

# K8s 3-Node KubeVirt on Azure

這份筆記已改為 **phase 導覽式結構**。如果你要完整從 Azure 建到 KubeVirt VM，請依序閱讀 `Phase 0` 到 `Phase 6`；如果你要查整體設計或指令，請直接跳到下方參考文件。

## Build Agenda

| Phase | 主題 | 說明 |
|------|------|------|
| [Phase 0](phase-0/) | Azure 資源建立 | Azure 網路、NSG、3 台 VM、Worker 第 2 張 NIC；同頁提供 Option A / Option B |
| [Phase 1](phase-1/) | OS 基礎 + kubeadm + Cilium | 主機初始化、container runtime、kubeadm、Cilium |
| [Phase 2](phase-2/) | Multus CNI | 安裝與驗證 Multus |
| [Phase 3](phase-3/) | Storage + Ingress | local-path-provisioner、MetalLB、Istio |
| [Phase 4](phase-4/) | Observability | Prometheus、OpenSearch、Dashboards、Fluent Bit |
| [Phase 5](phase-5/) | KubeVirt 平台層 | KubeVirt、NAD、network policy |
| [Phase 6](phase-6/) | VM workload | 建立 ub24-01 VM 與外網連線處理 |

## Reference Docs

| 文件 | 用途 |
|------|------|
| [Architecture](architecture/) | 架構決策、節點角色、資源分配 |
| [Commands](commands/) | 常用安裝與操作指令 |
| [Setup Flowchart](flowchart/) | 高層安裝流程圖 |
| [Buildup Guide](buildup/) | 過渡型總覽頁與 phase 導覽 |

## Reading Guide

1. 第一次建置：從 `Phase 0` 讀到 `Phase 6`
2. 查指令：看 `Commands`
3. 查設計與 sizing：看 `Architecture`
4. 看整體流程：看 `Setup Flowchart`
```

- [ ] **Step 3: Create the seven phase file stubs with front matter and headings**

Create these files with this exact starter content:

`kubernetes/3node-kubevirt/phase-0.md`
```md
---
title: Phase 0 - Azure 資源建立
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 10
---

# Phase 0 — Azure 資源建立
```

`kubernetes/3node-kubevirt/phase-1.md`
```md
---
title: Phase 1 - OS 基礎 + kubeadm + Cilium
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 11
---

# Phase 1 — OS 基礎 + kubeadm + Cilium
```

`kubernetes/3node-kubevirt/phase-2.md`
```md
---
title: Phase 2 - Multus CNI
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 12
---

# Phase 2 — Multus CNI
```

`kubernetes/3node-kubevirt/phase-3.md`
```md
---
title: Phase 3 - Storage + Ingress
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 13
---

# Phase 3 — Storage + Ingress
```

`kubernetes/3node-kubevirt/phase-4.md`
```md
---
title: Phase 4 - Observability
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 14
---

# Phase 4 — Observability
```

`kubernetes/3node-kubevirt/phase-5.md`
```md
---
title: Phase 5 - KubeVirt 平台層
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 15
---

# Phase 5 — KubeVirt 平台層
```

`kubernetes/3node-kubevirt/phase-6.md`
```md
---
title: Phase 6 - VM Workload
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 16
---

# Phase 6 — VM Workload
```

- [ ] **Step 4: Verify the new agenda and phase files exist**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
ls kubernetes/3node-kubevirt/index.md kubernetes/3node-kubevirt/phase-*.md
```

Expected:

- `index.md`
- `phase-0.md`
- `phase-1.md`
- `phase-2.md`
- `phase-3.md`
- `phase-4.md`
- `phase-5.md`
- `phase-6.md`

- [ ] **Step 5: Commit the scaffold**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add kubernetes/3node-kubevirt/index.md kubernetes/3node-kubevirt/phase-*.md
git commit -m $'docs: add kubevirt phase document scaffold\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

### Task 2: Build `phase-0.md` with Option A and Option B

**Files:**
- Modify: `kubernetes/3node-kubevirt/phase-0.md`
- Read from: `kubernetes/3node-kubevirt/buildup.md:16-164`

- [ ] **Step 1: Copy the current Phase 0 manual content into `phase-0.md`**

Move the content under these headings from `buildup.md` into `phase-0.md`:

- `## 環境概覽`
- `## Phase 0：Azure VM 建立（Portal GUI）`
- `### Step 0-1` through `### Step 0-7`

Do not paraphrase the existing Option A steps yet; preserve the current Azure Portal instructions.

- [ ] **Step 2: Add the common-input section above the options**

Insert this block near the top of `phase-0.md`, below the main heading:

```md
## 共通輸入

| 項目 | 值 |
|------|----|
| Resource Group | `mansion_resource` |
| Region | 例如 `East Asia` |
| VNet | `mansion-k8s-vnet` |
| Address space | `10.10.0.0/16` |
| `k8s-subnet` | `10.10.10.0/24` |
| `kubevirt-subnet` | `10.10.100.0/24` |
| SSH user | `ubuntu` |
| SSH public key | 由使用者提供 |
| NSG allowed source | 使用者的固定 Public IP 或 CIDR |
```

- [ ] **Step 3: Insert the Option A / Option B chooser table**

Add this block immediately before the manual Azure Portal steps:

```md
## 建置模式

| 模式 | 適用情境 | 說明 |
|------|----------|------|
| Option A | 第一次熟悉 Azure Portal | 手動建立 RG、VNet、NSG、VM、NIC 與 IP |
| Option B | 未來重建 / 重複部署 | 在 Mac mini 上由本地 Copilot CLI 透過 Azure MCP + IaC 代執行 |
```

- [ ] **Step 4: Rename the existing manual section to Option A**

Change the current section heading:

```md
## Phase 0：Azure VM 建立（Portal GUI）
```

to:

```md
## Option A：Azure VM 建立（Portal GUI）
```

- [ ] **Step 5: Add the Option B section with Pretasks, MCP explanation, and execution flow**

Append this structure after the Option A steps:

```md
## Option B：Mac mini + Azure MCP + IaC

### Pretasks on Mac mini

1. 安裝 Azure CLI
2. 完成 `az login`
3. 確認正確 subscription
4. 安裝並啟用 Azure MCP server
5. 確認本地 Copilot CLI 可連到 Azure MCP
6. 準備 SSH public key
7. 準備 IaC 模板與參數檔
8. 確認 NSG 允許來源 IP / CIDR
9. 確認 Azure quota 與 VM SKU 可用

### MCP 架構是什麼

| 元件 | 角色 |
|------|------|
| Copilot CLI | 協調者，接收使用者指令並決定呼叫哪個工具 |
| Azure MCP server | Azure 工具入口，讓 Copilot 能操作 Azure 能力 |
| Azure API / ARM | 真正建立資源的執行端 |
| IaC（建議 Bicep） | 定義 RG、VNet、Subnet、NSG、NIC、VM 的藍圖 |
| Mac mini | 本地控制主機，承載登入狀態、MCP server 與 IaC 模板 |

### Option B 執行流程

1. 在 Mac mini 開啟本地 Copilot CLI
2. 驗證 Azure MCP 可用
3. 載入 IaC 模板與參數檔
4. 建立以下 Azure 資源：
   - Resource Group
   - VNet + 2 個 Subnet
   - NSG + inbound rules
   - 3 台 VM
   - Static Private/Public IP
   - Worker 第 2 張 NIC
   - Worker 第 2 張 NIC 的 IP forwarding
5. 回報建置結果與驗證清單

### Option B 預期輸出

- `mansion_resource`
- `mansion-k8s-vnet`
- `k8s-subnet`
- `kubevirt-subnet`
- `k8s-nsg`
- `mansion-k8s-master`
- `mansion-k8s-infra`
- `mansion-k8s-worker`
- Worker 第 2 張 NIC 與 `10.10.100.12`
```

- [ ] **Step 6: Verify Phase 0 now contains both options**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -n 'Option A：Azure VM 建立（Portal GUI）\|Option B：Mac mini + Azure MCP + IaC\|Pretasks on Mac mini\|MCP 架構是什麼' kubernetes/3node-kubevirt/phase-0.md
```

Expected:

- `phase-0.md` contains both Option A and Option B headings.
- The Pretasks and MCP explanation sections exist.

- [ ] **Step 7: Commit Phase 0**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add kubernetes/3node-kubevirt/phase-0.md
git commit -m $'docs: add kubevirt phase 0 option B guide\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

### Task 3: Extract Phase 1, Phase 2, and Phase 3 content from `buildup.md`

**Files:**
- Modify: `kubernetes/3node-kubevirt/phase-1.md`
- Modify: `kubernetes/3node-kubevirt/phase-2.md`
- Modify: `kubernetes/3node-kubevirt/phase-3.md`
- Read from: `kubernetes/3node-kubevirt/buildup.md`

- [ ] **Step 1: Fill `phase-1.md` with existing Phase 1 content**

Copy the content from:

- `## Phase 1：OS 基礎 + kubeadm + Cilium`

up to, but not including:

- `## Phase 2：Multus CNI`

into `phase-1.md`, keeping existing step headings and code blocks.

- [ ] **Step 2: Fill `phase-2.md` with existing Phase 2 content**

Copy the content from:

- `## Phase 2：Multus CNI`

up to, but not including:

- `## Phase 3：local-path-provisioner`

into `phase-2.md`.

- [ ] **Step 3: Fill `phase-3.md` with existing Phase 3 and 3.5 content**

Copy both sections:

- `## Phase 3：local-path-provisioner`
- `## Phase 3.5：MetalLB + Istio（Service Mesh + Ingress Gateway）`

into `phase-3.md`.

Use this opening structure at the top of `phase-3.md`:

```md
## 範圍

本頁整合原本的 `Phase 3` 與 `Phase 3.5`，因為兩者都屬於 storage / ingress / traffic entry 相關的基礎設施配置。
```

- [ ] **Step 4: Verify the extracted phase headings**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -n '^## ' kubernetes/3node-kubevirt/phase-1.md
grep -n '^## ' kubernetes/3node-kubevirt/phase-2.md
grep -n '^## ' kubernetes/3node-kubevirt/phase-3.md
```

Expected:

- `phase-1.md` starts with Phase 1 content only.
- `phase-2.md` starts with Phase 2 content only.
- `phase-3.md` contains both Phase 3 and Phase 3.5 content.

- [ ] **Step 5: Commit the Phase 1~3 split**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add kubernetes/3node-kubevirt/phase-1.md kubernetes/3node-kubevirt/phase-2.md kubernetes/3node-kubevirt/phase-3.md
git commit -m $'docs: split kubevirt phases 1 to 3\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

### Task 4: Extract Phase 4, Phase 5, and Phase 6 content from `buildup.md`

**Files:**
- Modify: `kubernetes/3node-kubevirt/phase-4.md`
- Modify: `kubernetes/3node-kubevirt/phase-5.md`
- Modify: `kubernetes/3node-kubevirt/phase-6.md`
- Read from: `kubernetes/3node-kubevirt/buildup.md`

- [ ] **Step 1: Fill `phase-4.md` with existing Phase 4a, 4b, and 4c content**

Copy these sections:

- `## Phase 4a：Prometheus Stack（kube-prometheus-stack）`
- `## Phase 4b：OpenSearch + OpenSearch Dashboards`
- `## Phase 4c：Fluent Bit`

into `phase-4.md`.

Add this block after the top heading:

```md
## 範圍

本頁整合原本的 `Phase 4a`、`Phase 4b`、`Phase 4c`，因為三者都屬於 observability / logging stack。
```

- [ ] **Step 2: Fill `phase-5.md` with the existing Phase 5 content**

Copy the content from:

- `## Phase 5：KubeVirt + Multus NAD + multus-networkpolicy`

up to, but not including:

- `## Phase 6：建立 KubeVirt VM（ub24-01）並解決外網連線`

into `phase-5.md`.

- [ ] **Step 3: Fill `phase-6.md` with the existing Phase 6 content**

Copy the content from:

- `## Phase 6：建立 KubeVirt VM（ub24-01）並解決外網連線`

through the end of `buildup.md` into `phase-6.md`.

- [ ] **Step 4: Verify the extracted phase headings**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -n '^## ' kubernetes/3node-kubevirt/phase-4.md
grep -n '^## ' kubernetes/3node-kubevirt/phase-5.md
grep -n '^## ' kubernetes/3node-kubevirt/phase-6.md
```

Expected:

- `phase-4.md` contains Phase 4a/4b/4c content.
- `phase-5.md` contains only Phase 5 content.
- `phase-6.md` contains only Phase 6 content.

- [ ] **Step 5: Commit the Phase 4~6 split**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add kubernetes/3node-kubevirt/phase-4.md kubernetes/3node-kubevirt/phase-5.md kubernetes/3node-kubevirt/phase-6.md
git commit -m $'docs: split kubevirt phases 4 to 6\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

### Task 5: Convert `buildup.md` into a transition page and verify the new navigation

**Files:**
- Modify: `kubernetes/3node-kubevirt/buildup.md`
- Modify: `kubernetes/3node-kubevirt/index.md`
- Modify: `kubernetes/3node-kubevirt/architecture.md`
- Modify: `kubernetes/3node-kubevirt/commands.md`
- Modify: `kubernetes/3node-kubevirt/flowchart.md`
- Verify: `kubernetes/3node-kubevirt/phase-0.md`
- Verify: `kubernetes/3node-kubevirt/phase-1.md`
- Verify: `kubernetes/3node-kubevirt/phase-2.md`
- Verify: `kubernetes/3node-kubevirt/phase-3.md`
- Verify: `kubernetes/3node-kubevirt/phase-4.md`
- Verify: `kubernetes/3node-kubevirt/phase-5.md`
- Verify: `kubernetes/3node-kubevirt/phase-6.md`

- [ ] **Step 1: Replace `buildup.md` with a transition-page version**

Rewrite `kubernetes/3node-kubevirt/buildup.md` to this structure:

```md
---
title: Buildup Guide
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 2
---

# K8s 3-Node KubeVirt on Azure — Buildup Guide

> 這份文件已改為 **phase 導覽模式**。完整步驟請改從 `Phase 0` 到 `Phase 6` 閱讀。

## Phase Navigation

| Phase | 連結 | 說明 |
|------|------|------|
| Phase 0 | [Azure 資源建立](phase-0/) | Azure VM、VNet、NSG、Worker 第 2 張 NIC；含 Option A / Option B |
| Phase 1 | [OS 基礎 + kubeadm + Cilium](phase-1/) | 主機初始化與叢集建立 |
| Phase 2 | [Multus CNI](phase-2/) | Multus 安裝與驗證 |
| Phase 3 | [Storage + Ingress](phase-3/) | local-path-provisioner、MetalLB、Istio |
| Phase 4 | [Observability](phase-4/) | Prometheus、OpenSearch、Dashboards、Fluent Bit |
| Phase 5 | [KubeVirt 平台層](phase-5/) | KubeVirt、NAD、network policy |
| Phase 6 | [VM Workload](phase-6/) | ub24-01 VM 建立與外網連線 |

## Reference Docs

- [Architecture](architecture/)
- [Commands](commands/)
- [Setup Flowchart](flowchart/)
- [Project Agenda](./)
```

- [ ] **Step 2: Verify the agenda page and transition page link to all phases**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
grep -n 'phase-0/\|phase-1/\|phase-2/\|phase-3/\|phase-4/\|phase-5/\|phase-6/' kubernetes/3node-kubevirt/index.md
grep -n 'phase-0/\|phase-1/\|phase-2/\|phase-3/\|phase-4/\|phase-5/\|phase-6/' kubernetes/3node-kubevirt/buildup.md
```

Expected:

- Both `index.md` and `buildup.md` link to all phase documents.

- [ ] **Step 3: Reorder reference-doc navigation after the phase pages**

Update front matter nav orders so the sidebar reflects the intended primary reading path:

```md
---
nav_order: 20
---
```

in `kubernetes/3node-kubevirt/architecture.md`,

```md
---
nav_order: 21
---
```

in `kubernetes/3node-kubevirt/commands.md`, and

```md
---
nav_order: 22
---
```

in `kubernetes/3node-kubevirt/flowchart.md`.

Expected:

- The sidebar order becomes `Phase 0` through `Phase 6` first, then reference docs.
- `index.md` remains the landing page and `buildup.md` remains the transition page.

- [ ] **Step 4: Run a final structure check**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
ls kubernetes/3node-kubevirt
printf '\nPHASE_HEADINGS\n'
for f in kubernetes/3node-kubevirt/phase-*.md; do echo \"== $f ==\"; grep -n '^# ' \"$f\"; done
printf '\nNAV_ORDER_AUDIT\n'
grep -n 'nav_order:' kubernetes/3node-kubevirt/index.md \
  kubernetes/3node-kubevirt/buildup.md \
  kubernetes/3node-kubevirt/architecture.md \
  kubernetes/3node-kubevirt/commands.md \
  kubernetes/3node-kubevirt/flowchart.md \
  kubernetes/3node-kubevirt/phase-*.md
```

Expected:

- `index.md`, `buildup.md`, and `phase-0.md` through `phase-6.md` all exist.
- Each phase file has the correct top heading.
- `phase-0.md` through `phase-6.md` sort ahead of the reference docs by `nav_order`.

- [ ] **Step 5: Review the final diff**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git --no-pager diff -- kubernetes/3node-kubevirt/index.md \
  kubernetes/3node-kubevirt/buildup.md \
  kubernetes/3node-kubevirt/architecture.md \
  kubernetes/3node-kubevirt/commands.md \
  kubernetes/3node-kubevirt/flowchart.md \
  kubernetes/3node-kubevirt/phase-0.md \
  kubernetes/3node-kubevirt/phase-1.md \
  kubernetes/3node-kubevirt/phase-2.md \
  kubernetes/3node-kubevirt/phase-3.md \
  kubernetes/3node-kubevirt/phase-4.md \
  kubernetes/3node-kubevirt/phase-5.md \
  kubernetes/3node-kubevirt/phase-6.md
```

Expected:

- `buildup.md` becomes a transition page.
- `index.md` becomes an agenda page.
- The reference docs move below the phase pages in sidebar ordering.
- The phase files contain the extracted detailed steps.

- [ ] **Step 6: Commit the final reorganization**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add kubernetes/3node-kubevirt/index.md \
  kubernetes/3node-kubevirt/buildup.md \
  kubernetes/3node-kubevirt/architecture.md \
  kubernetes/3node-kubevirt/commands.md \
  kubernetes/3node-kubevirt/flowchart.md \
  kubernetes/3node-kubevirt/phase-0.md \
  kubernetes/3node-kubevirt/phase-1.md \
  kubernetes/3node-kubevirt/phase-2.md \
  kubernetes/3node-kubevirt/phase-3.md \
  kubernetes/3node-kubevirt/phase-4.md \
  kubernetes/3node-kubevirt/phase-5.md \
  kubernetes/3node-kubevirt/phase-6.md
git commit -m $'docs: split kubevirt buildup into phase guides\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

- [ ] **Step 7: Hand off to branch completion**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git status --short
```

Expected:

- Only the intended phase-doc changes are present.
- Next step after implementation is to use `superpowers:finishing-a-development-branch` to merge or open a PR, then push through the selected integration path.
