---
title: Spec
parent: Ceph Cross-DC Migration
nav_order: 10
permalink: /storage/ceph-cross-dc-migration/spec/
---

# ceph-cross-dc-migration Spec

最後更新：2026-05-22

## 1. Goal

將既有 Ceph cluster 從 dc1 擴展至 dc2，透過 CRUSH 與分批遷移，完成資料與服務重心轉移，最後可安全退場 dc1。

## 2. Scenario Baseline

1. 現況（dc1）：3 MON + 15 OSD nodes（每台 10 顆 OSD disks）
2. 目標（dc2）：3 MON + 15 OSD nodes（每台 10 顆 OSD disks）
3. 網路：dc1 與 dc2 之間為 stretched Layer 2，使用同一 IP segment
4. 主要 workload：RBD pool 服務 KubeVirt VM

## 3. Topology Metadata Baseline

1. dc1 / room r1 / racks：m1,m2,m3,o1,o2,o3
2. dc2 / room r2 / racks：m4,m5,m6,o4,o5,o6

## 4. Migration Principles

1. 優先 OSD，後 MON
2. 以 rack 為單位分批遷移，降低 blast radius
3. 每批次需設定健康檢查 gate（recovery/backfill 完成、RBD workload 驗證）
4. 全程保留回復方案（rollback / stop gate）

## 5. Required Deliverables

1. 遷移策略比較與決策說明（Option A/B）
2. OSD migration runbook（rack-by-rack）
3. MON migration runbook（quorum / external mode 協調）
4. 驗證清單（Ceph health、PG state、RBD I/O、KubeVirt）

## 6. Source Documents

1. `storage/ceph-cross-dc-migration/index.md`
2. `storage/ceph-cross-dc-migration/solutions.md`
3. `storage/ceph-cross-dc-migration/osd-migration.md`
4. `storage/ceph-cross-dc-migration/detail_runbook.md`

