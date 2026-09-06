---
title: Phase 0 IaC / Bicep
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_exclude: true
permalink: /kubernetes/3node-kubevirt/iac/
---

# Phase 0 IaC / Bicep

這個目錄用來放 Phase 0 Option B 的 Azure IaC / Bicep 模板、參數檔與部署指令。

> 目前狀態：Bicep 已開始實作，目錄中已有第一版 `main.bicep`、`main.bicepparam` 與 `modules/` 結構。若後續 Bicep 有明顯更新，這裡的狀態也要一起同步更新。

> 預設映像已改為 Canonical Ubuntu Jammy 22.04；`main.bicep` / `main.bicepparam` 現在直接使用 `japaneast` 可部署的 image reference，因此可不覆寫映像參數直接執行部署或 what-if。

## 資源命名

所有 Azure 資源使用 `mansion_kubevirt` prefix：

| 資源類型 | 名稱 |
|---------|------|
| Resource Group | `mansion_kubevirt_resource` |
| VNet | `mansion_kubevirt_vnet` |
| Node subnet | `mansion_kubevirt_node_subnet` (10.10.10.0/24) |
| VM overlay subnet | `mansion_kubevirt_vm_subnet` (10.10.100.0/24) |
| Ceph subnet (保留) | `mansion_kubevirt_ceph_subnet` (172.10.10.0/24) |
| NSG | `mansion_kubevirt_nsg` |
| Master VM | `mansion_kubevirt_master` (10.10.10.11) |
| Infra VM | `mansion_kubevirt_infra` (10.10.10.12) |
| Worker VM | `mansion_kubevirt_worker` (10.10.10.13) |
| Worker NIC2 | `mansion_kubevirt_worker_nic2` (10.10.100.13) |

> **注意：** ARM / Bicep 無法原地更名既有 Azure 資源。若環境中已存在舊命名資源（例如早期 `mansion-k8s-*`），請視為全新部署（fresh deploy），手動刪除舊資源後再重新部署。

---

## 共用 VNet 設計

此 Bicep 模板部署 `mansion_kubevirt_vnet`（`10.10.0.0/16` + `172.10.0.0/16`），並在重建時建立 `mansion_kubevirt_vm_subnet` 供 worker 第二張 NIC 使用：

| 子網 | CIDR | 用途 |
|------|------|------|
| `mansion_kubevirt_node_subnet` | `10.10.10.0/24` | K8s 節點（master .11, infra .12, worker .13） |
| `mansion_kubevirt_vm_subnet` | `10.10.100.0/24` | KubeVirt VM overlay（Worker eth1 專用） |
| `mansion_kubevirt_ceph_subnet` | `172.10.10.0/24` | 保留在 VNet inline subnets，避免 ARM PUT 在 KubeVirt 重部署時刪除此子網 |

> **ARM PUT 語義說明**：ARM 對 VNet 的 PUT 語義會取代整個 subnets 集合。`mansion_kubevirt_ceph_subnet` 仍需在 `modules/network.bicep` inline subnets 中保留；`mansion_kubevirt_vm_subnet` 則由 `main.bicep` 在重建時建立。

## FAQ

### 沒有 IaC / Bicep，也可以直接透過 Azure MCP 建立 Azure resource 嗎？如果可以，為什麼還需要 Bicep？

可以。只要 Azure 權限足夠，就能直接透過 Azure MCP 建立 VM、VNet、Subnet、NSG、Public IP、NIC 等資源。

但 Bicep 仍然很重要，因為它把基礎設施定義成可重複部署、可版控、可 review、可預覽變更的宣告式配置。對這個目錄來說，Bicep 的價值不只是「把資源建出來」，而是把已確認的 Azure 架構保存成之後可以重建、調整、比對的正式定義。

| 方式 | 比較像 | 強項 | 弱點 |
| --- | --- | --- | --- |
| **Azure MCP 直接建資源** | 即時操作 / imperative | 快、適合探索、臨時調整、查現況 | 容易變成手動流程，不好重現，不好 code review |
| **Bicep / IaC** | 宣告式 desired state | 可重複部署、一致性高、可版控、可 review、可預覽變更 | 前期要先把規格寫成 code |

一句話來說：Azure MCP 適合即時操作與驗證想法，Bicep 適合把環境正式定義下來，讓後續維護更穩定。


## 目前目錄內容

- [`main.bicep`](/kubernetes/3node-kubevirt/iac/main.bicep) : 主模板，負責串接 network、nsg、nic、vm 等模組。
- [`main.bicepparam`](/kubernetes/3node-kubevirt/iac/main.bicepparam) : 參數檔，集中放置區域、命名、網段、VM 規格等預設值。
- [`modules/network.bicep`](/kubernetes/3node-kubevirt/iac/modules/network.bicep) : 建立 VNet 與子網路。
- [`modules/nsg.bicep`](/kubernetes/3node-kubevirt/iac/modules/nsg.bicep) : 定義 Phase 0 所需的 NSG 規則。
- [`modules/nic.bicep`](/kubernetes/3node-kubevirt/iac/modules/nic.bicep) : 建立 NIC、Public IP 與 worker 的第二張網卡設定。
- [`modules/vm.bicep`](/kubernetes/3node-kubevirt/iac/modules/vm.bicep) : 建立 Ubuntu VM 並掛載對應網卡。

## SSH 連線提醒

- 目前 Phase 0 VM 的管理帳號是 `ubuntu`
- 連線格式：`ssh ubuntu@<public-ip>`
- 若要明確指定金鑰：`ssh -i ~/.ssh/id_ed25519 ubuntu@<public-ip>`
