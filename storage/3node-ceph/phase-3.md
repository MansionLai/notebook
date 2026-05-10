---
title: Phase 3 - Cluster 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 13
permalink: /storage/3node-ceph/phase-3/
---

# Phase 3 — Cluster 建立

## 目標

完成 Ceph cluster 建立，包括 bootstrap 第一台節點、加入其他節點、設定網路、部署 MON/MGR/OSD。

---

## Step 3-1：Bootstrap 第一台節點

在 `ceph-node-01` 執行：

```bash
sudo cephadm bootstrap \
  --mon-ip 10.10.10.10 \
  --cluster-network 172.10.10.0/24 \
  --initial-dashboard-user admin \
  --initial-dashboard-password <YOUR_PASSWORD> \
  --allow-fqdn-hostname \
  --skip-monitoring-stack
```

**參數說明：**

- `--mon-ip`: MON 服務監聽的 IP（public network）
- `--cluster-network`: OSD replication 使用的網路
- `--skip-monitoring-stack`: 跳過 Prometheus/Grafana（可後續啟用）

**預期輸出：**

```
Ceph Dashboard is now available at:

     URL: https://ceph-node-01:8443/
    User: admin
Password: <YOUR_PASSWORD>

...
Bootstrap complete.
```

驗證 bootstrap 成功：

```bash
sudo ceph -s
```

**預期輸出：**

```
  cluster:
    id:     <CLUSTER_ID>
    health: HEALTH_WARN
            ...

  services:
    mon: 1 daemons, quorum ceph-node-01 (age ...)
    mgr: ceph-node-01.<ID>(active, since ...)
    osd: 0 osds: 0 up, 0 in
```

---

## Step 3-2：設定 Public 與 Cluster Network

確認網路設定：

```bash
sudo ceph config get mon public_network
sudo ceph config get mon cluster_network
```

如需修改：

```bash
# 設定 public_network
sudo ceph config set mon public_network 10.10.10.0/24

# 設定 cluster_network
sudo ceph config set global cluster_network 172.10.10.0/24
```

---

## Step 3-3：加入其他節點到 Cluster

在 `ceph-node-01` 執行：

```bash
# 加入 ceph-node-02
sudo ceph orch host add ceph-node-02 10.10.10.11

# 加入 ceph-node-03
sudo ceph orch host add ceph-node-03 10.10.10.12
```

驗證節點加入：

```bash
sudo ceph orch host ls
```

**預期輸出：**

```
HOST           ADDR         LABELS  STATUS
ceph-node-01   10.10.10.10          
ceph-node-02   10.10.10.11          
ceph-node-03   10.10.10.12          
```

---

## Step 3-4：部署 MON 到所有節點

```bash
# 設定 MON 部署到 3 個節點
sudo ceph orch apply mon --placement="3 ceph-node-01 ceph-node-02 ceph-node-03"
```

等待 MON 部署完成（約 1-2 分鐘）：

```bash
sudo ceph orch ps --daemon-type mon
```

驗證 MON quorum：

```bash
sudo ceph mon stat
```

**預期輸出：**

```
e3: 3 mons at {ceph-node-01=...,ceph-node-02=...,ceph-node-03=...}, election epoch ..., leader 0 ceph-node-01, quorum 0,1,2
```

---

## Step 3-5：部署 MGR 到所有節點

```bash
# 設定 MGR 部署到 3 個節點（active + standby）
sudo ceph orch apply mgr --placement="3 ceph-node-01 ceph-node-02 ceph-node-03"
```

驗證 MGR 狀態：

```bash
sudo ceph orch ps --daemon-type mgr
```

檢查 MGR：

```bash
sudo ceph -s
```

**預期輸出：**

```
  services:
    mon: 3 daemons, quorum ceph-node-01,ceph-node-02,ceph-node-03
    mgr: ceph-node-01.xxx(active), standbys: ceph-node-02.xxx, ceph-node-03.xxx
```

