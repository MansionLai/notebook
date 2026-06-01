---
title: NetBox Backup and Disaster Recovery
parent: Netbox
nav_order: 99
---

# NetBox Backup and Disaster Recovery

## 方案比較表

| 方案類型 | 說明 | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| 單向備援（主備） | 定期將 NetBox01 的資料庫、media、config 備份同步到 NetBox02，災難時手動切換 | 架構簡單、維護容易、資料一致性高 | 需手動切換、RPO 取決於備份頻率 | 跨區域備援、災難復原 |
| 雙向同步（Active-Active） | 兩套 NetBox 互相同步資料，理論上可同時對外服務 | 理論上零停機、可分散讀取壓力 | NetBox 無原生支援，易有資料衝突與一致性問題，維護困難 | 嚴格高可用需求（不建議） |
| 高可用（HA） | 多個 NetBox 實例共用同一 PostgreSQL 資料庫叢集，搭配負載平衡 | 自動故障切換、無需手動操作 | 需共用資料庫，跨區域困難，僅適合同區高可用 | 同區高可用、不中斷服務 |

> NetBox 並不原生支援多活（active-active）或自動雙向同步（sync）兩套 NetBox 實例。強行同步容易造成資料衝突與一致性問題，建議採用主備架構，定期單向同步資料，災難時手動切換。

## 1. Backup Best Practices

> 目標環境：NetBox on Kubernetes、PostgreSQL + Redis（皆 3 replicas）、儲存層為同機房 NFS StorageClass，異地備份目標為 Nexus（HTTP/S）。

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

### C. 備份排程（Option 1：定期自動備份 + 手動還原）

用 K8s CronJob 執行，範例頻率：
- DB dump：每 6 小時
- config：每日 1 次（或依變更頻率調整）

備份程序（在 backup job 容器內）：
```bash
set -euo pipefail
TS="$(date +%Y%m%d-%H%M%S)"
WORKDIR="/backup/${TS}"
mkdir -p "${WORKDIR}"/{db,config}

# 1) PostgreSQL logical backup
PGPASSWORD="${PGPASSWORD}" pg_dump \
  -h "${PGHOST}" -U "${PGUSER}" -d "${PGDATABASE}" \
  -Fc -f "${WORKDIR}/db/netbox_${TS}.dump"

# 2) Config / secrets export (建議由 CI 事先產生 sanitized values 檔)
cp /backup-input/values.yaml "${WORKDIR}/config/values_${TS}.yaml"

# 3) Checksum
find "${WORKDIR}" -type f -exec sha256sum {} \; > "${WORKDIR}/manifest_${TS}.txt"

# 4) Upload to Nexus (HTTP/S)
tar -C /backup -czf "/backup/netbox-backup-${TS}.tar.gz" "${TS}"
curl -fSL -u "${NEXUS_USER}:${NEXUS_PASS}" \
  --upload-file "/backup/netbox-backup-${TS}.tar.gz" \
  "${NEXUS_URL}/repository/netbox-backup/netbox-backup-${TS}.tar.gz"
```

### D. 備份健檢與演練（強制）

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

- cluster1：主要服務（NetBox01）
- cluster2：平時 standby（NetBox02），不建議 active-active
- 兩邊都從同一個 Nexus 備份來源取檔；災難時在 cluster2 還原後切流量

建議切換流程：
1. 宣告 cluster1 故障、凍結寫入。
2. 在 cluster2 部署相同 Helm chart（版本固定）。
3. 在 cluster2 執行 restore job（指定最新可用備份版本）。
4. 驗證 NetBox API/UI 與關鍵資料。
5. 將 client/DNS/LB 指向 NetBox02。
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
