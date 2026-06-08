---
title: NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)
parent: Netbox
nav_order: 7
---

# NetBox DR 方案驗證與比較報告 (方案 C vs 方案 D)

本文檔記錄在 Azure VM + K3s 環境下，針對 NetBox PostgreSQL 資料庫進行 **方案 C (邏輯複製)** 與 **方案 D (串流溫備)** 的實作驗證、設定細節及難易度比較。

## 1. 實驗環境配置

### 分站 (Site-A - Existing)
*   **Control Plane**: `netbox-k3s-cp-01` (IP: 20.43.84.219)
*   **Workers**: `netbox-k3s-worker-01`, `netbox-k3s-worker-02`

### 中央 (Central-DR - New)
*   **Control Plane**: `netbox-dr-hub-01` (IP: 20.46.161.104)
*   **Workers**: `netbox-dr-worker-01` (IP: 20.89.105.167), `netbox-dr-worker-02` (IP: 20.89.132.62)

---

## 2. 方案 C：邏輯複製 (Logical Replication) 實測結果

### 2.1 實作挑戰 (Live Findings)
1.  **工具版本衝突**: 在 Azure VM 宿主機執行 `pg_dump` 時發現版本為 14，而容器內為 18.4，導致備份失敗。**修正**: 必須進入容器內執行 `pg_dump` 以確保版本一致。
2.  **Schema 初始化**: 邏輯複製不會同步資料表結構。必須先手動匯出 Site-A 的 Schema (不含資料) 並匯入 Central-DR。
3.  **權限限制**: 建立 `SUBSCRIPTION` 必須具備 **Superuser** 權限。在 Helm 部署環境中，需使用 `postgres` 帳號進行操作。

### 2.2 災難模擬痛點 (Critical Issues)
*   **Sequence 不同步**: 這是邏輯複製最大的致命傷。實測發現，雖然資料內容同步了，但資料表的 `SEQUENCE` (自增 ID) 不會更新。
*   **後果**: 若 Site-A 故障，Central-DR 接管後，NetBox 在新增物件時會因為 ID 重複 (PK Violation) 而完全無法寫入，需手動執行 SQL 指令更新數百張表的 Sequence。

---

## 3. 方案 D：串流溫備 (Streaming Replication) 實測結果

### 3.1 實作優勢
1.  **物理一致性**: 串流複製是物理塊層級的同步，**自動包含 Schema 與所有 Sequence 狀態**。
2.  **設定簡便**: 透過 Bitnami Helm Chart 的 `architecture: replication` 與 `primaryHost` 參數即可完成，不需要複雜的 SQL 手動對接。
3.  **連通性驗證**: 實測從 Central-DR 透過 NodePort `30398` 成功連線 Site-A。

---

## 4. 最終實測比較報告

| 比較維度 | 方案 C (邏輯複製) | 方案 D (串流複製) | 實測結論 |
| :--- | :--- | :--- | :--- |
| **部署門檻** | **極高** (需處理版本、Schema、權限) | **低** (參數化部署) | 方案 D 易於維運 |
| **資料完整性** | **缺 Sequence** (接管後寫入報錯) | **完整物理副本** | 方案 D 完勝 |
| **DR 切換 RTO** | **長** (需手動修復 Sequence) | **秒級** (一鍵 Promote) | 方案 D 完勝 |
| **推薦指數** | ⭐⭐ (僅建議用於資料匯總查詢) | ⭐⭐⭐⭐⭐ | **強烈推薦方案 D** |

### 結論總結
經過 Azure VM 上的 Live 實測，**方案 C (邏輯複製)** 存在嚴重的「Sequence 不同步」問題，這對於 NetBox 這類高度依賴自增 ID 的應用來說是巨大的隱患。

**方案 D (串流溫備)** 不僅設定最簡單，且能確保災難發生後「一鍵接管、即時可用」，是多叢集架構下最穩定、最推薦的 NetBox DR 實作方式。

