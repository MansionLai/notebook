---
title: Spec
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 10
permalink: /storage/3node-ceph/spec/
---

# 3node-ceph Spec

最後更新：2026-05-22

## 1. Goal

在 Azure 建立可重複部署的 3 節點 Ceph lab，供 Ceph 安裝、操作與 troubleshooting 學習，並保留可觀測性與自動化流程。

## 2. Azure / Resource Convention

1. Resource Group: `mansion_ceph_resource`
2. 資源命名前綴：`mansion-ceph-`
3. 共用資源放在：`mansion-shared-resource`

## 3. VM and Network Baseline

1. 節點數：3 台 Ubuntu 22.04
2. 每台角色：MON + MGR + OSD
3. 管理帳號：`ubuntu`（SSH key，無密碼登入）
4. Runtime：目前使用 Docker（未來可評估 Podman）
5. 公網/管理網段：`10.10.10.0/24`
6. Ceph cluster 私網：`172.10.10.0/24`

節點規格：

| Node | VM Size | OS IP | Cluster IP | Disk |
|---|---|---|---|---|
| ceph-1 | Standard_D4s_v4 | 10.10.10.21/24 | 172.10.10.21/24 | 1x64G OS + 2x64G OSD |
| ceph-2 | Standard_D4s_v4 | 10.10.10.22/24 | 172.10.10.22/24 | 1x64G OS + 2x64G OSD |
| ceph-3 | Standard_D4s_v4 | 10.10.10.23/24 | 172.10.10.23/24 | 1x64G OS + 2x64G OSD |

Topology labels：

1. ceph-1: `datacenter=dc1, room=room1, rack=rack1`
2. ceph-2: `datacenter=dc1, room=room1, rack=rack2`
3. ceph-3: `datacenter=dc1, room=room1, rack=rack3`

## 4. Ceph Baseline

1. Ceph version: `v19.2.2`
2. 所有 node 需可直接執行 `ceph -s`
3. RBD pool: `k8s_rbd_pool`
4. Pool target: `size=3, min_size=1, pg_num=128, pgp_num=128`
5. CRUSH 依 location labels，failure domain 使用 `rack`

## 5. Observability and Logging

1. 安裝 `ceph-exporter` + `ceph-node-exporter`，推送至 Kubernetes 專案中的 Prometheus
2. 安裝 `fluent-bit`，推送至 Kubernetes 專案中的 OpenSearch

## 6. Automation (Ansible)

1. 安裝流程使用 Ansible playbooks 自動化
2. 依 phase 拆 role（Phase 0~5）
3. inventory 採 YAML
4. `group_vars`：
   - `all.yml`: 明碼變數
   - `encrypted.yml`: ansible-vault 加密變數（secret）

## 7. Current Recognized State

1. Cluster health: `HEALTH_OK`
2. OSD count: `6`（osd.0 ~ osd.5）

