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

## 2. 備份與災備方案比較表

| 方案類型 | 技術手段 | RPO (資料遺失量) | 優點 | 適用情境 |
| :--- | :--- | :--- | :--- | :--- |
| **A. 集中式拉取 (Pull)** | `pg_dump` via `kubectl exec` | 高 (取決於排程) | Site 端零配置、中央統一管控 | 站點數量少、初階集中管理 |
| **B. 分站推送 (Push)** | `pg_dump` to Central S3 | 中 (取決於排程) | 權限邊界清晰、網路容錯高 | 大規模叢集、重視安全隔離 |
| **C. WAL 增量倉庫** | pgBackRest Repo | **極低** (PITR) | 支援時間點還原、節省 WAN 頻寬 | 大型資料庫、對 RPO 要求極高 |
| **D. 邏輯匯總副本** | Logical Replication | 秒級 | 便於中央進行跨站唯讀匯總查詢 | 重視即時查詢與輕量災備 |
| **E. 異地串流溫備** | Streaming Replication | **趨近於零** | **災難接管速度最快** (溫備模式) | **進階災備**：關鍵業務不可中斷 |

---

## 3. 方案詳解與實施架構

### A. 中央 Pull 備份 (Centralized Pull)
在 Central K8s 部署 CronJob，利用 Secret 保存的各站 `kubeconfig` 遠端下指令。
*   **機制**：`kubectl --kubeconfig=site-a exec pg_pod -- pg_dump`
*   **建議**：僅適用於 Site 數量 < 5 的環境。

### B. 分站 Push 備份 (Decentralized Push)
在 Central 部署 MinIO 作為 S3 儲存。各 Site 本地部署備份 Job。
*   **機制**：`pg_dump | mc pipe central-minio/site-a/`
*   **優勢**：即便中央叢集短暫維護，分站仍可繼續執行本地備份並排隊推送。

### C. pgBackRest 集中化倉庫 (Recommended for Scale)
在 Central 建立專屬的 pgBackRest Repo Server，各站資料庫作為 Client。
*   **特點**：
    *   **增量傳輸**：僅傳送變更的資料塊，對 WAN 友善。
    *   **自我修復**：具備強大的校驗功能。

### D. 中央邏輯匯總副本 (Logical Aggregate)
各 Site PostgreSQL 作為 Publisher，Central 一台大型 PostgreSQL 作為 Subscriber。
*   **特點**：中央擁有一份「活的」資料，除備份外，還可用於開發 Grafana 報表監控各站 IP 使用率。

### E. 中央異地串流副本 (DR Hub / Warm Standby)
在 Central 叢集為每個 Site 預留一個 `postgresql-dr` 實例。
*   **機制**：Site Primary DB 物理流複製至 Central Standby Pod。
*   **DR 切換**：當 Site A 整座機房毀滅時，於中央執行 `pg_ctl promote`，並將中央的 NetBox UI 指向此庫，達成秒級接管。

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
