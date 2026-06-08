---
title: NetBox 多叢集備份與災難復原 (Central-to-Site)
parent: Netbox
nav_order: 6
---

# NetBox 多叢集備份與災難復原架構 (Central-to-Site)

本指南專為 **「中央 (Central K8s) 控管多個分站 (Site K8s)」** 的架構所設計。在此情境下，每個 Site 皆獨立部署 NetBox，而中央叢集負責統一的資料備份、監控與異地災備 (DR)。

---

## 1. 核心架構前提

*   **中央叢集 (Central K8s)**：擁有存取各 Site K8s API 的權限，具備大容量儲存 (如 MinIO/Ceph) 或專屬資料庫。
*   **分站叢集 (Site K8s)**：獨立運行 NetBox 服務與 PostgreSQL 資料庫。
*   **設計目標**：在不影響分站效能的前提下，達成資料集中化與 RPO/RTO 的最佳平衡。

---

## 2. 關鍵績效指標：RPO 與 RTO

在討論備份方案前，必須先理解災難復原的兩大核心指標：

*   **RPO (Recovery Point Objective, 復原點目標)**：
    *   **定義**：災難發生時，企業**允許遺失多少時間的資料**。
    *   **範例**：若每 24 小時備份一次，RPO 就是 24 小時；若採用即時串流複製，RPO 則趨近於 0。
*   **RTO (Recovery Time Objective, 復原時間目標)**：
    *   **定義**：從災難發生到**服務恢復正常運作**所需的時間。
    *   **範例**：若重建環境需要 4 小時，還原資料庫需要 2 小時，則 RTO 為 6 小時。

**原則**：RPO/RTO 越短，技術難度與成本通常越高。

---

## 3. 備份與災備方案比較表

| 方案類型 | 技術手段 | RPO (資料遺失) | RTO (恢復速度) | 優點 |
| :--- | :--- | :--- | :--- | :--- |
| **A. 分站推送 (Push)** | `pg_dump` to Central S3 | 中 (取決於排程) | 中 (需手動還原) | 權限隔離、網路容錯 |
| **B. WAL 增量倉庫** | pgBackRest | **極低** (可 PITR) | 快 (自動化還原) | 支援時間點還原、省頻寬 |
| **C. 邏輯匯總副本** | Logical Replication | 秒級 | 快 (僅需切換連接) | 活資料、便於跨站查詢 |
| **D. 異地串流溫備** | Streaming Replication | **趨近於零** | **極快** (溫備切換) | **災難接管首選** |

---

## 4. 方案詳解與實施架構 (User Role 友善方案)

在「具備應用部署權限，但無 Cluster-Admin 權限」的前提下，備份邏輯必須從「中央拉取」轉向「分站推送」或「資料庫層級同步」。

### A. 分站推送備份 (Decentralized Push - 最易實施)
在分站 NetBox 所在的 Namespace 部署一個 CronJob。
*   **機制**：
    1.  CronJob 在分站本地執行 `pg_dump`。
    2.  利用分站擁有的網路權限，將備份檔推送至中央叢集的 S3 (如 MinIO) 或其他儲存終端。
*   **安全性**：不需跨叢集 `kubeconfig`，分站只需持有中央儲存的 Access Key。

### B. pgBackRest 集中化倉庫 (推薦大規模使用)
在中央部署 pgBackRest Repo 服務。各分站資料庫 Pod 只需配置 `archive_command` 指向中央服務。
*   **優勢**：pgBackRest 是在應用層運作，不需要 `kubectl exec` 權限，只需網路埠 (TLS) 連通即可。

### C. 中央邏輯匯總副本 (Logical Aggregate)
在中央部署一套 PostgreSQL 作為 Subscriber，各分站 PostgreSQL 開放連接權限作為 Publisher。
*   **權限要求**：只需資料庫層級的 `REPLICATION` 角色權限，不涉及 K8s 節點管理或高階 API 存取。

### D. 中央異地串流副本 (DR Hub / Warm Standby - 進階方案)
在中央部署分站的備援 Pod (Standby)。
*   **機制**：中央的 Standby Pod 主動連向分站的 Primary DB 拉取串流日誌。
*   **部署實務**：只需在中央部署普通的 StatefulSet，並在配置中填入分站資料庫的連線字串。

---

## 4. 災難復原工作流程 (DR Workflow)

針對「快速重建 + Restore 資料」的需求，我們採用 **「IaC + 資料庫還原」** 的混合策略。

### 第一階段：基礎設施重建 (The Outer Shell)
1.  **GitLab IaC**：透過 Helm 與 GitLab CI/CD 在新環境（或中央備援區）拉起 NetBox 基礎組件。
2.  **Velero Restore**：若有備份 K8s 原生物件（Secrets, ConfigMaps, PVC），使用 Velero 快速恢復 Namespace 狀態。

### 第二階段：資料注入 (The Heart)
根據備份方案選擇還原路徑：
*   **方案 A/B**：使用 `pg_restore` 匯入 `.dump` 檔案。
*   **方案 C**：使用 `pgbackrest restore` 執行時間點還原。
*   **方案 E**：直接提升 (Promote) 中央的 Standby Pod 為新 Primary。

---

## 5. 附錄：關鍵指令參考

### 集中式遠端備份 (Pull Example)
```bash
# 在中央叢集執行，對 Site-A 進行備份
kubectl --kubeconfig=/etc/kubeconfigs/site-a-config \
  exec -n netbox netbox-postgresql-primary-0 -- \
  bash -c "PGPASSWORD='pwd' pg_dump -U netbox -d netbox -Fc" > site-a-backup.dump
```

### 異地溫備提升 (Promote DR Pod)
```bash
# 當分站故障，在中央提升備援庫
kubectl -n dr-namespace exec netbox-postgresql-dr-site-a-0 -- \
  bash -c "pg_ctl promote -D /bitnami/postgresql/data"
```

### Velero 備份指定站點配置
```bash
velero backup create site-a-netbox-config \
  --include-namespaces netbox \
  --selector "app.kubernetes.io/instance=netbox"
```

---

## 6. 管理與驗證建議

1.  **分層儲存**：備份檔應至少保留一份於中央叢集的持久儲存，並非同步一份至冷儲存（如 Azure Blob Archive）。
2.  **定時演練**：每季度選定一個 Site 進行「中央接管演練」，確保 DR 流程在壓力下依然有效。
3.  **監控指標**：在 Prometheus 中監控「備份成功率」與「流複製延遲時間 (Replication Lag)」。
