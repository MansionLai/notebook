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

### A. Database Backups
- Use `pg_dump` to back up the PostgreSQL database regularly.
- Automate backups (e.g., daily cron jobs).
- Store backups off-site and keep multiple recent copies.
- Example:
  ```bash
  pg_dump -U netbox -h localhost netbox > netbox_backup_$(date +%F).sql
  ```
- Regularly test restores in a separate environment.

### B. Media Files Backup
- Backup `/opt/netbox/netbox/media/` using `rsync`, `tar`, or snapshots.
- Store media backups with database dumps.

### C. Configuration Files Backup
- Include `configuration.py`, `extra.py`, and service files (Gunicorn, Nginx, systemd) in backups.
- Store configs in a private Git repo if possible.

### D. Application Code Backup
- Use version control (Git) for custom scripts, plugins, and template overrides.

## 2. Disaster Recovery

### A. Documentation
- Document the restore process, including dependencies and service startup.

### B. Recovery Testing
- Regularly test recovery in an isolated environment.
- Perform periodic "fire drills" to ensure full restoration is possible.

### C. Automation
- Use tools like Ansible or Terraform to automate server and app provisioning.

### D. Backup Redundancy
- Store backups off-site or in the cloud; use immutability features if available.

### E. Minimizing Downtime
- Consider PostgreSQL hot standby replication for high availability.
- For advanced setups, use Docker/Kubernetes with persistent storage and failover.

## 3. Additional Best Practices
- Encrypt backups, especially for off-site/cloud storage.
- Restrict access to backups and restore procedures.
- Monitor and alert on backup failures.

## References
- [NetBox Maintenance Docs](https://docs.netbox.dev/en/stable/administration/maintenance/)
- [PostgreSQL Backup Solutions](https://www.postgresql.org/docs/current/backup.html)
