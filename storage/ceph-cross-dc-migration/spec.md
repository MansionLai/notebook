---
title: Spec
parent: Ceph Cross-DC Migration
nav_order: 10
permalink: /storage/ceph-cross-dc-migration/spec/
---

# ceph-cross-dc-migration Spec

最後更新：2026-06-03

## 1. Goal

在既有 **dc1 baseline Ceph cluster**（3 MON + 3 OSD）之上，新增 dc2（3 MON + 3 OSD），完成跨機房遷移演練與角色切換。

## 2. Scenario Baseline

1. 現況（dc1 baseline）：3 MON + 3 OSD nodes（共 6 VM）
2. 目標（dc2 expansion）：新增 3 MON + 3 OSD nodes（再加 6 VM）
3. 最終拓撲：dc1 + dc2 共 12 VM
4. 網路：dc1 與 dc2 為可互通環境（stretched L2 或等效可達）
5. 主要 workload：RBD pool 服務 KubeVirt VM

## 3. Responsibility Boundary

1. `storage/3node-ceph/phase-0~5`：只負責 dc1 baseline 建置
2. `storage/ceph-cross-dc-migration/*`：負責 dc2 節點加入、OSD migration、MON migration

## 4. Topology Metadata Baseline

1. dc1 / room r1 / racks：`m1,m2,m3,o1,o2,o3`
2. dc2 / room r2 / racks：`m4,m5,m6,o4,o5,o6`

## 5. Migration Principles

1. 先擴展（add dc2）再收斂（remove dc1）
2. OSD migration 先於 MON migration
3. 每個階段都要有健康檢查 gate（`ceph -s`, PG state, VM I/O）
4. 保留 rollback / stop gate

## 6. Required Deliverables

1. dc2 節點加入規劃（3 MON + 3 OSD）
2. OSD migration runbook（依批次遷移）
3. MON migration runbook（quorum 與 client endpoint 協調）
4. 驗證清單（Ceph health、PG state、RBD I/O、KubeVirt）

## 7. Source Documents

1. `storage/ceph-cross-dc-migration/index.md`
2. `storage/ceph-cross-dc-migration/solutions.md`
3. `storage/ceph-cross-dc-migration/osd-migration.md`
4. `storage/ceph-cross-dc-migration/mon-migration.md`
