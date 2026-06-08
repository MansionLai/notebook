---
title: NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)
parent: Netbox
nav_order: 7
---

# NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)

本文檔記錄在 Azure VM + K3s 環境下，針對 NetBox PostgreSQL 資料庫進行 **方案 C (邏輯複製)** 與 **方案 D (串流溫備)** 的實作驗證、設定細節及難易度比較。

## 1. 實驗環境配置

### 分站 (Site-A - Existing)
*   **Control Plane**: `netbox-k3s-cp-01` (IP: 20.46.161.94)
*   **Workers**: `netbox-k3s-worker-01`, `netbox-k3s-worker-02`

### 中央 (Central-DR - New)
*   **Control Plane**: `netbox-dr-hub-01` (IP: 20.46.161.104)
*   **Workers**: `netbox-dr-worker-01` (IP: 20.89.105.167), `netbox-dr-worker-02` (IP: 20.89.132.62)

---

## 2. 方案 C：邏輯複製 (Logical Replication) 驗證

### 2.1 實作設定
1.  **分站 (Publisher) 設定**:
    在 `postgresql.primary.extendedConfiguration` 加入：
    ```ini
    wal_level = logical
    max_replication_slots = 10
    max_wal_senders = 10
    ```
2.  **建立出版物**:
    ```sql
    CREATE ROLE rep_user WITH REPLICATION LOGIN PASSWORD 'pwd';
    GRANT ALL ON ALL TABLES IN SCHEMA public TO rep_user;
    CREATE PUBLICATION netbox_pub FOR ALL TABLES;
    ```
3.  **中央 (Subscriber) 設定**:
    需先手動同步 Table Schema (不含資料)，然後建立訂閱：
    ```sql
    CREATE SUBSCRIPTION netbox_sub 
    CONNECTION 'host=20.46.161.94 user=rep_user password=pwd dbname=netbox' 
    PUBLICATION netbox_pub;
    ```

### 2.2 災難模擬與恢復 (Failover)
*   **模擬**: 停止 Site-A 的 PostgreSQL 服務。
*   **恢復**: 
    1.  手動刪除 Central-DR 的 Subscription。
    2.  **關鍵痛點**: 需手動重設所有表的 `SEQUENCE` (自增 ID)，否則 NetBox 寫入新資料時會發生 ID 衝突。

---

## 3. 方案 D：串流溫備 (Streaming Replication) 驗證

### 3.1 實作設定
1.  **分站 (Primary) 設定**:
    只需確保 `wal_level = replica` (預設值) 並開放連線。
2.  **中央 (Standby) 設定**:
    在 `values.yaml` 使用 Bitnami 原生支援：
    ```yaml
    postgresql:
      architecture: replication
      primary:
        service:
          enabled: false # 因為 Primary 在異地
      replication:
        enabled: true
        readReplicas: 1
        primaryHost: "20.46.161.94"
        primaryPort: "5432"
        user: "replication_user"
    ```

### 3.2 災難模擬與恢復 (Failover)
*   **模擬**: 關閉 Site-A VM。
*   **恢復**: 
    1.  在 Central-DR 執行 `pg_ctl promote`。
    2.  **優勢**: 物理同步包含所有 Sequence 與狀態，完全不需額外調整，恢復時間 (RTO) 僅需幾秒鐘。

---

## 4. 比較報告總結

| 比較維度 | 方案 C (邏輯複製) | 方案 D (串流複製) | 評語 |
| :--- | :--- | :--- | :--- |
| **部署門檻** | 需手動同步 Schema | Helm Chart 參數化部署 | 方案 D 完勝 |
| **資料一致性** | 僅資料內容 | 包含物理狀態與序列 | 方案 D 更完整 |
| **DR 切換複雜度** | 需調整 Sequence | 一鍵提升為 Primary | 方案 D 完勝 |
| **RPO 潛力** | 秒級 | **趨近於零** | 方案 D 優異 |
| **推薦指數** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **強烈推薦方案 D** |

### 結論
對於 NetBox 這種 Schema 固定且對資料完整性要求極高的應用，**方案 D (串流溫備)** 是 CP 值最高的選擇，尤其在 **User Role** 權限受限下，透過 Helm 參數即可完成，不需要深入了解 K8s 底層 API。
