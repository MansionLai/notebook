---
title: NetBox Backup and Disaster Recovery
parent: Netbox
nav_order: 99
---

# NetBox Backup and Disaster Recovery

## 方案比較表

| 方案類型 | 說明 | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| 單向備援（主備） | 定期將 Azure VM 叢集 A 的資料庫、media、config 備份同步到 Azure VM 叢集 B，災難時手動切換 | 架構簡單、維護容易、資料一致性高 | 需手動切換、RPO 取決於備份頻率 | 跨區域備援、災難復原 |
| 雙向同步（Active-Active） | 兩套 NetBox 互相同步資料，理論上可同時對外服務 | 理論上零停機、可分散讀取壓力 | NetBox 無原生支援，易有資料衝突與一致性問題，維護困難 | 嚴格高可用需求（不建議） |
| 高可用（HA） | 多個 NetBox 實例共用同一 PostgreSQL 資料庫叢集，搭配負載平衡 | 自動故障切換、無需手動操作 | 需共用資料庫，跨區域困難，僅適合同區高可用 | 同區高可用、不中斷服務 |

> NetBox 並不原生支援多活（active-active）或自動雙向同步（sync）兩套 NetBox 實例。強行同步容易造成資料衝突與一致性問題，建議採用主備架構，定期單向同步資料，災難時手動切換。

## 1. Backup Best Practices

> 目標環境：Azure VM 上的 NetBox on K3s、PostgreSQL + Redis（副本數可依環境設定）、儲存層為 Azure VM 本機磁碟 / local-path，異地備份目標為 Nexus（HTTP/S）。

### A. 備份範圍（單向備援主備）

必備：
- PostgreSQL 資料：以 `pg_dump -Fc` 產生一致性邏輯備份。
- 關鍵設定與密鑰：Helm values、NetBox secret key、DB/Redis credentials、Ingress/TLS 相關設定。

不建議作為主要 DR 資料來源：
- Redis 資料本體（NetBox 多數場景可重建快取）；建議只備份 Redis 設定與連線憑證。

可選（你目前可不做）：
- NetBox media：`/opt/netbox/netbox/media/`（僅在有使用附件/圖片/檔案上傳時才需要）。

### B. 備份封裝格式與命名

- 每次備份產生一個版本目錄（或壓縮檔）：
  - `db/netbox_<timestamp>.dump`
  - `config/values_<timestamp>.yaml`
  - `manifest_<timestamp>.txt`（含 sha256）
- 備份命名建議：`netbox-backup-YYYYmmdd-HHMMSS`
- 上傳 Nexus 後保留策略：`7 daily + 4 weekly + 3 monthly`

### C. 備份程序（Step-by-Step 執行手冊）

假設你有一台可連 K8s API 與 Nexus 的管理機（bastion / jump host），已安裝 `kubectl`、`helm`、`curl`。

| 步驟 | 在哪裡執行 | 指令/動作 |
|---|---|---|
| 1. 設定變數 | 管理機 | `export NS=netbox`<br>`export REL=netbox`<br>`export NEXUS_URL='https://nexus.example.com/repository/netbox-backup'`<br>`export NEXUS_USER='xxx'`<br>`export NEXUS_PASS='xxx'`<br>`export TS=$(date +%Y%m%d-%H%M%S)`<br>`mkdir -p ~/netbox-backup/$TS/{db,config}` |
| 2. 找 PostgreSQL 主節點 Pod | 管理機 | `PG_POD=$(kubectl -n $NS get pod -l app.kubernetes.io/component=primary -o jsonpath '{.items[0].metadata.name}')` |
| 3. PostgreSQL dump (`pg_dump -Fc`) | **PostgreSQL Pod 內**（由管理機 `kubectl exec` 觸發） | `kubectl -n $NS exec $PG_POD -- bash -lc 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_dump -U netbox -d netbox -Fc -f /tmp/netbox_'$TS'.dump'` |
| 4. 把 DB 備份抓回管理機 | 管理機 | `kubectl -n $NS cp $PG_POD:/tmp/netbox_$TS.dump ~/netbox-backup/$TS/db/` |
| 5. 備份 Helm values | 管理機 | `helm -n $NS get values $REL -o yaml > ~/netbox-backup/$TS/config/values_$TS.yaml` |
| 6. 備份 Secrets | 管理機 | `kubectl -n $NS get secret -o yaml > ~/netbox-backup/$TS/config/secrets_$TS.yaml` |
| 7. 產生校驗檔 | 管理機 | `cd ~/netbox-backup/$TS && find . -type f -exec shasum -a 256 {} \; > manifest_$TS.txt` |
| 8. 打包備份 | 管理機 | `cd ~/netbox-backup && tar -czf netbox-backup-$TS.tar.gz $TS` |
| 9. 上傳 Nexus（HTTP/S） | 管理機 | `curl -fSL -u "$NEXUS_USER:$NEXUS_PASS" --upload-file netbox-backup-$TS.tar.gz "$NEXUS_URL/netbox-backup-$TS.tar.gz"` |
| 10. 驗證上傳成功 | 管理機 | `curl -fI -u "$NEXUS_USER:$NEXUS_PASS" "$NEXUS_URL/netbox-backup-$TS.tar.gz"` |

