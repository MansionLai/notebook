---
title: NetBox Backup and Disaster Recovery
parent: Netbox
nav_order: 6
---

# NetBox Backup and Disaster Recovery

本指南探討 NetBox 在 Kubernetes 環境下的三種災難復原策略，協助您達成「快速重建」與「資料回復」的目標。

## 方案比較表

| 方案 | 運作方式 | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| **IaC 重建 + 資料還原 (`pg_dump`)** | 使用 GitLab IaC 重建環境，手動匯入資料庫 | 極度乾淨、不依賴舊環境、易於升級 | 需維護還原腳本；若備份頻率不足，災難時會有資料遺失 (RPO 較高) | **推薦**：災難復原、版本升級 |
| **Kubernetes 快照 (Velero)** | 備份 PVC、Secrets、ConfigMaps 與資源 | 自動化程度高、可還原整個 Namespace | 需高權限 (Cluster Admin)；依賴 K8s 環境 | 叢集內局部故障、快速整組回滾 |
| **資料庫單向複製 (僅供 DR)** | 使用 PostgreSQL 串流複製 (Streaming Replication) 將資料由主庫同步到備份庫 | 資料同步時延極低 | **非自動切換**，需人工提升備份庫為 Primary；若操作錯誤極易導致資料遺失 | **進階災備**：嚴格的 RPO 要求 |

---

## 策略分析

### 1. IaC 重建 + 資料還原 (推薦)
這是您目前偏好的方式。架構穩定性最高，且不會有「帶入舊環境配置錯誤」的問題。
- **重建環境**：透過 GitLab 中的 `values.yaml` 與 `helm install` 快速拉起全新的叢集。
- **恢復資料**：使用 `pg_dump` 邏輯備份 SQL 資料。因為這是標準 SQL，即便從 v1.6.4 升級到 v2.x 也能成功。

### 2. Kubernetes 原生方案 (Velero)
Velero 是 K8s 社群的黃金標準。
- **權限要求**：由於 Velero 需要存取叢集內所有 Namespace 的資源與系統層級的 `CustomResourceDefinitions` (CRDs) 與 `PersistentVolume` 物件，它 **必須具備叢集管理員 (Cluster Admin) 或極高權限的 ServiceAccount**。這在嚴格合規的企業環境下是需要特別考量的權限邊界。
- **儲存選擇**：不強制依賴公有雲。
- **企業內部/地端環境方案 (On-Premises)**：
    - **MinIO**：輕量、部署快速，企業內部標準 S3 方案。
    - **Ceph (RADOS Gateway)**：若機房已有 Ceph，可直接利用其 S3 RGW 介面作為備份後端。
- **優勢**：當您的 `netbox-superuser` Secret 或 `media` 資料夾非常複雜時，Velero 可以一鍵還原 Namespace 的所有狀態。

### 3. 資料庫單向複製 (進階 DR)
這並非 NetBox 的「高可用 (HA)」方案。這是一個「異地災難復原 (DR)」手段。
- **重要警示**：NetBox 的架構嚴格依賴單一主資料庫，不具備多寫入同步機制。單向複製 **不能** 當作 Active-Active 架構使用。
- **風險**：若在未正確停止 Primary 的情況下提升 (Promote) 備份庫，極易造成 **Split-Brain (腦裂)**，導致資料損毀。
- **實務建議**：除非您有極高的 RPO 要求且有極強的 PostgreSQL 維運能力，否則請優先採用 **方案 1 (IaC+pg_dump)**。

---

## 多叢集 (Central-to-Site) 備份架構方案

在 **「中央有一套 Central K8s，可存取各分站 Site K8s，且各 Site 皆獨立部署 NetBox」** 的架構前提下，有以下四種備份設計方案可供選擇：

### 多叢集方案比較表

| 方案 | 運作方式 | 優點 | 缺點 | 適用情境 |
| :--- | :--- | :--- | :--- | :--- |
| **A. 中央 Pull 備份** | Central 透過 `kubeconfig` 遠端對各 Site 執行 `pg_dump` 並拉回 Central 儲存 | 集中式管理、Site 端免設定憑證與排程 | Central 需高權限 (Exec)、網路傳輸量大 | Site 數量少、重視中央統一管控 |
| **B. 分站 Push 備份** | 各 Site 本地執行 `pg_dump` 後，將備份推送至 Central 統一的 S3/MinIO | 權限隔離、Site 網路中斷時容錯高 | 各 Site 需保存 S3 存取金鑰 | 叢集規模大、重視安全權限邊界 |
| **C. pgBackRest 倉庫** | Central 建立 pgBackRest Repo，各 Site DB 透過 TLS 傳輸 WAL 與增量備份 | 支援增量備份與時間點還原 (PITR)、省頻寬 | 配置最複雜，需維運 DB Agent | 資料庫龐大、對 RPO 要求極高 |
| **D. 中央唯讀匯總副本** | 利用 PostgreSQL 邏輯複製 (Logical Replication) 即時將各 Site 資料同步至 Central 庫 | 資料即時同步、便於中央進行跨站唯讀查詢 | 需網絡持續連線、Schema 變更維護成本高 | 重視即時災備、需跨站匯總查詢 |

