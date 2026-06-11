---
title: mon_admin_label
parent: Storage
nav_order: 30
permalink: /storage/mon_admin_label/
---

# Ceph `_admin` Label

## 架構觀點：`_admin` 的意義

`_admin` 是 Ceph orchestrator 的主機標籤，用來標記「可安全執行管理指令」的節點。被標記的節點通常會持有管理所需的 `ceph.conf` 與 `client.admin` keyring，方便執行 `ceph` / `cephadm shell` 類操作。

它**不會**改變資料平面（data path）上的 I/O 路徑，也不會直接影響 PG 映射或 OSD 讀寫流量；其作用範圍主要是管理平面（control/management plane）。

## `_admin` 與設定檔案及金鑰的完整範圍

當節點被標記為 `_admin` 後，cephadm 會在該節點上自動部署與維護多個重要檔案與設定。以下詳述完整的範圍：

### 配置檔案 (`/etc/ceph/ceph.conf`)
- **作用**：定義 Ceph 集群的全局設定（monitor 地址、日誌等級、網路參數等）
- **與 `_admin` 的關係**：
  - `_admin` 標籤標記的節點會由 `cephadm` 自動維護一份最新的 `ceph.conf`
  - 執行 `ceph` / `cephadm shell` 等管理命令時，工具會讀取此檔案以連接到 monitor 節點
  - 當集群配置變更時，此檔案會由 orchestrator 自動同步

### 管理員金鑰 (`ceph.client.admin.keyring`)
- **作用**：包含 `client.admin` 身份的認證憑證，擁有完全的集群管理權限
- **與 `_admin` 的關係**：
  - `_admin` 標籤標記的節點會由 `cephadm` 自動部署並維護此金鑰檔案
  - 只有持有此金鑰的節點，才能執行 `ceph config set`、`ceph osd rm` 等需要 `admin` 權限的操作
  - `cephadm shell` 進入容器時，會使用此金鑰進行身份驗證

### SSH 公鑰 (`/etc/ceph/ceph.pub`)
- **作用**：Ceph 集群用於跨節點 SSH 通訊的公鑰
- **與 `_admin` 的關係**：
  - `_admin` 標籤標記的節點會持有此公鑰副本
  - 此公鑰需要被加入到所有其他節點的 `~/.ssh/authorized_keys` 中，才能讓 cephadm 進行無密碼 SSH 管理
  - 確保 orchestrator 可從 `_admin` 節點安全地操控其他節點的 daemon

### 範圍說明：什麼不受 `_admin` 影響
- **日誌設定** (`log_file`, `debug` 等) — 由各 daemon 的 spec 控制，不受 `_admin` 影響
- **MON/OSD 角色** — 由其他標籤或 service spec 定義
- **審計設定** — 由集群全局配置控制
- **其他客戶端金鑰** (`ceph.client.read-only.keyring` 等) — 通常不會被部署到 `_admin` 節點

### 完整關係與部署流程
```
_admin 標籤標記
     ↓
cephadm orchestrator reconcile
     ↓
cephadm 自動在該節點:
 ├─ 部署/維護 /etc/ceph/ceph.conf
 ├─ 部署/維護 /etc/ceph/ceph.client.admin.keyring
 ├─ 部署/維護 /etc/ceph/ceph.pub (SSH 公鑰)
 └─ 確保三個檔案保持最新同步
     ↓
使用者可在該節點執行管理命令
 ├─ ceph -s (讀 ceph.conf + 使用 client.admin keyring)
 ├─ ceph config set ... (需要 admin 權限)
 ├─ cephadm shell (載入金鑰與配置進容器)
 └─ 從該節點對其他主機進行 SSH 操作（透過 ceph.pub）
```

### Reconcile 流程中的檔案清理
- 當移除 `_admin` 標籤後，orchestrator 在下一個 reconcile 週期會：
  - 刪除 `/etc/ceph/ceph.conf`
  - 刪除 `/etc/ceph/ceph.client.admin.keyring`
  - 保留 `/etc/ceph/ceph.pub`（因為仍需要用於 SSH 連線）

## 架構觀點：ceph-mgr / orchestrator 互動

在 cephadm 架構下，ceph-mgr 的 orchestrator 模組會持續對照期望狀態與實際狀態。當主機標籤（含 `_admin`）異動後，orchestrator 會進入 reconcile 流程，重新評估哪些節點可承接管理操作，並同步後續的管理任務分派與檢查。

具體來說，當標籤異動時：
1. **新增 `_admin` 標籤**：
   - Orchestrator 掃描到新的 `_admin` 標籤
   - 自動部署 `/etc/ceph/ceph.conf`、`ceph.client.admin.keyring`、`ceph.pub` 到該節點
   - 後續的管理操作（如配置變更、OSD 操作等）會優先在 `_admin` 節點執行或發起

2. **移除 `_admin` 標籤**：
   - Orchestrator 掃描到標籤移除
   - 刪除 `/etc/ceph/ceph.conf` 和 `ceph.client.admin.keyring`
   - 保留 `ceph.pub`（仍需用於其他管理操作的 SSH 連線）
   - 該節點退出管理節點角色

