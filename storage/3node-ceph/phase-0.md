---
title: Phase 0 - Azure 資源建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 10
permalink: /storage/3node-ceph/phase-0/
---

# Phase 0 — Azure 資源建立（dc1 baseline）

## 環境概覽

| 節點 | Role | Azure VM | Public IP (shared-node-subnet) | Cluster IP (mansion-ceph-cluster-subnet) | 磁碟 |
|------|------|----------|--------------------------------|----------------------------------|------|
| mon-dc1-01 | MON | Standard_D2s_v4 (2C/8G) | 10.10.10.21 | 172.10.10.21 | 1x OS |
| mon-dc1-02 | MON | Standard_D2s_v4 (2C/8G) | 10.10.10.22 | 172.10.10.22 | 1x OS |
| mon-dc1-03 | MON | Standard_D2s_v4 (2C/8G) | 10.10.10.23 | 172.10.10.23 | 1x OS |
| osd-dc1-01 | OSD | Standard_D2s_v4 (2C/8G) | 10.10.10.24 | 172.10.10.24 | 1x OS + 2x OSD |
| osd-dc1-02 | OSD | Standard_D2s_v4 (2C/8G) | 10.10.10.25 | 172.10.10.25 | 1x OS + 2x OSD |
| osd-dc1-03 | OSD | Standard_D2s_v4 (2C/8G) | 10.10.10.26 | 172.10.10.26 | 1x OS + 2x OSD |

**Public Network:** 10.10.10.0/24 (`shared-node-subnet`)  
**Cluster Network:** 172.10.10.0/24 (`mansion-ceph-cluster-subnet`)

---

## 建置模式

> ✅ **唯一推薦：Azure MCP + Bicep**

- 使用 `storage/3node-ceph/iac/main.bicep` + `main.bicepparam`
- 部署目標是 **dc1 baseline 6 台**
- dc2 擴展不在本系列 phase，請改看 `storage/ceph-cross-dc-migration`

---

## 磁碟配置總覽

### MON node

| 磁碟 | 用途 |
|------|------|
| OS Disk (64 GiB) | 作業系統與 Ceph 軟體 |

### OSD node

| 磁碟 | 用途 |
|------|------|
| OS Disk (64 GiB) | 作業系統與 Ceph 軟體 |
| OSD Disk 1 (64 GiB) | OSD 資料儲存 |
| OSD Disk 2 (64 GiB) | OSD 資料儲存 |

> ⚠️ `/dev/sdb` 是 Azure temporary disk，不可用於 OSD

---

## 預期產出

- ✅ 6 台 VM 可 SSH 登入
- ✅ 每台有 2 張 NIC（public + cluster）
- ✅ MON 節點僅 1 顆 OS disk
- ✅ OSD 節點有 1 顆 OS + 2 顆 OSD disks
- ✅ Public IP 可從外部存取

