---
title: 3-Node Ceph (Azure)
parent: Storage
has_children: true
permalink: /storage/3node-ceph/
---

# Ceph 3-Node Cluster on Azure

這份筆記已改為 **phase 導覽式結構**。如果你要完整從 Azure 建到 Ceph RBD pool 與可觀測性，請依序閱讀 `Phase 0` 到 `Phase 5`；如果你要查整體設計或指令，請直接跳到下方參考文件。

## Build Agenda

| Phase | 主題 | 說明 |
|------|------|------|
| [Phase 0](phase-0/) | Azure 資源建立 | Azure MCP + Bicep 建立 Azure 網路、NSG、6 台 dc1 baseline VM 與 managed disk |
| [Phase 1](phase-1/) | OS 與磁碟準備 | Hostname、hosts、網路驗證與磁碟檢查 |
| [Phase 2](phase-2/) | Ceph v19.2.2 安裝 | Docker、cephadm、SSH key 與環境準備 |
| [Phase 3](phase-3/) | Cluster bootstrap | Bootstrap、加入節點、部署 MON/MGR/OSD |
| [Phase 4](phase-4/) | RBD pool 設定 | 建立 RBD pool 與 replication 參數設定 |
| [Phase 5](phase-5/) | Observability / Log shipping | ceph-exporter、node-exporter、fluent-bit 串接 Prometheus/OpenSearch |

## Reading Guide

1. 第一次建置：從 `Phase 0` 讀到 `Phase 5`
2. 查指令與設計：參考下方文件

## Ansible Automation

Phase 1 到 Phase 5 的主執行入口現在都放在：

```text
storage/3node-ceph/ansible/
```

在 Mac mini 上的最短操作路徑：

```bash
cd storage/3node-ceph/ansible

ansible-inventory --graph
ansible-playbook playbooks/phase-1.yml
ansible-playbook playbooks/phase-2.yml
ansible-playbook playbooks/phase-3.yml
ansible-playbook playbooks/phase-4.yml
ansible-playbook playbooks/phase-5.yml
```

如果要一次跑完 Phase 1-5：

```bash
ansible-playbook playbooks/site.yml
```

各 phase playbook 實際會做的系統變更（摘要）：

| Phase | 主要系統變更 |
|------|------|
| Phase 1 | 安裝 baseline 套件（`curl`、`wget`、`net-tools`、`vim`、`htop`、`lsof`、`chrony`、`netcat-openbsd`）、設定 hostname 與 `/etc/hosts`、啟用 `chrony`、關閉 `ufw`（若啟用中）、清除 OSD 磁碟簽章（`wipefs`） |
| Phase 2 | 安裝 Ceph 前置套件、安裝並啟動 Docker、下載 `cephadm`、在 MON 節點安裝 `ceph-common`、停用 swap（含 `/etc/fstab`）、寫入 Ceph sysctl、配置 cephadm SSH 免密 |
| Phase 3 | 在第一台 MON 執行 `cephadm bootstrap`（首次）、同步 `ceph.conf`/admin keyring 到所有 MON、設定 `public_network`/`cluster_network`、加入 orchestrator hosts、部署 MON/MGR/OSD、建立/調整 CRUSH 拓撲與 replicated rule |
| Phase 4 | 建立 `k8s_rbd_pool`（若不存在）、設定 `size/min_size/crush_rule/pg_autoscale_mode`、啟用 RBD application、初始化 pool、建立測試 image |
| Phase 5 | 安裝並啟動 `prometheus-node-exporter`、部署 `fluent-bit` 設定與 systemd unit、部署 `prometheus-agent` 與 `ceph-exporter`（MON 節點）、啟用相關服務開機自啟 |

Ansible 目錄內的重要結構：

- `inventory/hosts` — host groups + per-node public/cluster IP mapping
- `inventory/group_vars/all/all.yml` — shared Ceph and lab settings
- `playbooks/phase-1.yml` ~ `phase-5.yml` — one playbook per phase
- `roles/` — one primary role per phase

每次重新建立 Azure VM 之後，記得先更新：

- `inventory/hosts` 內的 `ansible_host`
- 每台節點的 `ceph_osd_devices`

## Reference Docs

- [Architecture](architecture/) — 架構設計與網路配置
- [Commands](commands/) — 指令快速查詢
- [Flowchart](flowchart/) — 建置流程圖
- [Buildup Guide](buildup/) — Phase 導覽總覽
