---
title: Phase 0 - Azure 資源建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 10
permalink: /storage/3node-ceph/phase-0/
---

# Phase 0 — Azure 資源建立

## 環境概覽

| 節點 | Azure VM | Public IP | Cluster IP | 角色 |
|------|----------|-----------|------------|------|
| ceph-node-01 | Standard_D4s_v4 (4C/16G) | 10.10.10.10 | 172.10.10.10 | MON + MGR + OSD x2 |
| ceph-node-02 | Standard_D4s_v4 (4C/16G) | 10.10.10.11 | 172.10.10.11 | MON + MGR + OSD x2 |
| ceph-node-03 | Standard_D4s_v4 (4C/16G) | 10.10.10.12 | 172.10.10.12 | MON + MGR + OSD x2 |

**Public Network:** 10.10.10.0/24 (`mansion_ceph_public_subnet`)  
**Cluster Network:** 172.10.10.0/24 (`mansion_ceph_cluster_subnet`)

---

## 建置模式

> ✅ **唯一推薦：Azure MCP + Bicep**

本 Phase 採用 Azure MCP + Bicep 為唯一建議路徑：

- 由 Copilot CLI 協調 Azure MCP server，統一資源管理
- 以 Bicep 定義所有 Azure 資源，確保可重現、可維護
- 部署前先執行 what-if 預覽變更，確認無誤再 create
- 直接 az 指令僅作為底層工具或驗證介面，非主要建議路徑

> 備註：不再提供 Portal GUI 或純 az CLI 手動逐步建立流程

---

### 共通輸入與命名範例

| 項目 | 值 |
|------|----|
| Resource Group | `mansion_ceph_resource` |
| Region | 例如 `East Asia` |
| VNet | `mansion_ceph_vnet` |
| Address space | `10.10.0.0/16` + `172.10.0.0/16` |
| Public subnet | `mansion_ceph_public_subnet` / `10.10.10.0/24` |
| Cluster subnet | `mansion_ceph_cluster_subnet` / `172.10.10.0/24` |
| SSH user | `ubuntu` |
| SSH public key | 由使用者提供 |
| NSG | `mansion_ceph_nsg` |
| NSG allowed source | 使用者的固定 Public IP 或 CIDR |

> Phase 0 Azure 物件命名建議一律加上 `mansion_` 前綴，方便在共用訂閱中辨識

---

## Bicep 部署生命週期（推薦流程）

### 步驟 1：準備本地 Azure / MCP / Bicep 環境

- 確認已安裝 Copilot CLI、Azure CLI、Bicep 工具
- 登入 Azure 帳號，設定正確訂閱

### 步驟 2：準備 Ceph Phase 0 Bicep 檔案

> **請注意：本文件假設你已經在本地專案目錄（例如 `storage/3node-ceph/iac/` 或你自訂的 IaC 目錄）準備好 Ceph Phase 0 所需的 Bicep 檔案（如 `main.bicep`、`main.bicepparam`）。請依照你的需求維護這些檔案，確保資源定義完整。**

### 步驟 3：預覽部署變更（what-if）

> **建議操作：請以 Copilot CLI 協調 Azure MCP 進行 Bicep 部署全流程。下方 az deployment group 指令僅供底層等效指令參考或本地驗證，非推薦主流程。**

```bash
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### 步驟 4：正式部署（create）

```bash
az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### 步驟 5：查詢輸出與資源狀態

- 查詢 Bicep 輸出參數、Azure 資源狀態
- 可用 az CLI、Portal、MCP 查驗

---

## 磁碟配置總覽

每台節點共 3 顆磁碟：

| 磁碟 | 裝置 | 大小 | 用途 |
|------|------|------|------|
| OS Disk | /dev/sda | 64 GiB | 作業系統與 Ceph 軟體 |
| OSD Disk 1 | /dev/sdc | 64 GiB | OSD 資料儲存 |
| OSD Disk 2 | /dev/sdd | 64 GiB | OSD 資料儲存 |

> ⚠️ `/dev/sdb` 是 Azure VM 的 temporary disk，不可用於 OSD

---

## 預期產出

- ✅ 3 台 VM 可 SSH 登入
- ✅ 每台有 2 張 NIC（public + cluster）
- ✅ 每台有 3 顆磁碟（1 OS + 2 OSD）
- ✅ Public IPs 可從外部存取
- ✅ 雙網路互通（10.10.10.x + 172.10.10.x）
- ✅ NSG 允許 SSH 與 Ceph ports
