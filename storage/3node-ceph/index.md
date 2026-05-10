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
| [Phase 0](phase-0/) | Azure 資源建立 | Azure 網路、NSG、3 台 VM 與 managed disk |
| [Phase 1](phase-1/) | OS 與磁碟準備 | Hostname、hosts、網路驗證與磁碟檢查 |
| [Phase 2](phase-2/) | Ceph v19.2.2 安裝 | Docker、cephadm、SSH key 與環境準備 |
| [Phase 3](phase-3/) | Cluster bootstrap | Bootstrap、加入節點、部署 MON/MGR/OSD |
| [Phase 4](phase-4/) | RBD pool 設定 | 建立 RBD pool 與 replication 參數設定 |

## Reading Guide

1. 第一次建置：從 `Phase 0` 讀到 `Phase 4`
2. 查指令與設計：參考下方文件

## Reference Docs

- [Architecture](architecture/) — 架構設計與網路配置
- [Commands](commands/) — 指令快速查詢
- [Flowchart](flowchart/) — 建置流程圖
- [Buildup Guide](buildup/) — Phase 導覽總覽
