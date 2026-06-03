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

- 已完成 [Phase 2](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-2/)

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-3.yml
```

## 驗證方式

```bash
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph -s"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph mon stat"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph orch host ls"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd tree"
```

預期結果：

- MON quorum 為 3
- OSD 節點已部署預期 OSD daemon
- `public_network = 10.10.10.0/24`
- `cluster_network = 172.10.10.0/24`
- PG 最終進入 `active+clean`

