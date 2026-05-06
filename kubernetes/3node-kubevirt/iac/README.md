---
title: Phase 0 IaC / Bicep
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_exclude: true
permalink: /kubernetes/3node-kubevirt/iac/
---

# Phase 0 IaC / Bicep

這個目錄保留給 Phase 0 Option B 使用的 Azure IaC / Bicep 模板、參數檔與部署指令。

> 目前狀態：Phase 0 Bicep 實作完成，所有 VM NIC 皆共用 `k8s-nsg`，worker 第二張 NIC 也同樣套用此 NSG。

## 目前可先閱讀

- [KubeVirt Phase 0 Option B Bicep Design Spec](https://github.com/MansionLai/notebook/blob/main/docs/superpowers/specs/2026-05-05-kubevirt-phase0-optionb-bicep-design.md)

## 後續預計會放在這裡的內容

- `main.bicep`
- `main.bicepparam`
- `modules/`
- deployment instructions

## 部署前準備

1. 確認已登入 Azure CLI 並選好 subscription。
2. 確認目標 Resource Group 已存在。
3. 準備 SSH public key，例如：

```bash
cat ~/.ssh/id_ed25519.pub
```

## 部署

```bash
az deployment group create \
  --resource-group mansion_resource \
  --template-file main.bicep \
  --parameters @main.bicepparam \
  --parameters adminPublicKey="$(cat ~/.ssh/id_ed25519.pub)"
```

> `allowedSourceCidr` 請先改成你自己的固定 Public IP / CIDR。
