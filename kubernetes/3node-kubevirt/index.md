---
title: 3-Node KubeVirt (Azure)
parent: Kubernetes
nav_order: 1
has_children: true
permalink: /kubernetes/3node-kubevirt/
---

# K8s 3-Node KubeVirt on Azure

這份筆記已改為 **phase 導覽式結構**。如果你要完整從 Azure 建到 KubeVirt VM，請依序閱讀 `Phase 0` 到 `Phase 6`；如果你要查整體設計或指令，請直接跳到下方參考文件。

## Build Agenda

| Phase | 主題 | 說明 |
|------|------|------|
| [Phase 0](phase-0/) | Azure 資源建立 | Azure 網路、NSG、3 台 VM、Worker 第 2 張 NIC；同頁提供 Option A / Option B |
| [Phase 1](phase-1/) | OS 基礎 + kubeadm + Cilium | 主機初始化、container runtime、kubeadm、Cilium |
| [Phase 2](phase-2/) | Multus CNI | 安裝與驗證 Multus |
| [Phase 3](phase-3/) | Storage + Ingress | local-path-provisioner、MetalLB、Istio |
| [Phase 4](phase-4/) | Observability | Prometheus、OpenSearch、Dashboards、Fluent Bit |
| [Phase 5](phase-5/) | KubeVirt 平台層 | KubeVirt、NAD、network policy |
| [Phase 6](phase-6/) | VM workload | 建立 ub24-01 VM 與外網連線處理 |

## Reference Docs

| 文件 | 用途 |
|------|------|
| [Architecture](architecture/) | 架構決策、節點角色、資源分配 |
| [Commands](commands/) | 常用安裝與操作指令 |
| [Setup Flowchart](flowchart/) | 高層安裝流程圖 |
| [Buildup Guide](buildup/) | 過渡型總覽頁與 phase 導覽 |

## Reading Guide

1. 第一次建置：從 `Phase 0` 讀到 `Phase 6`
2. 查指令：看 `Commands`
3. 查設計與 sizing：看 `Architecture`
4. 看整體流程：看 `Setup Flowchart`