## `_admin` 標籤流程圖

```mermaid
flowchart TD
    A[設定 _admin label] --> B[ceph-mgr orchestrator reconcile]
    B --> C[在 _admin 節點執行管理操作]
    C --> D[驗證管理操作結果]
    D --> E{符合預期?}
    E -- 是 --> F[維持現狀並持續監控]
    E -- 否 --> G[調整標籤或節點狀態]
    G --> B
```

## 指令序列：檢查 labels

```bash
ceph orch host ls --format yaml
# 或僅看特定主機
ceph orch host ls --host-pattern <hostname> --format yaml
```

## 指令序列：新增 `_admin` label

```bash
ceph orch host label add <hostname> _admin
```

## 指令序列：驗證行為

```bash
# 1) 確認 label 已生效
ceph orch host ls --host-pattern <hostname> --format yaml

# 2) 從該節點驗證管理指令可執行
ceph -s
ceph health detail
```

## 指令序列：移除 `_admin`（rollback）

```bash
ceph orch host label rm <hostname> _admin

# rollback 後再次確認
ceph orch host ls --host-pattern <hostname> --format yaml
```

## 底層原理：Paxos 儲存區與 Source of Truth

當我們提到 Ceph 的「共識儲存」或「Paxos 儲存區」時，技術上是指 Monitor (MON) 內部維護的一套具備強一致性的 Key-Value 資料庫。

### 1. 它是什麼樣的 DB？
- **實體層**：底層使用 **RocksDB**。每個 MON 節點的磁碟上都有一個 `store.db` 目錄（路徑通常在 `/var/lib/ceph/<fsid>/mon.<hostname>/store.db`）。
- **邏輯層 (Paxos)**：雖然每個 MON 都有自己的 RocksDB，但 Ceph 透過 **Paxos 演算法** 確保這些 RocksDB 裡的內容在整個集群中是完全同步的。這就是為什麼不論你連向哪一台 MON，看到的 `ceph.conf` 或金鑰都是一樣的。

### 2. Cephadm 如何取得這些資訊？
`cephadm` 並非直接讀取磁碟上的 RocksDB 檔案，而是透過 **ceph-mgr** 進行調度：
1. **內部請求**：運行在 `ceph-mgr` 內的 `cephadm` 模組，會透過內部 API 向 MON 集群發送 `mon_command`（類似我們執行的 `ceph config dump`）。
2. **數據封裝**：MON 從其 Paxos 狀態機中提取最新的 **MonMap** (IP 位址) 與 **Config Database** (參數)，並封裝成純文字格式回傳給 MGR。
3. **分發寫入**：MGR 拿到內容後，透過 SSH 登入目標節點，將內容寫入檔案。

---

## 檔案更新觸發情境

`/etc/ceph/ceph.conf` 與 `ceph.client.admin.keyring` 不會無故刷新，它們主要在以下情境會被 `cephadm` 強制更新：

| 異動類型 | 觸發動作 | 受影響檔案 |
| :--- | :--- | :--- |
| **MON 拓樸變更** | `ceph orch apply mon` (擴充或縮減節點) | `ceph.conf` (更新 `mon_host` 列表) |
| **全域設定變更** | `ceph config set global <key> <value>` | `ceph.conf` (若該參數屬於必備參數) |
| **主機標籤變更** | `ceph orch host label add <host> _admin` | 該節點新增兩個檔案 |
| **定期調解 (Reconcile)** | `cephadm` 預設的巡檢週期 (通常為每小時) | 所有 `_admin` 節點 (確保檔案無漂移) |
| **手動觸發** | `ceph orch host rescan <hostname>` | 強制該節點立即同步 |

---

## 如何手動查看「真相」(Source of Truth)？

如果您想繞過磁碟檔案，直接查看 Paxos 儲存區裡的內容，請使用以下標準指令：

### 1. 查看設定檔母本 (Config Database)
不要看 `/etc/ceph/ceph.conf`，而是執行：
```bash
ceph config dump
```
這會列出所有儲存在 MON 數據庫中的非預設參數。

### 2. 查看管理員金鑰母本 (Auth Database)
不要看 `ceph.client.admin.keyring` 檔案，而是執行：
```bash
ceph auth get client.admin
```
這會直接從 MON 的 `auth` 模組中提取金鑰與 Caps。

### 3. 進階：離線查看 (僅限災難復原)
如果所有 MON 都掛了，無法執行上述指令，資深維運人員會使用 `ceph-monstore-tool` 來直接讀取 RocksDB：
```bash
# 警告：此操作需停止 MON daemon
ceph-monstore-tool /var/lib/ceph/<fsid>/mon.<id>/ get config
```

---

## 風諧與最佳實務

- 避免將 `_admin` 只綁在單一節點；至少保留多個可管理節點，降低節點故障時的操作風險。
- 變更 label 前先確認目前維運流程是否依賴該節點（例如自動化腳本、SRE jump host 路徑）。
- 將 label 變更納入變更管理與審計紀錄，並先準備 rollback 指令。
- 調整 `_admin` 後，應立即驗證 `ceph -s` 與常用管理指令，確保管理面可用性。
