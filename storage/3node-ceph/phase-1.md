---
title: Phase 1 - OS 準備
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 11
permalink: /storage/3node-ceph/phase-1/
---

# Phase 1 — OS 準備（dc1 baseline）

## 目標

從管理端透過 Ansible 完成 dc1 六台節點初始化（3 MON + 3 OSD），包含 hostname、hosts、網路與 OSD 磁碟驗證。

## 前置條件

- 已完成 [Phase 0](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-0/)
- inventory 已區分 `ceph_mon` 與 `ceph_osd`
- `ceph_osd_devices` 僅定義在 OSD 節點

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-inventory --graph
ansible-playbook playbooks/phase-1.yml
```

## 這個 Ansible 會修改哪些系統狀態

- 安裝 `ceph_phase1_packages` 定義的 baseline 套件（含 apt cache update）：`curl`、`wget`、`net-tools`、`vim`、`htop`、`lsof`、`chrony`、`netcat-openbsd`。
- 設定每台節點 hostname，並覆寫 `/etc/hosts`（由 `hosts.j2` 產生）。
- 啟用並啟動 `chrony` 服務。
- 若節點有啟用 UFW，會執行 `ufw --force disable` 關閉防火牆。
- 對 OSD 節點定義的 `ceph_osd_devices`，若偵測到既有檔案系統簽章，會執行 `wipefs --all --force` 清除簽章（破壞性操作）。

## 驗證方式

```bash
ansible ceph_mon -m command -a hostname
ansible ceph_osd -m command -a hostname
ansible ceph_nodes -m command -a "ip addr show"
ansible ceph_osd -m command -a "lsblk"
```

預期結果：

- 6 台節點 hostname / IP 正確
- MON / OSD 分組正確
- OSD 節點的 `ceph_osd_devices` 均存在且未被使用
