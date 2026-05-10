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

**Public Network:** 10.10.10.0/24 (`ceph-public`)  
**Cluster Network:** 172.10.10.0/24 (`ceph-cluster`)

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

### Step 0-1：準備本地 Azure / MCP / Bicep 環境

- 確認已安裝 Copilot CLI、Azure CLI、Bicep 工具
- 登入 Azure 帳號，設定正確訂閱

### Step 0-2：準備或調整 Ceph Phase 0 Bicep 檔案

- 取得或編輯 `main.bicep`、`main.bicepparam`，定義所有資源

### Step 0-3：預覽部署變更（what-if）

```bash
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Step 0-4：正式部署（create）

```bash
az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Step 0-5：查詢輸出與資源狀態

- 查詢 Bicep 輸出參數、Azure 資源狀態
- 可用 az CLI、Portal、MCP 查驗

---

### Step 0-1：建立 Resource Group

```bash
az group create \
  --name ceph-resource \
  --location eastasia
```

---

### Step 0-2：建立 Virtual Network 與 Subnets

```bash
# 建立 VNet
az network vnet create \
  --resource-group ceph-resource \
  --name ceph-vnet \
  --address-prefixes 10.10.0.0/16 172.10.0.0/16 \
  --location eastasia

# 建立 public subnet
az network vnet subnet create \
  --resource-group ceph-resource \
  --vnet-name ceph-vnet \
  --name ceph-public \
  --address-prefix 10.10.10.0/24

# 建立 cluster subnet
az network vnet subnet create \
  --resource-group ceph-resource \
  --vnet-name ceph-vnet \
  --name ceph-cluster \
  --address-prefix 172.10.10.0/24
```

---

### Step 0-3：建立 Network Security Group

```bash
# 建立 NSG
az network nsg create \
  --resource-group ceph-resource \
  --name ceph-nsg \
  --location eastasia

# 允許 SSH
az network nsg rule create \
  --resource-group ceph-resource \
  --nsg-name ceph-nsg \
  --name Allow-SSH \
  --priority 100 \
  --source-address-prefixes <YOUR_IP> \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp

# 允許 Ceph MON port (6789, 3300)
az network nsg rule create \
  --resource-group ceph-resource \
  --nsg-name ceph-nsg \
  --name Allow-Ceph-MON \
  --priority 200 \
  --source-address-prefixes 10.10.0.0/16 172.10.0.0/16 \
  --destination-port-ranges 6789 3300 \
  --access Allow \
  --protocol Tcp

# 允許 Ceph OSD port (6800-7300)
az network nsg rule create \
  --resource-group ceph-resource \
  --nsg-name ceph-nsg \
  --name Allow-Ceph-OSD \
  --priority 300 \
  --source-address-prefixes 10.10.0.0/16 172.10.0.0/16 \
  --destination-port-ranges 6800-7300 \
  --access Allow \
  --protocol Tcp

# 允許內部所有流量
az network nsg rule create \
  --resource-group ceph-resource \
  --nsg-name ceph-nsg \
  --name Allow-Internal \
  --priority 1000 \
  --source-address-prefixes 10.10.0.0/16 172.10.0.0/16 \
  --destination-address-prefixes 10.10.0.0/16 172.10.0.0/16 \
  --access Allow \
  --protocol '*'
```

> ⚠️ 記得將 `<YOUR_IP>` 替換為你的 Public IP

---

### Step 0-4：建立 3 台 VM（含 2 張 NIC、3 顆磁碟）

每台 VM 需要：

- 1 張 NIC 在 `ceph-public` (10.10.10.0/24)
- 1 張 NIC 在 `ceph-cluster` (172.10.10.0/24)
- 1 顆 OS disk (64 GiB)
- 2 顆 OSD data disks (64 GiB each)

**建立 ceph-node-01:**

```bash
# 建立 Public NIC
az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-01-nic-pub \
  --vnet-name ceph-vnet \
  --subnet ceph-public \
  --network-security-group ceph-nsg \
  --private-ip-address 10.10.10.10

# 建立 Cluster NIC
az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-01-nic-cls \
  --vnet-name ceph-vnet \
  --subnet ceph-cluster \
  --private-ip-address 172.10.10.10

# 建立 Public IP
az network public-ip create \
  --resource-group ceph-resource \
  --name ceph-node-01-pip \
  --sku Standard \
  --allocation-method Static

# 將 Public IP 掛到 Public NIC
az network nic ip-config update \
  --resource-group ceph-resource \
  --nic-name ceph-node-01-nic-pub \
  --name ipconfig1 \
  --public-ip-address ceph-node-01-pip

# 建立 VM
az vm create \
  --resource-group ceph-resource \
  --name ceph-node-01 \
  --location eastasia \
  --size Standard_D4s_v4 \
  --nics ceph-node-01-nic-pub ceph-node-01-nic-cls \
  --image Ubuntu2204 \
  --os-disk-size-gb 64 \
  --admin-username ubuntu \
  --ssh-key-values "<YOUR_SSH_PUBLIC_KEY>"

# 加入 2 顆 OSD data disks
az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-01 \
  --name ceph-node-01-osd-disk1 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new

az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-01 \
  --name ceph-node-01-osd-disk2 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new
```

