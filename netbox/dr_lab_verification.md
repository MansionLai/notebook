---
title: NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)
parent: Netbox
nav_order: 7
---

# NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)

本文檔記錄在 Azure VM + K3s 環境下，針對 NetBox PostgreSQL 資料庫進行 **方案 C (邏輯複製)** 與 **方案 D (串流溫備)** 的實作驗證、設定細節及難易度比較。

## 1. 實驗環境配置

*   **分站 (Site-A)**: 現有的 Azure VM K3s 叢集 (NetBox Primary)。
*   **中央 (Central-DR)**: 新建的 Azure VM K3s 叢集 (作為 DR Hub)。
*   **資源群組**: `mansion_k3s_netbox`
*   **軟體版本**: NetBox v3.x+, PostgreSQL 14+ (Bitnami Helm Chart)。

---

## 2. 方案 C：邏輯複製 (Logical Replication) 驗證

### 2.1 PostgreSQL 設定 (分站 - Publisher)
需要修改 `postgresql.conf` 並建立出版物。

```yaml
# netbox-values.yaml 修正
postgresql:
  primary:
    extendedConfiguration: |
      wal_level = logical
      max_replication_slots = 10
      max_wal_senders = 10
```

### 2.2 設定步驟
1. 在 Site-A 建立 Replication User。
2. 在 Site-A 建立 Publication: `CREATE PUBLICATION netbox_pub FOR ALL TABLES;`
3. 在 Central-DR 建立 Subscription: `CREATE SUBSCRIPTION netbox_sub CONNECTION 'host=site-a-ip user=rep_user password=pwd dbname=netbox' PUBLICATION netbox_pub;`

---

## 3. 方案 D：串流溫備 (Streaming Replication) 驗證

### 3.1 PostgreSQL 設定 (中央 - Standby)
利用 Bitnami Chart 內建的 `architecture: replication` 或手動設定 `primary_conninfo`。

```yaml
# central-dr-values.yaml (溫備庫)
postgresql:
  architecture: replication
  replication:
    enabled: true
    primaryHost: "site-a-public-ip"
    primaryPort: "5432"
    user: "replication_user"
    password: "replication_password"
```

### 3.2 設定步驟
1. 在 Site-A 開放防火牆 (5432 埠) 允許 Central-DR 連線。
2. 在 Central-DR 啟動 PostgreSQL Standby 實例。
3. 驗證同步狀態: `SELECT * FROM pg_stat_wal_receiver;`

---

## 4. 難易度與效能比較報告

| 比較項目 | 方案 C (邏輯複製) | 方案 D (串流複製) | 結論 |
| :--- | :--- | :--- | :--- |
| **設定難易度** | **高** (需手動處理 Table Schema 建立與初始化) | **低** (Bitnami Chart 原生支援，全自動物理同步) | **方案 D 勝** |
| **網路依賴性** | 較低 (僅同步變更數據) | 較高 (物理層級同步) | 方案 C 較彈性 |
| **DR 切換難度** | **中** (需手動導向並處理 Sequence 同步) | **低** (一鍵執行 `promote` 即可接管) | **方案 D 勝** |
| **RPO 表現** | 秒級 | **趨近於零** | **方案 D 勝** |
| **RTO 表現** | 分鐘級 | **秒級** | **方案 D 勝** |

### 最終評估：
針對 **User Role** 且追求 **極低 RPO** 的情境，**方案 D (串流複製)** 在實作難度與災難恢復速度上具備絕對優勢，是 NetBox 異地災備的首選建議。
