---
title: Phase 0 IaC / Bicep
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_exclude: true
permalink: /kubernetes/3node-kubevirt/iac/
---

# Phase 0 IaC / Bicep

這個目錄保留給 Phase 0 Option B 使用的 Azure IaC / Bicep 模板、參數檔與部署指令。

> 目前狀態：設計 / spec 已完成，Bicep 實作尚未開始。

## FAQ

### 沒有 IaC / Bicep，也可以直接透過 Azure MCP 建立 Azure resource 嗎？如果可以，為什麼還需要 Bicep？

可以。只要 Azure 權限足夠，就能直接透過 Azure MCP 建立 VM、VNet、Subnet、NSG、Public IP、NIC 等資源。

但 Bicep 仍然很重要，因為它把基礎設施定義成可重複部署、可版控、可 review、可預覽變更的宣告式配置。對這個目錄來說，Bicep 的價值不只是「把資源建出來」，而是把已確認的 Azure 架構保存成之後可以重建、調整、比對的正式定義。

一句話來說：Azure MCP 適合即時操作與驗證想法，Bicep 適合把環境正式定義下來，讓後續維護更穩定。

## 目前可先閱讀

- [KubeVirt Phase 0 Option B Bicep Design Spec](https://github.com/MansionLai/notebook/blob/main/docs/superpowers/specs/2026-05-05-kubevirt-phase0-optionb-bicep-design.md)

## 後續預計會放在這裡的內容

- `main.bicep`
- `main.bicepparam`
- `modules/`
- deployment instructions