---

### 詳細方案說明

#### 1. 中央 Pull 備份 (Centralized Pull Backup)
在 Central K8s 部署 CronJob，利用 Kubernetes Secret 保存的各站 `kubeconfig`：
```bash
# Central CronJob 遠端備份 Site A 範例
kubectl --kubeconfig=/etc/kubeconfigs/site-a-config exec -n netbox netbox-postgresql-primary-0 -- \
  bash -c "PGPASSWORD='pwd' pg_dump -U netbox -d netbox -Fc" > /backups/site-a-$(date +%F).dump
```

#### 2. 分站 Push 備份 (Decentralized Push to Central Storage)
在 Central 部署 MinIO 作為 S3-Compatible 儲存。各 Site 本地部署備份 Job，直接將備份推送至專屬的 Bucket Prefix：
```bash
# Site A 本地 Job 備份並上傳
pg_dump -U netbox -d netbox -Fc | mc pipe central-minio/netbox-backups/site-a/db-latest.dump
```

#### 3. pgBackRest 中央備份倉庫
在 Central 運行 pgBackRest Dedicated Repo 服務。各 Site PostgreSQL 的 `postgresql.conf` 設定 `archive_command`：
* **特點**：每次備份只傳輸變更的 WAL 日誌，大幅降低 WAN（廣域網路）的流量消耗。

#### 4. 中央唯讀匯總副本 (Logical Replication)
各 Site 的 PostgreSQL 作為 **Publisher**，Central 端的大型 PostgreSQL 作為 **Subscriber**，訂閱各分站的表結構。
* **特點**：Central 隨時保有一份與分站近乎同步的唯讀資料，備份作業只需在 Central 本地對匯總庫進行即可。

---

## 災難復原工作流程 (建議最佳實踐)

針對您希望「快速重建 + Restore 設定與資料」的需求，推薦 **混合策略**：

1.  **IaC (GitLab)**：負責「環境定義」(K8s Resources, Helm Values)。
2.  **邏輯備份 (`pg_dump`)**：負責「應用資料」(NetBox 業務資料)。
3.  **Velero**：負責「自動化備份 K8s 原生配置」(PVC, Secrets)。

### 實施建議：
*   **平時**：配置 Velero 自動備份 `netbox` Namespace 到 **S3-Compatible 儲存 (例如地端的 MinIO)**。
*   **災難時**：
    1. 執行 IaC 重建基礎設施。
    2. 若只需還原 NetBox Namespace，直接執行 `velero restore`（速度最快）。
    3. 若遇特殊架構變更導致 Velero 無法還原，則改用 `pg_dump` 手動執行資料庫還原（最穩健）。

---
## 附錄：指令參考

### 使用 pg_dump 備份
```bash
# 備份 PostgreSQL (在管理機執行)
kubectl -n netbox exec netbox-postgresql-primary-0 -- \
  bash -c "PGPASSWORD='您的密碼' pg_dump -U netbox -d netbox -Fc" > netbox-db-backup.dump
```

### 使用 pg_restore 還原
```bash
# 1. 將備份檔傳入 Pod
kubectl -n netbox cp netbox-db-backup.dump netbox-postgresql-primary-0:/tmp/netbox.dump

# 2. 執行還原 (參數 -c 表示在還原前先清除舊資料庫物件，確保乾淨還原)
kubectl -n netbox exec -it netbox-postgresql-primary-0 -- \
  bash -c "PGPASSWORD='您的密碼' pg_restore -U netbox -d netbox -v -c /tmp/netbox.dump"
```

### 使用 Velero 備份 (S3-Compatible 範例)
（內容不變...）

在安裝 Velero 時，指向您的內網 S3 儲存（如 MinIO）：

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket <minio-bucket-name> \
  --secret-file ./credentials-velero \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://<minio-internal-url>:9000
```

### 驗證建議
*   **每月演練**：不建議僅依賴備份檔，請確保 `deployment-steps.md` 中的「重建步驟」在每個季度至少執行一次測試。
*   **Secret 管理**：確保您的 `netbox-superuser` Secret 關鍵內容（如 `api_token`）同樣備份在安全的地方（例如 GitLab CI/CD Variable 或 Vault）。
