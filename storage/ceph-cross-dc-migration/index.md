---
title: Ceph Cross-DC Migration
parent: Storage
permalink: /storage/ceph-cross-dc-migration/
---

# Ceph Cross-DC Migration

跨資料中心 Ceph 遷移實戰筆記：從 dc1 線上 Ceph cluster 擴展至 dc2,透過 CRUSH 機制完成資料搬遷後再移除 dc1 節點。

---

## 1. Overview / Scenario

### 現況

- **dc1 現有 cluster**：3 台 MON、15 台 OSD nodes（每台 10 顆 OSD disks），現有 RBD pool 服務 KubeVirt 虛擬機
- **dc2 目標硬體**：3 台 MON、15 台 OSD nodes（每台 10 顆 OSD disks）
- **網路拓樸**：dc1 與 dc2 之間有 Layer 2 連通（stretched Layer 2），Server OS 與 Ceph private network 使用相同的 IP segment

### Topology Metadata

```text
datacenter dc1
└─ room r1
   ├─ rack m1 / m2 / m3
   └─ rack o1 / o2 / o3

datacenter dc2
└─ room r2
   ├─ rack m4 / m5 / m6
   └─ rack o4 / o5 / o6
```

---

## 2. Architecture Diagram

### CRUSH Tree + Cabinet View

```mermaid
graph LR
    subgraph META["Topology Metadata"]
        DC1["datacenter dc1"]
        R1["room r1"]
        M1["MON racks<br/>m1 / m2 / m3"]
        O1["OSD racks<br/>o1 / o2 / o3"]

        DC2["datacenter dc2"]
        R2["room r2"]
        M2["MON racks<br/>m4 / m5 / m6"]
        O2["OSD racks<br/>o4 / o5 / o6"]

        DC1 --> R1
        R1 --> M1
        R1 --> O1
        DC2 --> R2
        R2 --> M2
        R2 --> O2
    end

    subgraph CAB["Cabinet View"]
        subgraph C1["dc1 / room r1"]
            C1M["MON racks × 3"]
            C1O["OSD racks × 3<br/>15 nodes / 150 OSDs"]
        end

        subgraph C2["dc2 / room r2"]
            C2M["MON racks × 3"]
            C2O["OSD racks × 3<br/>15 nodes / 150 OSDs"]
        end
    end

    NET["Stretched Layer 2<br/>Same IP Segment"]
    RBD["RBD Pool<br/>for KubeVirt VMs"]

    M1 -.-> C1M
    O1 -.-> C1O
    M2 -.-> C2M
    O2 -.-> C2O

    C1O --- NET --- C2O
    C1O --> RBD
    C2O --> RBD

    classDef metaStyle fill:#e8f1ff,stroke:#3b82f6,stroke-width:1.5px
    classDef monStyle fill:#fff7db,stroke:#b7791f,stroke-width:1.5px
    classDef osdStyle fill:#e6ffed,stroke:#2f855a,stroke-width:1.5px
    classDef netStyle fill:#f2f2f2,stroke:#666,stroke-width:1px
    classDef rbdStyle fill:#e8edff,stroke:#4c51bf,stroke-width:1.5px

    class DC1,DC2,R1,R2 metaStyle
    class M1,M2,C1M,C2M monStyle
    class O1,O2,C1O,C2O osdStyle
    class NET netStyle
    class RBD rbdStyle
```

**圖說**：
- 左側以 `datacenter -> room -> rack` 呈現 topology metadata
- 右側以機櫃群視角呈現 dc1 / dc2 的 MON 與 OSD 分布
- 每個 DC 各有 3 個 MON racks 與 3 個 OSD racks，OSD 區合計 15 nodes / 150 OSDs
- 兩個 DC 透過 stretched Layer 2 網路連通，並共同提供 RBD 給 KubeVirt VM 使用
- 虛線箭頭表示拓樸 metadata 與機櫃視圖的對應關係，不代表資料流向

---

## 3. Reading Guide

本文件為跨資料中心 Ceph 遷移的主題入口。深入的解決方案分析與執行細節請參考：

### 📚 Solutions

深入探討遷移策略的比較與決策依據：

- **[Solutions Overview](solutions/)**
  - Option A vs Option B 比較
  - 設計取捨分析
  - 風險評估與緩解措施

### 📋 Runbooks

- **[MON Migration Runbook](detail_runbook/)**
  - quorum 重新定位 / monitor 拓樸變動
  - Rook external 模式協調
  - ceph-csi / KubeVirt 驗證步驟

- **[OSD Migration Runbook](osd-migration/)**
  - 以機櫃 (rack-by-rack) 為單位遷移
  - 觀察 recovery/backfill 進度並設定觀察門檻
  - RBD workload 影響評估與 gate criteria

---

## 相關參考

- [Ceph Official Documentation](https://docs.ceph.com/)
- [CRUSH Map Documentation](https://docs.ceph.com/en/latest/rados/operations/crush-map/)
- [cephadm Orchestrator](https://docs.ceph.com/en/latest/cephadm/)
