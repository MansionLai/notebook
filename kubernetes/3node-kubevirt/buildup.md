---
title: Buildup Guide
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 2
permalink: /kubernetes/3node-kubevirt/buildup/
---

# K8s 3-Node KubeVirt on Azure — Buildup Guide

> 這份文件已改為 **phase 導覽模式**。完整步驟請改從 `Phase 0` 到 `Phase 6` 閱讀。

## Phase Navigation

| Phase | 連結 | 說明 |
|------|------|------|
| Phase 0 | [Azure 資源建立](../phase-0/) | Azure VM、VNet、NSG、Worker 第 2 張 NIC；含 Option A / Option B |
| Phase 1 | [OS 基礎 + kubeadm + Cilium](../phase-1/) | 主機初始化與叢集建立 |
| Phase 2 | [Multus CNI](../phase-2/) | Multus 安裝與驗證 |
| Phase 3 | [Storage + Ingress](../phase-3/) | local-path-provisioner、MetalLB、Istio |
| Phase 4 | [Observability](../phase-4/) | Prometheus、OpenSearch、Dashboards、Fluent Bit |
| Phase 5 | [KubeVirt 平台層](../phase-5/) | KubeVirt、NAD、network policy |
| Phase 6 | [VM Workload](../phase-6/) | ub24-01 VM 建立與外網連線 |

## Reference Docs

- [Architecture](../architecture/)
- [Commands](../commands/)
- [Setup Flowchart](../flowchart/)
- [Project Agenda](../)
