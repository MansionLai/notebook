---
title: Phase 4 - RBD Pool 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 14
permalink: /storage/3node-ceph/phase-4/
---

# Phase 4 — RBD Pool 建立（dc1 baseline）

## 目標

建立 `k8s_rbd_pool` 並完成基礎驗證（size/min_size/測試 image）。

## 前置條件

- 已完成 [Phase 3](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-3/)
- Cluster 為 dc1 baseline 拓撲（3 MON + 3 OSD nodes）

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-4.yml
```

## 這個 Ansible 會修改哪些系統狀態

- 若 `k8s_rbd_pool` 不存在，建立 pool（使用設定中的 pg/pgp）。
- 設定 pool 參數：`size`、`min_size`、`crush_rule`、`pg_autoscale_mode=off`。
- 啟用 pool 的 `rbd` application，並在新建 pool 時執行 `rbd pool init`。
- 若測試 image 不存在，建立 `ceph_test_image_name` 測試 image。

## 驗證方式

```bash
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd pool ls detail"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd pool get k8s_rbd_pool size"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd pool get k8s_rbd_pool min_size"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo rbd ls k8s_rbd_pool"
```

預期結果：

- pool `k8s_rbd_pool` 存在
- `size=3`, `min_size=1`
- 驗證 image 可建立
