---
title: Spec
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 10
permalink: /kubernetes/3node-multipass/spec/
---

# 3node-multipass Spec

## 1) Scope & Goal

- 目標：在 Mac Mini M4 本機用 Multipass 建立 3 節點純 K8s Lab（不含 KubeVirt）。
- 範圍：K8s 核心元件、基礎設施服務（監控/日誌）、簡易應用部署驗證。

## 2) Target Architecture

### 2.1 節點與網段

| Node | vCPU / RAM / Disk | IP | 角色 |
|---|---|---|---|
| k8s-master | 2 / 3GB / 30GB | 192.168.50.201/24 | control plane |
| k8s-infra | 2 / 3GB / 30GB | 192.168.50.202/24 | infra services |
| k8s-worker | 2 / 3GB / 30GB+ | 192.168.50.203/24 | app workload |

- 橋接網路：`en0`（192.168.50.x/24）
- Pod CIDR：`172.46.0.0/16`
- Service CIDR：`10.96.0.0/12`

### 2.2 主要軟體版本

- Kubernetes：`v1.31`
- Container runtime：`CRI-O`
- CNI：`Cilium`

## 3) Naming Convention

- VM 命名：`k8s-master` / `k8s-infra` / `k8s-worker`
- 文件內步驟命名統一採 `Step.0` ~ `Step.6`

## 4) Execution Guardrails

1. 本子題為本機 Multipass，避免混入 Azure/KubeVirt 專屬設定。
2. 靜態 IP 設定需與 spec 一致（`.201~.203`）。
3. `buildup.md` 與 `commands.md` 步驟需保持對齊。

## 5) Agent Bootstrap（新 agent 開局必讀）

1. 先讀：`kubernetes/spec.md`（總綱）
2. 再讀：`kubernetes/3node-multipass/buildup.md`
3. 再讀：`kubernetes/3node-multipass/commands.md`
4. 最後確認 Step.0~6 是否有版本漂移（k8s/cri-o/cilium 參數）

## 6) Current Status Snapshot

- 已有 Step.0~Step.6 完整導覽。
- 文件已記錄關鍵修正（CRI-O 路徑、靜態 IP、Cilium 參數）。
- 可作為純 K8s 基礎操作與教學基線。

## 7) Definition of Done

1. 三節點可正常加入叢集。
2. CNI/監控/日誌元件可正常運行。
3. Worker 上可成功部署並對外驗證簡易 Web App。
4. 文件步驟與實際操作一致。
