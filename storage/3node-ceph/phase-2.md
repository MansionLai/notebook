---
title: Phase 2 - Ceph 安裝
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 12
permalink: /storage/3node-ceph/phase-2/
---

# Phase 2 — Ceph 安裝

## 目標

從 Mac mini 透過 Ansible 完成 Ceph 先決條件配置：container runtime、cephadm、admin node 的 `ceph-common`、swap 關閉、sysctl 調整，以及 cephadm 需要的無密碼 SSH。

---

## 前置條件

- 已完成 [Phase 1](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-1/)
- 三台節點可從 Mac mini 用 Ansible 連線
- `storage/3node-ceph/ansible/group_vars/all.yml` 已確認：
  - `ceph_version`
  - `ceph_cephadm_url`
  - `ceph_dashboard_password`

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-2.yml
```

---

## 這個 Phase 的 role 會做什麼

- 安裝 `docker.io`、`lvm2`、Python 相關先決條件
- 啟動並設為開機自動啟動 Docker
- 下載 `cephadm`
- 在 `ceph-node-01` 安裝 `ceph-common`
- 關閉 swap 並註解 `/etc/fstab` 內的 swap entry
- 寫入 Ceph lab 用 sysctl 設定
- 在 `ceph-node-01` 建立 cephadm SSH key
- 將 public key 發佈到三台節點的 `ubuntu` 使用者
- 驗證 `ceph-node-01` 能無密碼 SSH 到三台節點

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-2.yml
storage/3node-ceph/ansible/roles/phase2_ceph_prereqs/
```

---

## 驗證方式

```bash
cd storage/3node-ceph/ansible

ansible ceph_nodes -m command -a "docker --version"
ansible ceph_nodes -m command -a "systemctl is-active docker"
ansible ceph_nodes -m command -a "/usr/local/bin/cephadm version"
ansible ceph_admin -m command -a "ceph --version"
ansible ceph_nodes -m command -a "free -h"

ssh ubuntu@<ceph-node-01-public-ip> "ssh -o BatchMode=yes ceph-node-02 hostname"
ssh ubuntu@<ceph-node-01-public-ip> "ssh -o BatchMode=yes ceph-node-03 hostname"
```

預期結果：

- 三台都有 Docker 與 cephadm
- `ceph-node-01` 有 `ceph` CLI
- `Swap` 顯示為 0
- `ceph-node-01` 可無密碼 SSH 到其他兩台

---

## Troubleshooting

- `docker: command not found`：先確認 apt repo 可用且 `docker.io` 套件安裝成功
- `cephadm install ceph-common` 失敗：檢查 Ceph repo 是否已加到 admin node
- `Permission denied (publickey)`：檢查 `phase2_ceph_prereqs` 是否成功將 id_rsa.pub 發佈到全部節點
