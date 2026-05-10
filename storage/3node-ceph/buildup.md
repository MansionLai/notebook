---
title: Buildup Guide
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 2
permalink: /storage/3node-ceph/buildup/
---

# Ceph 3-Node on Azure — Buildup Guide

> 這份文件已改為 **phase 導覽模式**。完整步驟請改從 `Phase 0` 到 `Phase 4` 閱讀。

## Phase Navigation

| Phase | 連結 | 說明 |
|------|------|------|
| Phase 0 | [Azure 資源建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-0/) | Azure VM、VNet、NSG、雙 NIC、三磁碟；僅單一選項 |
| Phase 1 | [OS 準備](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-1/) | SSH、hostname、/etc/hosts、NIC 與磁碟驗證 |
| Phase 2 | [Ceph 安裝](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-2/) | 安裝 Ceph v19.2.2 並驗證版本 |
| Phase 3 | [Cluster 建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-3/) | bootstrap、加入節點、MON/MGR/OSD 部署 |
| Phase 4 | [RBD Pool 建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-4/) | 建立 rbdpool、設定參數與驗證 |

## Reference Docs

- [Architecture](https://mansionlai.github.io/notebook/storage/3node-ceph/architecture/)
- [Commands](https://mansionlai.github.io/notebook/storage/3node-ceph/commands/)
- [Setup Flowchart](https://mansionlai.github.io/notebook/storage/3node-ceph/flowchart/)
- [Project Agenda](https://mansionlai.github.io/notebook/storage/3node-ceph/)
