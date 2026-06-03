---
title: Spec
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 10
permalink: /storage/3node-ceph/spec/
---

# 3node-ceph Spec

最後更新：2026-06-03

## 1. Goal

在 Azure 建立 **dc1 baseline Ceph cluster**（3 MON + 3 OSD，共 6 台 VM），作為後續跨機房遷移（dc2 擴展）的基礎。

## 2. Azure / Resource Convention

1. Resource Group: `mansion_ceph_resource`
2. 資源命名前綴：`mansion-ceph-`
3. 共用資源放在：`mansion-shared-resource`

## 3. VM and Network Baseline (dc1 only)

1. 節點數：6 台 Ubuntu 22.04（3 MON + 3 OSD）
2. 管理帳號：`ubuntu`（SSH key，無密碼登入）
3. Runtime：目前使用 Docker（未來可評估 Podman）
4. 公網/管理網段：`10.10.10.0/24`
5. Ceph cluster 私網：`172.10.10.0/24`

節點規格：

| Node | Role | VM Size | OS IP | Cluster IP | Disk |
|---|---|---|---|---|---|
| mon-dc1-01 | MON | Standard_D2s_v4 | 10.10.10.21/24 | 172.10.10.21/24 | 1x64G OS |
| mon-dc1-02 | MON | Standard_D2s_v4 | 10.10.10.22/24 | 172.10.10.22/24 | 1x64G OS |
| mon-dc1-03 | MON | Standard_D2s_v4 | 10.10.10.23/24 | 172.10.10.23/24 | 1x64G OS |
| osd-dc1-01 | OSD | Standard_D2s_v4 | 10.10.10.24/24 | 172.10.10.24/24 | 1x64G OS + 2x64G OSD |
| osd-dc1-02 | OSD | Standard_D2s_v4 | 10.10.10.25/24 | 172.10.10.25/24 | 1x64G OS + 2x64G OSD |
| osd-dc1-03 | OSD | Standard_D2s_v4 | 10.10.10.26/24 | 172.10.10.26/24 | 1x64G OS + 2x64G OSD |

Topology labels：

1. MON 節點：`datacenter=dc1, room=r1, rack=m1/m2/m3`
2. OSD 節點：`datacenter=dc1, room=r1, rack=o1/o2/o3`

## 4. Ceph Baseline

1. Ceph version: `v19.2.2`
2. 所有 MON 節點需可直接執行 `ceph -s`
3. RBD pool: `k8s_rbd_pool`
4. Pool target: `size=3, min_size=1, pg_num=128, pgp_num=128`
5. CRUSH 依 location labels，failure domain 使用 `rack`

## 5. Observability and Logging

1. 安裝 `ceph-exporter` + `ceph-node-exporter`，推送至 Kubernetes 專案中的 Prometheus
2. 安裝 `fluent-bit`，推送至 Kubernetes 專案中的 OpenSearch

## 6. Automation (Ansible)

1. 安裝流程使用 Ansible playbooks 自動化
2. 依 phase 拆 role（Phase 0~5）
3. inventory 採 YAML，至少區分 `ceph_mon` / `ceph_osd` 群組
4. `group_vars`：
   - `all.yml`: 明碼變數
   - `encrypted.yml`: ansible-vault 加密變數（secret）

## 7. Sizing Note (D2s_v4)

目前 baseline 使用 `Standard_D2s_v4`（MON/OSD 同規格）。  
此配置適合 lab 與流程驗證；若 recovery/backfill 期間 OSD 延遲過高，優先升級 OSD 節點規格。