**建立 ceph-node-02:**

```bash
# 建立 NICs
az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-02-nic-pub \
  --vnet-name ceph-vnet \
  --subnet ceph-public \
  --network-security-group ceph-nsg \
  --private-ip-address 10.10.10.11

az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-02-nic-cls \
  --vnet-name ceph-vnet \
  --subnet ceph-cluster \
  --private-ip-address 172.10.10.11

# Public IP
az network public-ip create \
  --resource-group ceph-resource \
  --name ceph-node-02-pip \
  --sku Standard \
  --allocation-method Static

az network nic ip-config update \
  --resource-group ceph-resource \
  --nic-name ceph-node-02-nic-pub \
  --name ipconfig1 \
  --public-ip-address ceph-node-02-pip

# VM
az vm create \
  --resource-group ceph-resource \
  --name ceph-node-02 \
  --location eastasia \
  --size Standard_D4s_v4 \
  --nics ceph-node-02-nic-pub ceph-node-02-nic-cls \
  --image Ubuntu2204 \
  --os-disk-size-gb 64 \
  --admin-username ubuntu \
  --ssh-key-values "<YOUR_SSH_PUBLIC_KEY>"

# OSD disks
az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-02 \
  --name ceph-node-02-osd-disk1 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new

az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-02 \
  --name ceph-node-02-osd-disk2 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new
```

**建立 ceph-node-03:**

```bash
# 建立 NICs
az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-03-nic-pub \
  --vnet-name ceph-vnet \
  --subnet ceph-public \
  --network-security-group ceph-nsg \
  --private-ip-address 10.10.10.12

az network nic create \
  --resource-group ceph-resource \
  --name ceph-node-03-nic-cls \
  --vnet-name ceph-vnet \
  --subnet ceph-cluster \
  --private-ip-address 172.10.10.12

# Public IP
az network public-ip create \
  --resource-group ceph-resource \
  --name ceph-node-03-pip \
  --sku Standard \
  --allocation-method Static

az network nic ip-config update \
  --resource-group ceph-resource \
  --nic-name ceph-node-03-nic-pub \
  --name ipconfig1 \
  --public-ip-address ceph-node-03-pip

# VM
az vm create \
  --resource-group ceph-resource \
  --name ceph-node-03 \
  --location eastasia \
  --size Standard_D4s_v4 \
  --nics ceph-node-03-nic-pub ceph-node-03-nic-cls \
  --image Ubuntu2204 \
  --os-disk-size-gb 64 \
  --admin-username ubuntu \
  --ssh-key-values "<YOUR_SSH_PUBLIC_KEY>"

# OSD disks
az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-03 \
  --name ceph-node-03-osd-disk1 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new

az vm disk attach \
  --resource-group ceph-resource \
  --vm-name ceph-node-03 \
  --name ceph-node-03-osd-disk2 \
  --size-gb 64 \
  --sku Premium_LRS \
  --new
```

---

### Step 0-5：啟用 IP Forwarding（於 Cluster NICs）

```bash
# 啟用 IP forwarding
az network nic update \
  --resource-group ceph-resource \
  --name ceph-node-01-nic-cls \
  --ip-forwarding true

az network nic update \
  --resource-group ceph-resource \
  --name ceph-node-02-nic-cls \
  --ip-forwarding true

az network nic update \
  --resource-group ceph-resource \
  --name ceph-node-03-nic-cls \
  --ip-forwarding true
```

---

### Step 0-6：驗證建立完成

```bash
# 列出 VMs
az vm list --resource-group ceph-resource --output table

# 取得 Public IPs
az network public-ip list \
  --resource-group ceph-resource \
  --query "[].{Name:name, IP:ipAddress}" \
  --output table
```

SSH 進入三台 VM：

```bash
ssh ubuntu@<ceph-node-01-public-ip>
ssh ubuntu@<ceph-node-02-public-ip>
ssh ubuntu@<ceph-node-03-public-ip>
```

在每台 VM 確認網路與磁碟：

```bash
# 確認 2 張 NIC
ip addr show

# 應看到：
# eth0: 10.10.10.10 (或 .11, .12)
# eth1: 172.10.10.10 (或 .11, .12)

# 確認 3 顆磁碟
lsblk

# 應看到：
# sda: OS disk (64 GiB)
# sdb: temporary disk (Azure 暫存)
# sdc: OSD disk 1 (64 GiB)
# sdd: OSD disk 2 (64 GiB)
```

驗證雙網路互通：

```bash
# 從 ceph-node-01 測試
ping -c 3 10.10.10.11   # public network
ping -c 3 172.10.10.11  # cluster network
```

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
