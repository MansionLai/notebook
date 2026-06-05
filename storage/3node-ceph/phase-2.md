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

## 這個 Ansible 會修改哪些系統狀態

- 安裝 `ceph_phase2_packages` 前置套件，並確保 Docker 啟用且啟動。
- 下載 `cephadm` 到 `/usr/local/bin/cephadm`（`0755`）。
- 在 `ceph_mon` 節點（若尚未有 `ceph` CLI）新增 Ceph repo 並安裝 `ceph-common`。
- 停用 swap（`swapoff -a`），並把 `/etc/fstab` 內 swap entry 註解，避免重開後再啟用。
- 寫入 `/etc/sysctl.d/99-ceph-lab.conf` 並套用 `sysctl --system`。
- 在第一台 MON 產生 cephadm SSH key，將公鑰佈署到所有 Ceph 節點，並寫入管理端 SSH config 以支援免密連線。

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
