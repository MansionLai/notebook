---
title: Phase 3 - Cluster 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 13
permalink: /storage/3node-ceph/phase-3/
---

# Phase 3 — Cluster 建立（dc1 baseline）

## 目標

建立 dc1 baseline Ceph cluster：

- 3 MON（mon-dc1-01~03）
- OSD 部署於 3 台 OSD 節點（osd-dc1-01~03）

## 前置條件

- 已完成 [Phase 2](/storage/3node-ceph/phase-2/)

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-3.yml
```

## 這個 Ansible 會修改哪些系統狀態

- 首次執行時，在第一台 MON 以 `cephadm bootstrap` 建立 Ceph cluster（若已存在 `/etc/ceph/ceph.conf` 則跳過 bootstrap）。
- 將第一台 MON 的 `/etc/ceph/ceph.conf` 與 `ceph.client.admin.keyring` 同步到所有 MON 節點。
- 設定 Ceph `mon public_network` 與 `global cluster_network`。
- 將 MON 節點加入 `ceph orch host`，OSD 節點則在 `ceph orch host add` 時一併帶入 `datacenter/room/rack` location，並套用 MON/MGR placement。
- 依 inventory 的 `ceph_osd_devices` 對應新增 OSD daemon。
- 依 host location 驗證 CRUSH 拓撲（datacenter/room/rack/host）並建立 replicated CRUSH rule（failure domain=rack）。

## 驗證方式

```bash
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph -s"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph mon stat"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph orch host ls"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd tree"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd crush tree --format json-pretty"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd crush rule ls"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd crush rule dump k8s_rbd_pool_rack"
```

預期結果：

- MON quorum 為 3
- OSD 節點已部署預期 OSD daemon
- `public_network = 10.10.10.0/24`
- `cluster_network = 172.10.10.0/24`
- CRUSH tree 可看到 datacenter/room/rack/host 階層
- `k8s_rbd_pool_rack` rule 存在，且 rule step 使用 `type rack`
- PG 最終進入 `active+clean`
