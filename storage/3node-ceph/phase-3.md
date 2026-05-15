---
title: Phase 3 - Cluster 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 13
permalink: /storage/3node-ceph/phase-3/
---

# Phase 3 — Cluster 建立

## 目標

從 Mac mini 透過 Ansible 在 `ceph-node-01` 完成 `cephadm bootstrap`，並把另外兩台節點加入 orchestrator、部署 MON/MGR/OSD，建立 3-node Ceph cluster。

---

## 前置條件

- 已完成 [Phase 2](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-2/)
- `group_vars/all.yml` 內的 dashboard 帳密已調整成你可接受的 lab 值
- `ceph-node-01` 能無密碼 SSH 到三台節點

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-3.yml
```

---

## 這個 Phase 的 role 會做什麼

- 若尚未 bootstrap，於 `ceph-node-01` 執行 `cephadm bootstrap`
- 設定 `public_network` 與 `cluster_network`
- 將 `ceph-node-02`、`ceph-node-03` 加入 orchestrator
- 套用 3-node MON placement
- 套用 3-node MGR placement
- 針對 inventory / host vars 內定義的 `ceph_osd_devices` 加入 OSD
- 等待 cluster 達到：
  - 3 MON
  - 6 OSD up
  - 6 OSD in

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-3.yml
storage/3node-ceph/ansible/roles/cluster_build/
```

---

## 驗證方式

從 Mac mini 或 `ceph-node-01` 驗證：

```bash
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph -s"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph orch host ls"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph mon stat"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph orch ps --daemon-type mgr"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph osd tree"
```

預期結果：

- 3 hosts 都在 orchestrator
- MON quorum 為 3
- MGR active + standbys 正常
- `osd: 6 osds: 6 up, 6 in`
- Dashboard 預設在 `https://ceph-node-01:8443/`

---

## Troubleshooting

- bootstrap 失敗：先確認 `ceph-node-01` 的 `cephadm version`、`ceph --version`、以及 SSH key / config 是否完整
- host add 失敗：通常是 hostname 解析或 cephadm SSH 失敗
- OSD 沒起來：先檢查 `ceph orch device ls` 與 `host_vars/*.yml` 的 `ceph_osd_devices` 是否一致
