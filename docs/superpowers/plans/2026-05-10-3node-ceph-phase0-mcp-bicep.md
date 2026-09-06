# 3-Node Ceph Phase 0 MCP Bicep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revise the `storage/3node-ceph/` Phase 0 documentation so it recommends Azure MCP + Bicep, not direct Azure CLI as the primary workflow, and standardize naming around `mansion_ceph_resource` and `mansion_` prefixes.

**Architecture:** Keep the change tightly scoped to Ceph Phase 0 docs and adjacent navigation. Rewrite `phase-0.md` around MCP + Bicep roles and deployment lifecycle, convert the Azure section of `commands.md` into Bicep-oriented deployment and verification commands, and align `buildup.md` plus the project landing page so they describe the new recommendation consistently.

**Tech Stack:** Markdown, Jekyll front matter, Mermaid, Azure CLI command examples, Bicep workflow documentation, git

---

### Task 1: Rewrite Phase 0 as Azure MCP + Bicep

**Files:**
- Modify: `storage/3node-ceph/phase-0.md`

- [ ] **Step 1: Review the current Phase 0 wording**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
sed -n '1,260p' storage/3node-ceph/phase-0.md
```

Expected: The page currently presents `Azure MCP / Azure CLI` together and uses direct `az group create`, `az network nic create`, `az vm create`, and `az vm disk attach` commands as the main path.

- [ ] **Step 2: Replace the build-mode section with MCP + Bicep wording**

Update the section around `## 建置模式` and `## Azure MCP / Azure CLI 建立流程` so it becomes:

```md
## 建置模式

> ⚠️ **本 Phase 僅提供單一選項：Azure MCP + Bicep（推薦）**

這一版 Phase 0 的推薦流程是：

- 由本地 Copilot CLI 協調 Azure MCP server
- 由 Bicep 定義 Azure 資源
- 先用 `what-if` 預覽，再用 deployment create 套用

直接 `az` command 可以作為底層工具與驗證介面，但不是這份文件的主要推薦路徑。

## Azure MCP + Bicep 建立流程
```

Expected: The page now clearly distinguishes Azure MCP from raw Azure CLI.

- [ ] **Step 3: Update common inputs and naming examples**

Replace the current Phase 0 naming examples so the page uses:

```md
| 項目 | 值 |
|------|----|
| Resource Group | `mansion_ceph_resource` |
| VNet | `mansion_ceph_vnet` |
| Public subnet | `mansion_ceph_public_subnet` |
| Cluster subnet | `mansion_ceph_cluster_subnet` |
| NSG | `mansion_ceph_nsg` |
```

Also add a short note stating:

```md
> 命名規則：Phase 0 相關 Azure 物件優先使用 `mansion_` prefix，方便在共用 subscription 中辨識。
```

Expected: Resource group and related object names consistently use the `mansion_` prefix.

- [ ] **Step 4: Replace imperative resource-creation steps with Bicep lifecycle steps**

Replace the per-resource `az network nic create` / `az vm create` / `az vm disk attach` steps with a sequence like:

```md
### Step 0-1：準備本地 Azure / MCP / Bicep
### Step 0-2：準備或調整 Ceph Phase 0 Bicep
### Step 0-3：執行 `what-if`
### Step 0-4：執行 deployment create
### Step 0-5：查詢 outputs 與 Azure 資源
```

Include command examples such as:

```bash
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file main.bicep \
  --parameters main.bicepparam

az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Expected: The page now documents a Bicep deployment lifecycle rather than manual resource assembly.

- [ ] **Step 5: Re-read the updated page**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
sed -n '1,320p' storage/3node-ceph/phase-0.md
```

Expected: The page consistently recommends Azure MCP + Bicep, uses `mansion_ceph_resource`, and no longer presents raw per-resource `az` creation commands as the main workflow.

- [ ] **Step 6: Commit the Phase 0 rewrite**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/3node-ceph/phase-0.md
git commit -m "docs: revise ceph phase0 for mcp bicep" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: One commit exists containing only the Phase 0 rewrite.

### Task 2: Convert the commands reference to Bicep deployment lifecycle

**Files:**
- Modify: `storage/3node-ceph/commands.md`

- [ ] **Step 1: Review the current Azure commands section**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
sed -n '1,240p' storage/3node-ceph/commands.md
```

Expected: The file currently starts with detailed direct Azure CLI resource creation commands.

- [ ] **Step 2: Replace direct resource-creation blocks with Bicep-oriented command groups**

Rewrite the top Azure section so it uses grouped subsections like:

```md
## Azure Phase 0（Azure MCP + Bicep）

### Bicep 檔案與參數準備
### What-If 預覽
### 套用 Deployment
### 查詢 Deployment Outputs
### 查詢 VM / NIC / Disk 狀態
### 整批刪除 Resource Group
```

Include command examples such as:

```bash
# 預覽這次 Phase 0 會建立或更新哪些資源
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file main.bicep \
  --parameters main.bicepparam

