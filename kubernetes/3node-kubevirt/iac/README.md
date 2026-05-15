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

## 資源更名遷移說明（重要）

> ⚠️ **此次變更將 KubeVirt 預設資源名稱從舊版（`mansion-k8s-vnet` / `k8s-subnet`）更改為共用命名（`mansion-shared-vnet` / `shared-node-subnet`）。**
>
> ARM / Bicep **無法原地更名**既有的 Azure 資源（VNet、Subnet 名稱不支援 rename）。部署此版本 Bicep 時，ARM 將建立**全新**的資源，而非重命名舊資源。
>
> 若你的環境已存在舊版資源（`mansion-k8s-vnet`、`k8s-subnet`）：
> 1. 將此次部署視為**全新部署（fresh deploy）**，而非升級。
> 2. 遷移前需先將舊 VM / NIC 與舊 VNet 解除關聯（或刪除舊 VM），否則部署不會影響舊資源。
> 3. 舊資源（`mansion-k8s-vnet`、`k8s-subnet`）不會被自動刪除，需手動清除以避免混淆。
> 4. 所有後續 lab（Ceph 等）請以新名稱 `mansion-shared-vnet` / `shared-node-subnet` 為準。

---

## 共用 VNet 設計

此 Bicep 模板部署的 VNet（`mansion-shared-vnet`，`10.10.0.0/16` + `172.10.0.0/16`）是由 **KubeVirt lab 建立並擁有**的共用網路基礎設施：

| 子網 | CIDR | 用途 |
|------|------|------|
| `shared-node-subnet` | `10.10.10.0/24` | KubeVirt K8s 節點（`.10-.12`）；Ceph 節點未來使用（`.20-.22`） |
| `kubevirt-subnet` | `10.10.100.0/24` | KubeVirt VM overlay（Worker eth1 專用） |

VNet 宣告兩個 address prefix（`10.10.0.0/16` 與 `172.10.0.0/16`），確保 Ceph lab 稍後新增 `172.10.10.0/24`（Ceph 專屬 cluster subnet）時，不需要對既有 VNet 進行破壞性的 address space 變更。

Ceph lab 部署時將直接使用既有的 `mansion-shared-vnet` 與 `shared-node-subnet`，不需另建 VNet。

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

- [`main.bicep`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/main.bicep) : 主模板，負責串接 network、nsg、nic、vm 等模組。
- [`main.bicepparam`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/main.bicepparam) : 參數檔，集中放置區域、命名、網段、VM 規格等預設值。
- [`modules/network.bicep`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/modules/network.bicep) : 建立 VNet 與子網路。
- [`modules/nsg.bicep`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/modules/nsg.bicep) : 定義 Phase 0 所需的 NSG 規則。
- [`modules/nic.bicep`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/modules/nic.bicep) : 建立 NIC、Public IP 與 worker 的第二張網卡設定。
- [`modules/vm.bicep`](https://mansionlai.github.io/notebook/kubernetes/3node-kubevirt/iac/modules/vm.bicep) : 建立 Ubuntu VM 並掛載對應網卡。

## SSH 連線提醒

- 目前 Phase 0 VM 的管理帳號是 `ubuntu`
- 連線格式：`ssh ubuntu@<public-ip>`
- 若要明確指定金鑰：`ssh -i ~/.ssh/id_ed25519 ubuntu@<public-ip>`
