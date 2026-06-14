---
title: 3-Node Ceph Design
---

# 3-Node Ceph on Azure Design

## Problem

目前 notebook repo 已有 `kubernetes/3node-kubevirt/` 作為 Azure 三節點實驗環境筆記範本，但還沒有對應的 Ceph cluster 主題。這次要新增一組同樣偏向 lab / walkthrough 的 Ceph 筆記，目標是在 Azure 上建立 3 台 VM，將 Ceph 的 public network 與 internal replication network 分開，並記錄從 VM 建立到 Ceph cluster 與 RBD pool 可用的完整流程。

## Goal

新增 `storage/3node-ceph/` 主題，採用與 `3node-kubevirt` 相近的文件結構與 phase 導覽模式，覆蓋以下範圍：

1. 透過 Azure 建立 3 台 Ceph VM
2. 每台 VM 使用 2 張 NIC，分離：
   - public / OS network：`10.10.10.0/24`
   - cluster / internal sync network：`172.10.10.0/24`
3. 每台 VM 至少有 3 顆磁碟：
   - 1 顆 OS disk
   - 2 顆 OSD data disk
4. 安裝並建立 `Ceph v19.2.2` 三節點 cluster
5. 建立一個 RBD pool，並記錄 `size`、`min_size`、`pg_num`、`pgp_num` 的初始設定

## Chosen Approach

採用與 `kubernetes/3node-kubevirt` 同風格的 **phase-oriented notebook**，但針對 Ceph 收斂為單一路徑：

- 主題路徑：`storage/3node-ceph/`
- Phase 0 只保留一個做法：**Use Azure MCP / Azure CLI to create VM**
- 文件重點放在：
  - Azure VM / network / disk baseline
  - Ceph `v19.2.2`
  - `public_network` 與 `cluster_network` 分離
  - 建立 `rbdpool`

此設計偏向 **3-node all-in-one Ceph lab baseline**：三台節點都同時承載 `MON + MGR + OSD`，讓文件結構簡單、步驟清楚，適合作為第一版實驗筆記。

## Alternatives Considered

### 1. 泛化為可調 node / disk 數量的 Ceph 通用筆記

將文件寫成較抽象的通用部署指南，可套用到 3-node、5-node、更多 OSD disk 的情境。

**不採用原因：**
- 第一版會變得過度抽象
- 不利於快速產出可直接照抄的 lab 文件
- 與目前 `3node-kubevirt` 的固定拓樸風格不一致

### 2. 只寫 VM / network / disk 建立，不寫 RBD pool

把範圍縮到 cluster ready 即止，後續儲存配置另開 phase 或另開主題。

**不採用原因：**
- 使用者已明確要求先把 RBD pool、`size`、`pg_num` 一起納入
- 沒有 pool 會讓這份筆記停在「Ceph 架起來了，但還沒變成可用儲存」的中間狀態

### 3. 推薦方案：固定 3-node lab baseline + RBD pool

以對稱三節點設計快速建立第一版，先把 public/cluster 網路分離、OSD disks、bootstrap、RBD pool 初始設定整理完整。

**採用原因：**
- 跟現有 notebook 風格一致
- 容易畫圖、寫 phase、補 commands
- 先完成可用的第一版，再考慮後續擴充 CephFS、client mount、或 IaC/Bicep

## Scope

### In Scope

- 新增 `storage/3node-ceph/` 主題入口頁
- 新增下列文件：
  - `index.md`
  - `architecture.md`
  - `buildup.md`
  - `flowchart.md`
  - `commands.md`
  - `phase-0.md`
  - `phase-1.md`
  - `phase-2.md`
  - `phase-3.md`
  - `phase-4.md`
- 描述 Azure 上 3 台 VM、2 張 NIC、1 OS disk + 2 OSD disks 的 baseline
- 描述 `Ceph v19.2.2` 安裝與 bootstrap 流程
- 描述 `rbdpool` 建立與初始參數設定：
  - `size = 3`
  - `min_size = 1`
  - `pg_num = 128`
  - `pgp_num = 128`

### Out of Scope

- CephFS
- Client 主機掛載 RBD / kernel mapping / Kubernetes CSI 整合
- 更高可用的 production-grade Ceph 架構（例如 dedicated MON / dedicated admin node）
- IaC / Bicep 自動化版本
- WAL / DB 獨立磁碟切分

## Information Architecture

### Folder

```text
storage/
└── 3node-ceph/
    ├── index.md
    ├── architecture.md
    ├── buildup.md
    ├── flowchart.md
    ├── commands.md
    ├── phase-0.md
    ├── phase-1.md
    ├── phase-2.md
    ├── phase-3.md
    └── phase-4.md
```

### File Responsibilities

| File | Purpose |
|------|---------|
| `index.md` | 主入口頁、閱讀順序、phase 導覽 |
| `architecture.md` | Ceph 拓樸、節點角色、網路與磁碟配置 |
| `buildup.md` | 過渡型總覽與 phase navigation |
| `flowchart.md` | 從 Azure 建機到 Ceph Ready 的高層流程 |
| `commands.md` | 常用安裝、驗證、pool 與 RBD 指令 |
| `phase-0.md` | Azure 建 3 台 VM、2 subnet、2 NIC、3 disks |
| `phase-1.md` | OS 初始化、hostnames、雙網路與磁碟檢查 |
| `phase-2.md` | 安裝 Ceph v19.2.2 |
| `phase-3.md` | 建立 3-node cluster，設定 `public_network` / `cluster_network`，加入 OSD |
| `phase-4.md` | 建立 `rbdpool`、設定 pool 參數與基本驗證 |

