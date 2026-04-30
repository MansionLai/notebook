---
title: Option A Docs Realignment Design
parent: Specs
grand_parent: Superpowers
nav_order: 20260430
---

# Option A Docs Realignment Design

## Problem

`kubernetes/3node-kubevirt/` 目前多數操作文件仍以 **Option B** 為主，和現在要往 production 靠攏的方向不一致。需要把 `buildup.md`、`commands.md`、`flowchart.md` 全部改成 **Option A**，同時讓 `architecture.md` 改為 **Option A 為主體**，但保留 **Option B** 作為後續參考。

## Goal

完成後，整個 `kubernetes/3node-kubevirt/` 專案中的文件應有一致的預設部署模型：

1. `Option A` 是唯一的主要操作路徑。
2. `architecture.md` 仍保留 `Option B` 參考內容，但不再把它當成主方案。
3. 文件中的節點角色、Node label/taint、KubeVirt `infra/workloads` placement、流程圖、步驟說明與 sizing 敘述彼此一致。

## Recommended Approach

採用 **全面切換主體到 Option A，但保留 architecture 對照章節** 的方式。

這個做法的好處是：

- 所有實作文件只維持一條主線，避免使用時在 Option A / Option B 之間來回切換。
- `architecture.md` 仍保留 Option B，方便未來比較 lab 與 production 取向。
- 改動集中在既有檔案，不新增平行版本文件，避免 Jekyll 導覽重複。

## Alternatives Considered

### Alternative 1: 只改三份操作文件，architecture 維持 Option B 主體

優點是改動較小；缺點是整個資料夾會同時存在兩套「主方案」，閱讀時容易混淆，不符合這次要把 Option A 當預設模型的目標。

### Alternative 2: 為 Option A / Option B 各自拆獨立文件

優點是歷史保留完整；缺點是維護成本高、Jekyll 導覽會重複，且容易讓後續更新只改到其中一套。

## File-by-File Design

### `kubernetes/3node-kubevirt/architecture.md`

- 主標題、概述、主架構圖、元件分配表、Azure VM sizing、決策說明全部改為 **Option A 主體**。
- 保留一個明確標示的 **Option B（保留參考）** 章節。
- 決策語氣改為：目前主要採用 Option A，Option B 保留供 lab / future reference 比較。

### `kubernetes/3node-kubevirt/commands.md`

- 「設定 Node 角色」改成 Option A。
- KubeVirt 管理面 placement 改為排到 **Infra Node**，不是 Master。
- 相關 label / taint / nodeSelector / toleration 範例改成 Option A 對應命名與說明。
- 驗證指令改為確認 `virt-operator` / `virt-api` / `virt-controller` 在 Infra，`virt-handler` 在 Worker。

### `kubernetes/3node-kubevirt/flowchart.md`

- 頂部架構決策改成 Option A。
- 流程圖中 KubeVirt 管理面部署位置改成 Infra。
- 步驟表中的備註欄位從 Option B 改成 Option A，並同步更新 Master / Infra sizing 說明。

### `kubernetes/3node-kubevirt/buildup.md`

- 環境概覽表中的節點角色改為 Option A。
- 所有提到 KubeVirt 管理面在 Master 的敘述都改到 Infra。
- 所有與 node placement、taint、label、KubeVirt CR placement 有關的步驟都改為 Option A。
- 任何 sizing 或資源說明若是基於 Option B，也一併改為 Option A。

## Consistency Rules

實作時必須滿足以下一致性：

1. **Master**：只承載 Kubernetes Control Plane。
2. **Infra**：承載基礎設施服務與 KubeVirt 管理面。
3. **Worker**：承載 `virt-handler`、`virt-launcher` 與 VM workload。
4. 若文件提到 Node labels / taints，必須和 KubeVirt CR placement 設定互相對應。
5. `architecture.md` 以外的文件不再保留 Option B 當作主要操作路徑。

## Validation Plan

完成修改後，至少要重新檢查：

1. `Option A` / `Option B` 關鍵字分布是否符合設計。
2. `commands.md`、`flowchart.md`、`buildup.md` 是否都已移除以 Option B 為主的操作說明。
3. `architecture.md` 是否同時保留 Option A 主體與 Option B 參考章節。
4. Markdown 與 Mermaid 區塊是否沒有明顯語法錯誤。
