---
title: Phase 2 - Ceph 安裝
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 12
permalink: /storage/3node-ceph/phase-2/
---

# Phase 2 — Ceph 安裝（dc1 baseline）

## 目標

完成 dc1 六台節點 Ceph 先決條件：container runtime、cephadm、ceph-common（MON 節點）、SSH 免密。

## 前置條件

- 已完成 [Phase 1](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-1/)
- `ceph_mon` / `ceph_osd` 分組已可連線

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-2.yml
```

## 驗證方式

```bash
ansible ceph_nodes -m command -a "docker --version"
ansible ceph_mon -m command -a "ceph --version"
ansible ceph_nodes -m command -a "/usr/local/bin/cephadm version"
```

預期結果：

- 六台都有 Docker 與 cephadm
- 三台 MON 節點可執行 `ceph` CLI
- cephadm 管理節點可 SSH 到 dc1 六台節點

