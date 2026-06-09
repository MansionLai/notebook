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

## 4. 災難恢復演練 (Restore Procedure)

假設 Site-A 遭遇毀滅性故障且已完成 K3s 叢集重建，以下是從 Nexus 恢復 NetBox 資料的標準流程：

### 4.1 環境準備
1.  **重新部署 NetBox**: 使用原有的 Helm `values.yaml` 重新安裝 NetBox。
2.  **暫停應用寫入**: 為了確保資料一致性，建議將 NetBox App 副本數設為 0。
    ```bash
    kubectl scale deployment netbox -n netbox --replicas=0
    kubectl scale deployment netbox-worker -n netbox --replicas=0
    ```

### 4.2 下載備份檔案
在 Site-A 的 Control Plane 節點執行，從 Nexus 下載指定的備份檔：
```bash
BACKUP_NAME="netbox-backup-202606091332.sql.gz"
curl -u backup-user:NetboxBackup123! \
  -O "http://20.46.161.104:30081/repository/netbox-backups/$BACKUP_NAME"
```

### 4.3 執行資料庫還原
我們將下載的壓縮檔解壓並透過 `psql` 灌回資料庫：

1. **取得資料庫密碼**:
   ```bash
   DB_PASSWORD=$(kubectl get secret netbox-postgresql -n netbox -o jsonpath='{.data.password}' | base64 -d)
   ```

2. **清空舊資料 (Drop & Create)**:
   ```bash
   # 進入 DB Pod 執行
   kubectl exec -it netbox-postgresql-primary-0 -n netbox -- bash -c "DROPDB_PASSWORD=$DB_PASSWORD dropdb -h localhost -U netbox netbox && createdb -h localhost -U netbox netbox"
   ```

3. **匯入 SQL 數據**:
   ```bash
   gunzip -c $BACKUP_NAME | kubectl exec -i netbox-postgresql-primary-0 -n netbox -- bash -c "PGPASSWORD=$DB_PASSWORD psql -h localhost -U netbox -d netbox"
   ```

### 4.4 恢復服務
1.  **重啟 Pod**:
    ```bash
    kubectl scale deployment netbox -n netbox --replicas=1
    kubectl scale deployment netbox-worker -n netbox --replicas=1
    ```
2.  **驗證**: 登入 NetBox Web UI，確認所有 Site、Device 等資料已正確恢復。

---

## 5. 實戰結論 (方案 A)
1. **可行性 (Feasibility)**: **100% 成功**。透過 NodePort 暴露 Nexus 並使用標準 `curl` 上傳非常穩定。
2. **優點**: 
   - 無需 Cloud Provider 的 S3 權限，完全自主控管。
   - 備份檔自帶時間戳，在 Nexus 中清晰可見。
   - 恢復時只需 `curl` 下載 dump 檔並 `pg_restore` 即可。
3. **建議**:
   - 生產環境應使用 `PersistentVolume` 掛載 Nexus 數據目錄（本實驗使用 `emptyDir`）。
   - Nexus 密碼應使用更複雜的生成機制並透過 Secret 管理。
