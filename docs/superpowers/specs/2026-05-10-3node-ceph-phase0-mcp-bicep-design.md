---
title: 3-Node Ceph Phase 0 MCP Bicep Design
---

# 3-Node Ceph Phase 0 MCP Bicep Design

## Problem

目前 `storage/3node-ceph/phase-0.md` 與 `storage/3node-ceph/commands.md` 的 Azure 建置流程是以直接執行 `az` CLI 指令為主，雖然可操作，但這種寫法容易和「Azure MCP」混淆，也不符合這個主題後續可重複部署、可預覽變更、可維護的方向。

另外，Phase 0 目前使用的 Resource Group 名稱是 `ceph-resource`，需要同步調整為 `mansion_ceph_resource`，以符合目前使用者偏好的命名方式。

## Goal

將 `storage/3node-ceph/` 的 Phase 0 文件改為以 **Azure MCP + Bicep（推薦）** 為主軸，並把相關文件中的 Resource Group 名稱統一更新為 `mansion_ceph_resource`。

完成後，文件應清楚表達：

1. **直接 `az` command 不等於 Azure MCP**
2. Phase 0 的推薦做法是：
   - 由本地 Copilot CLI / Azure MCP 驅動
   - 使用 Bicep 作為 IaC 定義
3. 後續重建、刪除、比對變更時，應以 Bicep 與 `what-if` / deploy workflow 為主

## Chosen Approach

採用「**文件改版，不立即補實作檔**」的方式，先把 notebook 的導向改正：

- `phase-0.md`：改成 **Azure MCP + Bicep（推薦）**
- `commands.md`：把 Azure 區塊改為 **Bicep deployment lifecycle**
- `buildup.md`：同步調整 Phase 0 說明
- 必要時補充：
  - `what-if`
  - `deployment group create`
  - `deployment group show`
  - `group delete`

這次先不建立新的 Ceph Bicep 檔案，只先把文件導向修正為正確的推薦模式。這樣可以避免在 Ceph IaC 尚未定稿前，文件又把 CLI 流程當成主要建置方式。

## Alternatives Considered

### 1. 保留 Azure CLI，僅加一段說明「這不是 Azure MCP」

這種做法改動最小，但主流程仍然會誤導讀者把 Azure CLI 當成 Phase 0 的正式推薦做法。

**不採用原因：**
- 無法真正修正主流程的方向
- 仍然不夠可重複、不可版控
- 和 `3node-kubevirt` 的 IaC / MCP 路線不一致

### 2. 改成 Azure MCP，但不提 Bicep

這可以解決「Azure CLI 不是 MCP」的混淆，但仍然缺少 IaC 層，對後續重建、destroy、review 不夠穩定。

**不採用原因：**
- 只改控制面，不改部署模式
- 還是缺少 Bicep 的可重複部署特性

### 3. 推薦方案：Azure MCP + Bicep（採用）

把文件主流程收斂成：

- 本地準備 Azure CLI / Azure MCP / Bicep
- 用 Bicep 定義 Resource Group、VNet、Subnet、NSG、NIC、VM、Managed Disks
- 用 `what-if` 預覽變更
- 用 deployment create 套用
- 用 deployment output / Azure 查詢驗證結果

**採用原因：**
- 最符合 IaC 思維
- 和既有 `3node-kubevirt` 的方向一致
- 後續若真的補 Ceph Bicep，也不需要重寫文件結構

## Scope

### In Scope

- 更新 `storage/3node-ceph/phase-0.md`
- 更新 `storage/3node-ceph/commands.md`
- 更新 `storage/3node-ceph/buildup.md`
- 必要時更新 `storage/3node-ceph/index.md` 中對 Phase 0 的描述
- 統一 Resource Group 名稱為 `mansion_ceph_resource`

### Out of Scope

- 實際新增 Ceph 專用 Bicep template
- 實際執行 Azure 資源部署
- 調整 Phase 1 到 Phase 4 的 Ceph 安裝與 RBD 內容
- 引入第二個 Phase 0 option

## Content Design

### 1. `phase-0.md`

應改為以下結構：

1. 說明本 phase 僅提供單一選項：**Azure MCP + Bicep（推薦）**
2. 說明角色分工：
   - Copilot CLI
   - Azure MCP server
   - Bicep
   - Azure ARM
3. 說明共通輸入：
   - `mansion_ceph_resource`
   - Region
   - VNet / subnet / NIC / VM / disks baseline
4. 說明推薦流程：
   - 準備本地 Azure / MCP / Bicep
   - 撰寫或調整 Bicep
   - `what-if`
   - `deployment group create`
   - 查 output / 驗證 IP 與 NIC / disks
5. 明確寫出：
   - Azure CLI 可以當作底層命令介面
   - 但文件的推薦模式是 **MCP 驅動 + Bicep 定義**

### 2. `commands.md`

Azure 區塊應調整為以下分組：

- Bicep 目錄與參數準備
- `az deployment group what-if`
- `az deployment group create`
- `az deployment group show`
- `az vm list` / `az network nic list` / `az disk list`
- `az group delete` 作為整批清除

不再保留大量逐條 `az network nic create` / `az vm create` / `az vm disk attach` 當作主流程。

### 3. `buildup.md`

Phase 0 說明要改成：

- Azure MCP + Bicep
- 建立 Azure VM、VNet、NSG、雙 NIC、三磁碟
- 不再暗示 direct Azure CLI 是主要推薦路徑

### 4. Resource Group Naming

所有本次改動涉及 Phase 0 的文件，Resource Group 名稱統一改為：

```text
mansion_ceph_resource
```

## Expected Result

完成後，`storage/3node-ceph/` 的讀者會得到一個更一致的訊息：

1. Ceph Phase 0 的推薦做法是 **Azure MCP + Bicep**
2. 直接 `az` command 不是 Azure MCP 本身
3. `mansion_ceph_resource` 是這份文件的標準 Resource Group 名稱
4. 後續若補 Ceph 專用 IaC，文件不需要再大改方向
