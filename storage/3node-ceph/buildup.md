---
title: Buildup Guide
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 2
permalink: /storage/3node-ceph/buildup/
---

# Ceph 3-Node on Azure — Buildup Guide

> 這份文件已改為 **phase 導覽模式**。完整步驟請改從 `Phase 0` 到 `Phase 5` 閱讀。

## Phase Navigation

| Phase | 連結 | 說明 |
|------|------|------|
| Phase 0 | [Azure 資源建立](/storage/3node-ceph/phase-0/) | Azure MCP + Bicep 建立 RG、NSG、雙 NIC、三磁碟 |
| Phase 1 | [OS 準備](/storage/3node-ceph/phase-1/) | 從 Mac mini 執行 Ansible 進行 OS baseline、hostname、hosts、NIC 與磁碟驗證 |
| Phase 2 | [Ceph 安裝](/storage/3node-ceph/phase-2/) | 從 Mac mini 執行 Ansible 安裝 Docker、cephadm、ceph-common、SSH 與 sysctl |
| Phase 3 | [Cluster 建立](/storage/3node-ceph/phase-3/) | 從 Mac mini 執行 Ansible 完成 bootstrap、host add、MON/MGR/OSD 建立 |
| Phase 4 | [RBD Pool 建立](/storage/3node-ceph/phase-4/) | 從 Mac mini 執行 Ansible 建立 k8s_rbd_pool 與 test image |
| Phase 5 | [Observability 與 Log Shipping](/storage/3node-ceph/phase-5/) | 安裝 ceph-exporter、node-exporter、fluent-bit，串接 Prometheus/OpenSearch |

## Ansible Entry Point

所有 Phase 1-5 的主執行路徑都改由：

```text
storage/3node-ceph/ansible/
```

在 Mac mini 上執行，例如：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/site.yml
```

## Reference Docs

- [Architecture](/storage/3node-ceph/architecture/)
- [Commands](/storage/3node-ceph/commands/)
- [Setup Flowchart](/storage/3node-ceph/flowchart/)
- [Project Agenda](/storage/3node-ceph/)
