---
title: Phase 0 - Azure 資源建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 10
permalink: /storage/3node-ceph/phase-0/
---

# Phase 0 — Azure 資源建立

## 環境概覽

| 節點 | Azure VM | Public IP (shared-node-subnet) | Cluster IP (mansion-ceph-cluster-subnet) | 角色 |
|------|----------|--------------------------------|----------------------------------|------|
| ceph-node-01 | Standard_D4s_v4 (4C/16G) | 10.10.10.21 | 172.10.10.21 | MON + MGR + OSD x2 |
| ceph-node-02 | Standard_D4s_v4 (4C/16G) | 10.10.10.22 | 172.10.10.22 | MON + MGR + OSD x2 |
| ceph-node-03 | Standard_D4s_v4 (4C/16G) | 10.10.10.23 | 172.10.10.23 | MON + MGR + OSD x2 |

**Public Network（共用節點子網）:** 10.10.10.0/24 (`shared-node-subnet`，與 KubeVirt K8s 節點共用，KubeVirt 使用 .10-.12，Ceph 使用 .21-.23)  
**Cluster Network（Ceph 專屬）:** 172.10.10.0/24 (`mansion-ceph-cluster-subnet`)

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
| Region | 預設 `japaneast`（Japan East） |
| VNet（**既存**，由 KubeVirt lab 建立） | `mansion-shared-vnet` |
| Address space（主，KubeVirt 節點/overlay） | `10.10.0.0/16` |
| Address space（次，Ceph cluster subnet 預留） | `172.10.0.0/16` |
| Public subnet（**既存**，共用節點子網） | `shared-node-subnet` / `10.10.10.0/24` |
| Cluster subnet（**新建**，Ceph 專屬） | `mansion-ceph-cluster-subnet` / `172.10.10.0/24` |
| SSH user | `ubuntu` |
| SSH public key | 由使用者提供 |
| NSG | `mansion-ceph-nsg` |
| NSG allowed source | 使用者的固定 Public IP 或 CIDR |
| MCP API port | `8000/tcp`（僅允許 `allowedSourceCidr` 來源） |

> **共用 VNet 說明：** `mansion-shared-vnet` 與 `shared-node-subnet` 為既存資源，由 KubeVirt lab 的 Phase 0 負責建立。Ceph lab 部署前必須確認這兩個資源可被目前訂閱存取。Ceph Phase 0 會在 `mansion_ceph_resource` 內建立 Ceph VM/NIC/NSG，並在共用 VNet 中建立/管理 `mansion-ceph-cluster-subnet`。

> Phase 0 Azure 物件命名採用與 KubeVirt lab 一致的風格（小寫 + hyphen），方便在共用訂閱中辨識

---

## Bicep 部署生命週期（推薦流程）

### 步驟 1：準備本地 Azure / MCP / Bicep 環境

- 確認已安裝 Copilot CLI、Azure CLI、Bicep 工具
- 登入 Azure 帳號，設定正確訂閱

### 步驟 2：準備 Ceph Phase 0 Bicep 檔案

> 本 repo 已提供 Ceph Phase 0 所需的 IaC 檔案，請直接使用 `storage/3node-ceph/iac/` 內的 `README.md`、`main.bicep` 與 `main.bicepparam`。部署前請依實際環境覆寫 `allowedSourceCidr`、`adminPublicKey` 與必要的 region / naming 參數。

### 步驟 3：確認 KubeVirt lab 已部署（前置條件）

> Ceph Phase 0 依賴 KubeVirt lab 所建立的共用資源。在執行 Ceph 部署前，請確認 `mansion-shared-vnet` 與 `shared-node-subnet` 已存在且可存取：
> - `mansion-shared-vnet`（VNet，含 `10.10.0.0/16` 與 `172.10.0.0/16` 兩個 address space）
> - `shared-node-subnet`（子網，`10.10.10.0/24`，KubeVirt K8s 節點已使用 .10-.12）

```bash
az network vnet show --resource-group <kubevirt-rg> --name mansion-shared-vnet --query "{name:name, addressSpace:addressSpace.addressPrefixes}" -o json
az network vnet subnet show --resource-group <kubevirt-rg> --vnet-name mansion-shared-vnet --name shared-node-subnet --query "{name:name, prefix:addressPrefix}" -o json
```

### 步驟 4：建立目標 Resource Group（若尚未存在）

```bash
az group create \
  --name mansion_ceph_resource \
  --location japaneast
```

> 若 `mansion_ceph_resource` 已存在，此步驟可略過

### 步驟 5：預覽部署變更（what-if）

> **建議操作：請以 Copilot CLI 協調 Azure MCP 進行 Bicep 部署全流程。下方 az deployment group 指令僅供底層等效指令參考或本地驗證，非推薦主流程。**

```bash
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 步驟 6：正式部署（create）

```bash
az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 步驟 7：查詢輸出與資源狀態

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
- ✅ 雙網路互通（10.10.10.2x + 172.10.10.2x）
- ✅ NSG 允許 SSH（22/tcp）與 MCP API（8000/tcp），且來源仍受 `allowedSourceCidr` 限制
