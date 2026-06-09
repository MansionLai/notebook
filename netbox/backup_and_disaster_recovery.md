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

---

## 3. 備份與災備方案比較表

| 方案類型 | 技術手段 | RPO (資料遺失) | RTO (恢復速度) | 優點 |
| :--- | :--- | :--- | :--- | :--- |
| **A. 分站推送 (Push)** | `pg_dump` to Central S3 | 中 (取決於排程) | 中 (需手動還原) | 權限隔離、網路容錯 |
| **B. WAL 增量倉庫** | pgBackRest | **極低** (可 PITR) | 快 (自動化還原) | 支援時間點還原、省頻寬 |
| **C. 異地串流溫備** | Streaming Replication | **趨近於零** | **極快** (溫備切換) | **災難接管首選方案** |

---

## 4. 方案詳解與實施架構 (User Role 友善方案)

在「具備應用部署權限，但無 Cluster-Admin 權限」的前提下，我們排除「中央拉取」與「邏輯複製」(經實測有 Sequence 不同步問題)，專注於以下可靠方案：

### A. 分站推送備份 (Decentralized Push - 最易實施)
在分站 NetBox 所在的 Namespace 部署一個 CronJob。
*   **機制**：
    1.  CronJob 在分站本地執行 `pg_dump` 並進行 `gzip` 壓縮。
    2.  利用 `curl` 將備份檔透過 REST API 推送至中央 (Central-DR) 的 **Nexus Raw Repository**。
*   **安全性**：不需跨叢集 `kubeconfig`，分站只需持有 Nexus 的上傳帳密。
*   **實作參考**：
    - [Nexus 安裝腳本 (VM)](./setup_nexus.sh)
    - [NetBox 備份 CronJob 範本](./netbox-backup-cronjob.yaml)

#### 實施步驟：
1.  **中央站點 (Central-DR)**:
    - 執行 `setup_nexus.sh` 安裝 Nexus。
    - 登入 Nexus UI，創建一個類型為 `raw (hosted)` 的 Repository，命名為 `netbox-backups`。
    - 創建一個專用帳號 (如 `backup-user`) 並賦予上傳權限。
2.  **分站站點 (Site-A)**:
    - 建立 `nexus-credentials` Secret 儲存帳密。
    - 部署 `netbox-backup-cronjob.yaml`，並修改 `NEXUS_URL` 指向中央站點 IP。

### B. pgBackRest 集中化倉庫 (推薦大規模使用)
在中央部署 pgBackRest Repo 服務。各分站資料庫 Pod 只需配置 `archive_command` 指向中央服務。

*   **運作原理**：
    1.  **WAL 歸檔 (WAL Archiving)**：分站資料庫將每次異動產生的 Write-Ahead Log (WAL) 檔案，即時推送到中央的 pgBackRest Repo (或指定的 S3 儲存)。
    2.  **增量/差異備份 (Incremental/Delta Backups)**：除了一開始的完整備份，後續的備份 pgBackRest 只會比對並傳輸修改過的資料塊 (Block-level)，極大程度節省了網路頻寬與備份時間。
    3.  **時間點還原 (PITR)**：因為擁有連續的 WAL 日誌，當災難發生時，您可以將資料庫還原到「過去的任意一秒鐘」，避免人為誤刪造成的無法挽回的損失。
*   **優勢**：pgBackRest 是在應用層運作，不需要 `kubectl exec` 權限，只需網路埠 (TLS) 連通即可。
*   **實施門檻**：⚠️ **極高 (不建議 User Role 採用)**。
    *   **預設限制**：NetBox 依賴的 Bitnami PostgreSQL 鏡像基於極簡與安全設計 (以非 root `uid 1001` 運行)。雖然可能內含 pgBackRest 執行檔，但完全沒有預先設定，也缺乏將 WAL 寫入 S3/Repo 的環境權限。
    *   **改造複雜**：若要強行使用，必須打破「單一容器」原則。您需要自行撰寫 Dockerfile 製作 Custom Image 植入設定，或是透過 Helm 撰寫複雜的 Sidecar 容器並共用磁碟 (`/bitnami/postgresql/data`)，這超出了一般應用部署權限 (User Role) 的能力範圍。

### C. 中央異地串流副本 (DR Hub / Warm Standby - 強烈推薦)
在中央部署分站的備援 Pod (Standby)。
*   **機制**：中央的 Standby Pod 主動連向分站的 Primary DB 拉取串流日誌。
*   **部署實務**：只需在中央部署普通的 StatefulSet，並在配置中填入分站資料庫的連線字串。
*   **優勢**：物理級同步，包含 Schema 與 Sequence，災難發生時一鍵 `promote` 即可接管，無需修復資料。
*   **缺點 (規模化限制)**：必須維持 **1:1 的實例映射**。若有 20 個分站，中央叢集就必須建立 20 套獨立的 PostgreSQL Standby 實例。這會導致中央叢集的資源消耗 (CPU/Memory/PVC) 與維運複雜度隨著分站數量線性暴增。

---

## 5. 附錄：關鍵指令參考


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

1.  **分層儲存**：備份檔應至少保留一份於中央叢集的持久儲存，並同步一份至冷儲存。
2.  **定時演練**：每季度選定一個 Site 進行「中央接管演練」，確保 DR 流程有效。
3.  **監控指標**：在 Prometheus 中監控「備份成功率」與「流複製延遲時間 (Replication Lag)」。
