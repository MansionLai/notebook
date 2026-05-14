---
title: 3-Node Ceph (Azure)
parent: Storage
has_children: true
permalink: /storage/3node-ceph/
---

# Ceph 3-Node Cluster on Azure

這份筆記已改為 **phase 導覽式結構**。如果你要完整從 Azure 建到 Ceph RBD pool，請依序閱讀 `Phase 0` 到 `Phase 4`；如果你要查整體設計或指令，請直接跳到下方參考文件。

## Build Agenda

| Phase | 主題 | 說明 |
|------|------|------|
| [Phase 0](phase-0/) | Azure 資源建立 | Azure MCP + Bicep 建立 Azure 網路、NSG、3 台 VM 與 managed disk |
| [Phase 1](phase-1/) | OS 與磁碟準備 | Hostname、hosts、網路驗證與磁碟檢查 |
| [Phase 2](phase-2/) | Ceph v19.2.2 安裝 | Docker、cephadm、SSH key 與環境準備 |
| [Phase 3](phase-3/) | Cluster bootstrap | Bootstrap、加入節點、部署 MON/MGR/OSD |
| [Phase 4](phase-4/) | RBD pool 設定 | 建立 RBD pool 與 replication 參數設定 |

## Reading Guide

1. 第一次建置：從 `Phase 0` 讀到 `Phase 4`
2. 查指令與設計：參考下方文件

## Ansible Automation

Phase 1 到 Phase 4 的主執行入口現在都放在：

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
```

如果要一次跑完 Phase 1-4：

```bash
ansible-playbook playbooks/site.yml
```

Ansible 目錄內的重要結構：

- `inventory/hosts.yml` — host groups
- `group_vars/all.yml` — shared Ceph and lab settings
- `host_vars/*.yml` — per-node public/cluster IP mapping
- `playbooks/phase-1.yml` ~ `phase-4.yml` — one playbook per phase
- `roles/` — one primary role per phase

每次重新建立 Azure VM 之後，記得先更新：

- `host_vars/*.yml` 內的 `ansible_host`
- 每台節點的 `ceph_osd_devices`

## Reference Docs

- [Architecture](architecture/) — 架構設計與網路配置
- [Commands](commands/) — 指令快速查詢
- [Flowchart](flowchart/) — 建置流程圖
- [Buildup Guide](buildup/) — Phase 導覽總覽