---

## Step 3-6：加入 OSD（每台 2 顆 data disks）

在 `ceph-node-01` 執行：

```bash
# 列出可用磁碟
sudo ceph orch device ls

# 應看到 /dev/sdc 與 /dev/sdd 在三台節點上都可用
```

**方法 1：手動逐一加入 OSD**

```bash
# ceph-node-01
sudo ceph orch daemon add osd ceph-node-01:/dev/sdc
sudo ceph orch daemon add osd ceph-node-01:/dev/sdd

# ceph-node-02
sudo ceph orch daemon add osd ceph-node-02:/dev/sdc
sudo ceph orch daemon add osd ceph-node-02:/dev/sdd

# ceph-node-03
sudo ceph orch daemon add osd ceph-node-03:/dev/sdc
sudo ceph orch daemon add osd ceph-node-03:/dev/sdd
```

**方法 2：自動加入所有可用磁碟**

```bash
# 自動將所有可用磁碟加入為 OSD
sudo ceph orch apply osd --all-available-devices
```

等待 OSD 建立（約 2-5 分鐘）：

```bash
# 監控 OSD 建立進度
watch sudo ceph -s
```

驗證 OSD 狀態：

```bash
sudo ceph osd tree
```

**預期輸出：**

```
ID  CLASS  WEIGHT   TYPE NAME             STATUS  REWEIGHT  PRI-AFF
-1         0.35156  root default                                   
-3         0.11719      host ceph-node-01                          
 0    hdd  0.05859          osd.0             up   1.00000  1.00000
 1    hdd  0.05859          osd.1             up   1.00000  1.00000
-5         0.11719      host ceph-node-02                          
 2    hdd  0.05859          osd.2             up   1.00000  1.00000
 3    hdd  0.05859          osd.3             up   1.00000  1.00000
-7         0.11719      host ceph-node-03                          
 4    hdd  0.05859          osd.4             up   1.00000  1.00000
 5    hdd  0.05859          osd.5             up   1.00000  1.00000
```

---

## Step 3-7：驗證 Cluster Health

```bash
sudo ceph -s
```

**預期輸出：**

```
  cluster:
    id:     <CLUSTER_ID>
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node-01,ceph-node-02,ceph-node-03
    mgr: ceph-node-01.xxx(active), standbys: ceph-node-02.xxx, ceph-node-03.xxx
    osd: 6 osds: 6 up, 6 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:     
```

檢查 MON 詳細資訊：

```bash
sudo ceph mon stat
sudo ceph mon dump
```

檢查 OSD 詳細資訊：

```bash
sudo ceph osd stat
sudo ceph osd df
```

---

## 驗證清單

完成此 Phase 後，確認以下項目：

| 項目 | 驗證方式 | 預期結果 |
|------|---------|---------|
| Bootstrap 成功 | `sudo ceph -s` | cluster 顯示正常 |
| 網路設定 | `sudo ceph config get mon public_network` | 10.10.10.0/24 |
| 網路設定 | `sudo ceph config get global cluster_network` | 172.10.10.0/24 |
| 3 個節點加入 | `sudo ceph orch host ls` | 3 hosts |
| MON quorum | `sudo ceph mon stat` | 3 mons in quorum |
| MGR active | `sudo ceph -s` | mgr active + standbys |
| 6 個 OSD up | `sudo ceph osd tree` | 6 osds up + in |
| Cluster health | `sudo ceph -s` | HEALTH_OK |

---

## 預期產出

- ✅ Ceph cluster bootstrap 完成
- ✅ 3 台節點加入 cluster
- ✅ Public network: 10.10.10.0/24
- ✅ Cluster network: 172.10.10.0/24
- ✅ MON quorum: 3 個 MON
- ✅ MGR: 1 active + 2 standby
- ✅ OSD: 6 個 OSD 全部 up + in
- ✅ Cluster health: HEALTH_OK
- ✅ 準備好建立 RBD pool