# 正式套用 Ceph Phase 0 Bicep
az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file main.bicep \
  --parameters main.bicepparam

# 查看 deployment outputs
az deployment group show \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --query properties.outputs

# 查看 VM 狀態
az vm list -d -g mansion_ceph_resource -o table

# 若要整批清除資源
az group delete --name mansion_ceph_resource --yes --no-wait
```

Expected: The commands file now treats Azure CLI as the deployment/verification interface for Bicep, not as the primary imperative build flow.

- [ ] **Step 3: Normalize Azure object names**

Update command examples to prefer names such as:

```text
mansion_ceph_resource
mansion_ceph_vnet
mansion_ceph_nsg
mansion_ceph_node_01
mansion_ceph_node_01_nic_pub
mansion_ceph_node_01_nic_cls
```

Expected: The Azure examples follow the `mansion_` prefix rule consistently.

- [ ] **Step 4: Re-read the Azure section**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
sed -n '1,220p' storage/3node-ceph/commands.md
```

Expected: The Azure section is now Bicep lifecycle-oriented and no longer led by raw `az network nic create` / `az vm create` sequences.

- [ ] **Step 5: Commit the commands update**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/3node-ceph/commands.md
git commit -m "docs: revise ceph commands for mcp bicep" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: One commit exists containing only the commands rewrite.

### Task 3: Align navigation and Phase 0 references

**Files:**
- Modify: `storage/3node-ceph/buildup.md`
- Modify: `storage/3node-ceph/index.md`

- [ ] **Step 1: Review current cross-page Phase 0 wording**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
sed -n '1,120p' storage/3node-ceph/buildup.md
sed -n '1,120p' storage/3node-ceph/index.md
```

Expected: These files still describe Phase 0 generically as Azure resource creation and do not emphasize Azure MCP + Bicep.

- [ ] **Step 2: Update buildup.md Phase 0 description**

Replace the current Phase 0 row with wording like:

```md
| Phase 0 | [Azure 資源建立](/storage/3node-ceph/phase-0/) | Azure MCP + Bicep 建立 RG、VNet、NSG、雙 NIC、三磁碟 |
```

Expected: The buildup page explicitly advertises the new recommended approach.

- [ ] **Step 3: Update index.md Build Agenda Phase 0 description**

Adjust the Phase 0 row in `storage/3node-ceph/index.md` to match the new wording, for example:

```md
| [Phase 0](phase-0/) | Azure 資源建立 | Azure MCP + Bicep 建立 Azure 網路、NSG、3 台 VM 與 managed disk |
```

Expected: The project landing page and buildup page describe Phase 0 consistently.

- [ ] **Step 4: Verify all Phase 0 references are aligned**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
rg -n "Azure MCP|Azure CLI|mansion_ceph_resource|ceph-resource" storage/3node-ceph/phase-0.md storage/3node-ceph/commands.md storage/3node-ceph/buildup.md storage/3node-ceph/index.md
```

Expected:
- `Azure MCP` and `mansion_ceph_resource` appear in the updated pages
- lingering `ceph-resource` references are removed from these files
- `Azure CLI` appears only in supporting / explanatory context, not as the recommended primary path

- [ ] **Step 5: Commit the navigation alignment**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git add storage/3node-ceph/buildup.md storage/3node-ceph/index.md
git commit -m "docs: align ceph phase0 references" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: One commit exists containing only the navigation/reference wording updates.

### Task 4: Final verification and publish

**Files:**
- Verify: `storage/3node-ceph/phase-0.md`
- Verify: `storage/3node-ceph/commands.md`
- Verify: `storage/3node-ceph/buildup.md`
- Verify: `storage/3node-ceph/index.md`

- [ ] **Step 1: Verify the final file set and naming references**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
find storage/3node-ceph -maxdepth 1 -type f | sort
rg -n "mansion_ceph_resource|mansion_" storage/3node-ceph/phase-0.md storage/3node-ceph/commands.md storage/3node-ceph/buildup.md storage/3node-ceph/index.md
```

Expected: The four updated files exist, use `mansion_ceph_resource`, and include `mansion_`-prefixed naming examples.

- [ ] **Step 2: Verify the old primary workflow wording is gone**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
rg -n "Azure MCP / Azure CLI|az network nic create|az vm create|az vm disk attach" storage/3node-ceph/phase-0.md storage/3node-ceph/commands.md
```

Expected: These direct Azure CLI build patterns no longer appear as the main documented workflow in the updated pages.

- [ ] **Step 3: Push the completed documentation updates**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git push origin main
```

Expected: The updated Ceph Phase 0 documentation is published to `main`.
