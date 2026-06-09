# NetBox DR 方案 A 實測記錄 (Azure Nexus Lab)

本文檔記錄在 2026/06/09 於 Azure Lab 環境下，完成 **Option A (分站推送備份到 Nexus)** 的完整實測結果。

## 1. 實驗環境細節

### Site-A (分站 - Primary)
- **環境**: 3-node K3s Cluster (v1.35.5)
- **Control Plane**: `20.43.84.219` (Private: `10.0.0.4`)
- **NetBox 部署**: Helm Chart (Bitnami PostgreSQL + Redis/Valkey)
- **PostgreSQL**: `registry-1.docker.io/bitnami/postgresql:latest`

### Central-DR (中央 - DR Site)
- **環境**: 3-node K3s Cluster (v1.35.5)
- **Control Plane**: `20.46.161.104` (Private: `10.0.0.7`)
- **Nexus 部署**: K8s Deployment in `nexus` namespace
- **Nexus URL**: `http://20.46.161.104:30081/repository/netbox-backups`
- **初始密碼**: `be553685-2887-49aa-94ef-9813abe47d9c`

---

## 2. 實作組件清單

### 2.1 Nexus Repository 配置
- **Repo Name**: `netbox-backups`
- **Format**: `raw (hosted)`
- **Backup User**: `backup-user` / `NetboxBackup123!`

### 2.2 Site-A 備份 CronJob
- **名稱**: `netbox-backup`
- **排程**: `0 2 * * *` (每日凌晨 2 點)
- **邏輯**:
    1. 使用 `pg_dump` 導出 `netbox` 資料庫。
    2. 使用 `gzip` 壓縮。
    3. 透過 `curl -u ... --upload-file` 將檔案推送到 Nexus REST API。

---

## 3. 測試驗證結果

### 3.1 Job 執行記錄
手動觸發 `manual-test-backup-v2` 成功，執行日志如下：
```text
Starting backup to netbox-backup-202606091332.sql.gz...
Uploading to Nexus...
* Connected to 20.46.161.104 (20.46.161.104) port 30081 (#0)
> PUT /repository/netbox-backups/netbox-backup-202606091332.sql.gz HTTP/1.1
< HTTP/1.1 201 Created
Backup completed successfully.
```

### 3.2 Nexus 端檔案確認
透過 Nexus API 查詢確認檔案已入庫：
- **檔案名稱**: `netbox-backup-202606091332.sql.gz`
- **檔案大小**: `86,951 bytes` (壓縮後)
- **上傳者**: `backup-user`
- **時間**: `2026-06-09T13:32:54.864+00:00`

---

## 4. 實戰結論 (方案 A)
1. **可行性 (Feasibility)**: **100% 成功**。透過 NodePort 暴露 Nexus 並使用標準 `curl` 上傳非常穩定。
2. **優點**: 
   - 無需 Cloud Provider 的 S3 權限，完全自主控管。
   - 備份檔自帶時間戳，在 Nexus 中清晰可見。
   - 恢復時只需 `curl` 下載 dump 檔並 `pg_restore` 即可。
3. **建議**:
   - 生產環境應使用 `PersistentVolume` 掛載 Nexus 數據目錄（本實驗使用 `emptyDir`）。
   - Nexus 密碼應使用更複雜的生成機制並透過 Secret 管理。
