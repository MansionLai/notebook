---
title: Phase 4 - RBD Pool 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 14
permalink: /storage/3node-ceph/phase-4/
---

# Phase 4 — RBD Pool 建立

## 目標

從 Mac mini 透過 Ansible 建立 `rbdpool`、設定 replication 與 PG 參數、初始化 RBD 應用，並驗證 test image 可正常建立。

---

## 前置條件

- 已完成 [Phase 3](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-3/)
- Cluster 已有 3 MON / 3 MGR / 6 OSD
- `group_vars/all.yml` 已確認：
  - `ceph_rbd_pool_name`
  - `ceph_rbd_pool_pg_num`
  - `ceph_rbd_pool_pgp_num`
  - `ceph_rbd_pool_size`
  - `ceph_rbd_pool_min_size`

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-4.yml
```

---

## 這個 Phase 的 role 會做什麼

- 建立 `rbdpool`
- 設定 `size=3`、`min_size=1`
- 啟用 `rbd` application
- 執行 `rbd pool init`
- 建立 `test-image`
- 驗證 pool detail、image info 與 PG 狀態

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-4.yml
storage/3node-ceph/ansible/roles/phase4_rbd_pool/
```

---

## 驗證方式

```bash
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph osd pool ls detail"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph osd pool get rbdpool size"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph osd pool get rbdpool min_size"
ssh ubuntu@<ceph-node-01-public-ip> "sudo rbd ls rbdpool"
ssh ubuntu@<ceph-node-01-public-ip> "sudo rbd info rbdpool/test-image"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph pg stat"
```

預期結果：

- pool `rbdpool` 存在
- `size=3`
- `min_size=1`
- `test-image` 已建立
- PG 狀態進入 `active+clean`

---

## Troubleshooting

- `pool already exists`：代表 Phase 4 曾執行過，通常不需要清掉重建
- `application already enabled`：可視為 idempotent 正常情況
- PG 不 clean：先回頭檢查 `ceph -s`、`ceph osd tree` 與 OSD/replication 狀態
