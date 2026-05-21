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
- `inventory/group_vars/encrypted.yml` 內的 dashboard 帳密已調整成你可接受的 lab 值
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
  - 使用 public NIC (`10.10.10.21`) 作為 bootstrap 節點
  - 配置 `public_network = 10.10.10.0/24`
  - 配置 `cluster_network = 172.10.10.0/24`
- 將 `ceph-node-02`、`ceph-node-03` 加入 orchestrator（使用各自的 cluster 網卡地址）
- 套用 3-node MON placement
- 套用 3-node MGR placement
- 針對 inventory / host vars 內定義的 `ceph_osd_devices` 加入 OSD
- 設定 CRUSH map 的 failure domain 為 `rack`（使用 locations.yml 內定義的 datacenter/room/rack）
- 等待 cluster 達到：
  - 3 MON
  - 6 OSD up
  - 6 OSD in
  - All PGs active+clean

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
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph config get mon public_network"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph config get mon cluster_network"
ssh ubuntu@<ceph-node-01-public-ip> "sudo ceph crush rule dump replicated_rule"
```

預期結果：

- 3 hosts 都在 orchestrator（含 cluster IP 地址 172.10.10.x）
- MON quorum 為 3
- MGR active + standbys 正常
- `osd: 6 osds: 6 up, 6 in`
- `public_network = 10.10.10.0/24`
- `cluster_network = 172.10.10.0/24`
- CRUSH rule 內 failure domain 為 `rack`
- Dashboard 預設在 `https://ceph-node-01:8443/`
- All PGs 進入 `active+clean` 狀態

---

## Troubleshooting

- bootstrap 失敗：先確認 `ceph-node-01` 的 `cephadm version`、`ceph --version`、以及 SSH key / config 是否完整
- host add 失敗：通常是 hostname 解析或 cephadm SSH 失敗
- OSD 沒起來：先檢查 `ceph orch device ls` 與 `inventory/hosts.yml` 的 `ceph_osd_devices` 是否一致
