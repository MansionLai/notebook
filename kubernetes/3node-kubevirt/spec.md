---
title: Spec
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 10
permalink: /kubernetes/3node-kubevirt/spec/
---

# 3node-kubevirt Spec

## 1) Scope & Goal

- 目標：在 Azure 建立 3 節點 K8s + KubeVirt Lab，供安裝、驗證與 runbook 演練。
- 範圍：Infra 建置、K8s 基礎元件、Rook-Ceph 外部儲存整合、Observability、KubeVirt 平台層與 VM workload。

## 2) Target Architecture

### 2.1 節點與網段

| Node | Size | OS IP | 角色 |
|---|---|---|---|
| master | Standard_D2s_v4 | 10.10.10.11/24 | K8s control plane |
| infra | Standard_D4s_v4 | 10.10.10.12/24 | infra services + KubeVirt control plane |
| worker | Standard_D4s_v4 | 10.10.10.13/24 | workload + virt-handler/virt-launcher |

- OS 網段：`10.10.10.0/24`
- KubeVirt VM 網段（worker 第 2 張 NIC / Multus）：`10.10.100.0/24`
- VM 帳號：`ubuntu`（SSH key only，無密碼）

### 2.2 主要軟體版本

- Kubernetes：`v1.31`
- Container runtime：`CRI-O`
- CNI：`Cilium`（Pod CIDR `172.46.0.0/16`）
- Rook-Ceph：`v1.17`（外部 Ceph cluster）
- KubeVirt：`v1.5.0`

## 3) Naming Convention

- 主要 RG：`mansion_kubevirt_resource`（IaC 實際名稱）
- 共用 RG：`mansion-shared-resource`
- 共用 VNet：`mansion-shared-vnet`
- 資源命名前綴：`mansion_kubevirt_`（依現行 IaC）

## 4) Execution Guardrails

1. Azure 操作優先使用 Azure MCP。
2. 文件與 IaC 變更需保持一致（`main.bicep` 與 `main.json` 不可漂移）。
3. 涉及部署驗證時，需確認 VM/NIC/PublicIP 與 deployment status。

## 5) Agent Bootstrap（新 agent 開局必讀）

1. 先讀：`kubernetes/spec.md`（總綱）
2. 再讀：`kubernetes/3node-kubevirt/buildup.md`
3. 再讀：`kubernetes/3node-kubevirt/phase-0.md` ~ `phase-6.md`
4. 再讀：`kubernetes/3node-kubevirt/iac/main.bicep`、`main.bicepparam`、`main.json`
5. 最後確認目前 Azure 資源狀態（VM/網路/部署狀態）

## 6) Current Status Snapshot

- 已有完整 Phase 0~6 導覽。
- 文件包含常見故障補充（Ceph CSI 排程、KubeVirt selector/affinity、VMI network 問題等）。
- 重建流程已可透過 Azure MCP 執行（需注意 template 與參數一致性）。

## 7) Definition of Done

一輪完整驗證需滿足：
1. 3 台 VM 建立成功且可連線。
2. 核心安裝流程可跑完（Phase 1~5）。
3. 儲存與觀測元件狀態健康。
4. 文件與實際操作結果一致。