**執行提示**
- 所有指令都在管理機執行，pod 內操作由 `kubectl exec` 完成
- 變數 `$NS`、`$NEXUS_URL`、`$NEXUS_USER`、`$NEXUS_PASS` 依你環境調整
- 確保 NetBox namespace 設定無誤，否則會找不到 pod

### D. 自動排程建議（K8s CronJob）

- **DB dump：每 6 小時** 執行一次
- **Config 備份：每日 1 次** 執行（或依變更頻率調整）
- **保留策略：** `7 daily + 4 weekly + 3 monthly`（自行實作 cleanup 邏輯）

### E. 備份健檢與演練（強制）

- 每次上傳後做 Nexus 檔案存在性驗證（HEAD/GET）。
- 每月至少 1 次在隔離 namespace 做還原演練（非正式環境）。
- 備份失敗要告警（Slack/Email/Webhook 任一）。

## 2. Disaster Recovery

### A. DR 模式（Option 2：一鍵還原）

建立一個 restore Job（或腳本），只需輸入 `backup_version` 即可完成：
1. 從 Nexus 下載指定備份檔。
2. 停止 NetBox app/worker（避免寫入）。
3. 重建目標 DB（或 drop schema）並 `pg_restore`。
4. 套用 config/secrets。
5. 啟動 NetBox，執行 health check。
6. 驗證資料筆數/關鍵物件（例如 devices、ipam prefixes）是否合理。

一鍵還原核心命令範例：
```bash
set -euo pipefail
VER="${BACKUP_VERSION}" # e.g. 20260601-010000

curl -fSL -u "${NEXUS_USER}:${NEXUS_PASS}" \
  -o /restore/netbox-backup-${VER}.tar.gz \
  "${NEXUS_URL}/repository/netbox-backup/netbox-backup-${VER}.tar.gz"

tar -C /restore -xzf /restore/netbox-backup-${VER}.tar.gz

# 停止寫入（實務上可 scale deployment to 0）
kubectl -n netbox scale deploy netbox netbox-worker --replicas=0

# 還原 PostgreSQL
PGPASSWORD="${PGPASSWORD}" dropdb   -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}" || true
PGPASSWORD="${PGPASSWORD}" createdb -h "${PGHOST}" -U "${PGUSER}" "${PGDATABASE}"
PGPASSWORD="${PGPASSWORD}" pg_restore \
  -h "${PGHOST}" -U "${PGUSER}" -d "${PGDATABASE}" \
  "/restore/${VER}/db/netbox_${VER}.dump"

# 啟動服務
kubectl -n netbox scale deploy netbox netbox-worker --replicas=3
```

### B. DR 模式（Option 3：跨叢集異地重建）

- cluster A：主要 Azure VM K3s 叢集
- cluster B：平時 standby 的 Azure VM K3s 叢集，不建議 active-active
- 兩邊都從同一個 Nexus 備份來源取檔；災難時在 cluster B 還原後切流量

建議切換流程：
1. 宣告 cluster A 故障、凍結寫入。
2. 在 cluster B 部署相同 Helm chart（版本固定）。
3. 在 cluster B 執行 restore job（指定最新可用備份版本）。
4. 驗證 NetBox API/UI 與關鍵資料。
5. 將 client/DNS/LB 指向 cluster B。
6. 事件後做 failback 規劃（避免雙向回寫）。

### C. 建議 SLO（初始值）

- RPO：6 小時（可收斂到 1 小時）
- RTO：2~4 小時（有一鍵還原流程可再縮短）
- 每季至少一次完整 DR drill（含 DNS/LB 切換演練）

## 3. Additional Best Practices
- 備份檔與傳輸全程加密（HTTPS + at-rest encryption）。
- Nexus 帳號採最小權限（backup writer 與 restore reader 分離）。
- 備份與還原腳本版本化管理，所有變更要可追蹤。
- 還原流程要文件化為 runbook，並放在值班可存取位置。

## References
- [NetBox Maintenance Docs](https://docs.netbox.dev/en/stable/administration/maintenance/)
- [PostgreSQL Backup Solutions](https://www.postgresql.org/docs/current/backup.html)