## Architecture Design

### Node Topology

三台 VM 採完全對稱角色：

- `ceph-node-01`
- `ceph-node-02`
- `ceph-node-03`

每台節點都同時承載：

- `MON`
- `MGR`
- `OSD`

此做法適合 lab / test，優點是文件較短、理解成本低；缺點是並非高隔離的 production 拓樸。

### Network Layout

兩個網路明確分離：

- **public / OS network**：`10.10.10.0/24`
  - SSH
  - Ceph 管理與 client-facing traffic
  - monitor service communication
- **cluster / internal sync network**：`172.10.10.0/24`
  - OSD replication
  - backfill
  - recovery

每台 VM 掛 2 張 NIC：

- NIC1 → `10.10.10.0/24`
- NIC2 → `172.10.10.0/24`

### Fixed IP Plan

| Node | Public / OS IP | Cluster / Sync IP |
|------|----------------|-------------------|
| `ceph-node-01` | `10.10.10.10` | `172.10.10.10` |
| `ceph-node-02` | `10.10.10.11` | `172.10.10.11` |
| `ceph-node-03` | `10.10.10.12` | `172.10.10.12` |

### VM and Disk Baseline

每台節點使用：

- VM size：`Standard_D4s_v4`
- OS disk：`64 GiB`
- OSD data disk：`64 GiB x2`

設計意圖：

- 保持成本較低，適合實驗測試
- 保持每台節點至少有兩顆獨立 data disk，可示範多 OSD 配置
- 不做 WAL / DB 分離，避免第一版文件複雜化

總體來說，3 台主機共有：

- 3 顆 OS disk
- 6 顆 OSD data disk
- 預設每顆 data disk 對應 1 個 OSD

## Ceph Configuration Baseline

### Version

- Ceph：`v19.2.2`

### Network Config

在 Ceph 設定中明確寫入：

- `public_network = 10.10.10.0/24`
- `cluster_network = 172.10.10.0/24`

### Pool Baseline

建立預設 RBD pool：

- pool name：`rbdpool`
- `size = 3`
- `min_size = 1`
- `pg_num = 128`
- `pgp_num = 128`

並在文件中補上：

- 啟用 `rbd` application
- 建立一個測試 image
- 驗證 `rbd ls` / `ceph osd pool ls detail` 可看到預期結果

## Phase Design

### Phase 0 — Azure Resource Build

重點：

- 建 Resource Group
- 建 VNet / subnets
- 建 NSG
- 建 3 台 VM
- 每台掛 2 張 NIC
- 每台掛 2 顆額外 data disk

此 phase 只保留一個做法：**Azure MCP / Azure CLI**

### Phase 1 — OS and Disk Preparation

重點：

- SSH 登入與基礎套件
- hostname 與 `/etc/hosts`
- 驗證兩張 NIC
- 驗證兩條 network path
- 驗證 2 顆 data disk 存在且未被系統使用

### Phase 2 — Ceph Installation

重點：

- 安裝 Ceph `v19.2.2`
- 驗證安裝版本
- 準備 bootstrap 所需使用者與工具

### Phase 3 — Cluster Bootstrap

重點：

- bootstrap 第一台節點
- 加入第 2、3 台 node
- 套用 `public_network` / `cluster_network`
- 建立 6 個 OSD
- 驗證 health 與 OSD / MON / MGR 狀態

### Phase 4 — RBD Pool Setup

重點：

- 建 `rbdpool`
- 設定 `size` / `min_size`
- 設定 `pg_num` / `pgp_num`
- 啟用 `rbd` application
- 建測試 image 驗證

## Mermaid Content Plan

### `architecture.md`

使用 `graph TD` 或 `graph LR` 描述：

- Azure VNet
- `10.10.10.0/24` public network
- `172.10.10.0/24` cluster network
- 3 個 Ceph nodes
- 每台節點上的 `MON / MGR / OSD`
- 6 顆 OSD disks

### `flowchart.md`

使用 `flowchart TD` 描述：

1. Azure 建 3 台 VM
2. OS 初始化
3. 安裝 Ceph
4. bootstrap cluster
5. 加入 3 台 node
6. 建 OSD
7. 建 RBD pool
8. 驗證完成

## Writing Style and Constraints

- 內容語氣沿用現有 notebook：偏實作、可操作、簡潔表格化
- 連結優先使用 GitHub Pages URL 或 repo 內相對導覽方式，與現有風格一致
- `buildup.md` 採 phase navigation 模式，而不是把所有步驟塞在單頁
- 所有 Mermaid 圖保持簡單，不引入過度細節

## Expected Result

完成後，repo 內會多出一個 `storage/3node-ceph/` 主題，能讓讀者依序完成：

1. 在 Azure 建立 3 台 Ceph node
2. 將 public 與 cluster network 分離
3. 安裝並建立 Ceph `v19.2.2` 三節點 cluster
4. 建立可用的 `rbdpool`

這份文件會成為 Ceph lab 的第一版基準；未來若要加入 CephFS、client 掛載或 IaC/Bicep，可在此基礎上擴充。
