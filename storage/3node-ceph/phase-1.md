---
title: Phase 1 - OS 準備
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 11
permalink: /storage/3node-ceph/phase-1/
---

# Phase 1 — OS 準備

## 目標

從 Mac mini 透過 Ansible 完成三台 Azure VM 的作業系統初始化，包括基礎套件、hostname、`/etc/hosts`、NIC/IP 驗證、OSD 磁碟檢查、chrony 與 lab 用防火牆設定。

---

## 前置條件

- 已完成 [Phase 0](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-0/)
- Mac mini 可用 SSH key 連到三台 VM
- 已準備好：
  - `storage/3node-ceph/ansible/inventory/hosts.yml`
  - `storage/3node-ceph/ansible/group_vars/all.yml`
  - `storage/3node-ceph/ansible/host_vars/ceph-node-0{1,2,3}.yml`
  - 每台節點的 `ceph_osd_devices` 已依實際 `lsblk` 結果填好

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-inventory --graph
ansible-playbook playbooks/phase-1.yml
```

---

## 這個 Phase 的 role 會做什麼

- 套用基礎套件：`curl`、`wget`、`net-tools`、`vim`、`htop`、`lsof`、`chrony`、`netcat-openbsd`
- 將 hostname 設為 `ceph-node-01` ~ `ceph-node-03`
- 以 template 管理 `/etc/hosts`
- 驗證每台節點都有對應的 public / cluster IP
- 驗證 inventory 內定義的 `ceph_osd_devices` 存在且仍為空白 OSD 磁碟
- 確保 `chrony` 啟用
- 在 lab 環境關閉 `ufw`

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-1.yml
storage/3node-ceph/ansible/roles/phase1_os_prep/
```

---

## 驗證方式

在 Mac mini 以 ad-hoc 或 SSH 驗證：

```bash
cd storage/3node-ceph/ansible

ansible ceph_nodes -m command -a hostname
ansible ceph_nodes -m command -a "grep ceph-node /etc/hosts"
ansible ceph_nodes -m command -a "ip addr show"
ansible ceph_nodes -m command -a "lsblk"
ansible ceph_nodes -m command -a "chronyc tracking"
ansible ceph_nodes -m command -a "ufw status"
```

預期結果：

- 三台節點 hostname 正確
- `/etc/hosts` 含 public / cluster 對照
- `10.10.10.x` 與 `172.10.10.x` 都存在於對應節點
- `ceph_osd_devices` 內指定的裝置存在且還沒被 Ceph 使用
- `chrony` 正常
- `ufw` 為 inactive 或 disabled

---

## Troubleshooting

- `Expected public IP ... was not found`：先回頭檢查 Phase 0 的 NIC / IP 以及 `host_vars/*.yml`
- `Expected <device> to be empty`：表示這台機器可能不是全新狀態，或 `ceph_osd_devices` 與實際 Azure disk mapping 不一致
- `Permission denied (publickey)`：先在 Mac mini 測試 `ssh ubuntu@<public-ip>`
