---
title: KubeVirt Phase Docs + Option B Design
parent: Specs
grand_parent: Superpowers
nav_order: 20260501
---

# KubeVirt Phase Docs + Option B Design

## Problem

`kubernetes/3node-kubevirt/buildup.md` 已成長到不利閱讀與維護的程度，現在包含從 Azure 建立 VM 到 KubeVirt VM workload 的完整長流程。使用者希望：

1. 保留現有的 **Phase 0 Option A**（手動 Azure Portal 流程）
2. 新增 **Phase 0 Option B**（由本地 Mac mini 上的 Copilot CLI 透過 Azure MCP + IaC 代執行）
3. 讓整份建立指南拆成更容易閱讀的 phase 文件
4. 使用一個 agenda / landing page 導覽 `Phase 0 ~ Phase 6`

## Goal

將 `3node-kubevirt` 的建置筆記重構成：

1. `index.md` 成為主要導覽頁，列出各 phase 與參考文件
2. `phase-0.md` 到 `phase-6.md` 各自承擔一個階段
3. `phase-0.md` 同時包含：
   - **Option A：Portal GUI 手動建置**
   - **Option B：Mac mini + Azure MCP + IaC 自動建置**
4. `architecture.md`、`commands.md`、`flowchart.md` 保留為跨 phase 的橫向參考文件
5. `buildup.md` 從單一巨型主文件，轉為總覽 / 過渡頁面，而不是唯一入口

## Recommended Approach

採用 **Phase 分頁 + agenda 主頁 + Phase 0 同頁雙模式**。

原因：

- 真正解決 `buildup.md` 過長的問題，而不是只把 Option B 外掛在原文末端
- `Phase 0` 的兩種執行方式共用同一組目標與輸入，不需要拆成兩份幾乎重複的文件
- 使用者可以依需求選擇：
  - **順著 phase 閱讀**
  - **直接查 architecture / commands / flowchart**
- 後續若要把 Option B 從設計提升為可實際執行的操作流程，也有清楚落點

## Alternatives Considered

### Alternative 1: 只新增 `phase-0-option-b.md`

優點是改動最小。缺點是 `buildup.md` 依然過長，而且資訊入口會變成「主流程在 buildup，特例在額外檔案」，閱讀模型不一致。

### Alternative 2: Phase 分頁 + `phase-0.md` 同頁雙模式

這是推薦方案。可以同時解決可讀性與未來自動化需求。

### Alternative 3: Phase 分頁 + 每個 phase 再細拆子檔

例如 `phase-0-networking.md`、`phase-0-vm.md`、`phase-0-validation.md`。優點是最細；缺點是以目前內容量來說過度切碎，導覽成本高於收益。

## Information Architecture

目標結構如下：

```text
kubernetes/3node-kubevirt/
├── index.md
├── architecture.md
├── commands.md
├── flowchart.md
├── buildup.md
├── phase-0.md
├── phase-1.md
├── phase-2.md
├── phase-3.md
├── phase-4.md
├── phase-5.md
└── phase-6.md
```

### `index.md`

升級為 agenda / landing page，至少包含：

1. 專案摘要
2. `Phase 0 ~ Phase 6` 導覽表
3. 橫向參考文件連結（architecture / commands / flowchart）
4. 建議閱讀路徑

### `phase-0.md`

主題限定為 Azure 基礎設施建立，並使用 **雙模式**：

1. 共通輸入
2. Option A：Portal GUI 手動流程
3. Option B：Mac mini Pretasks + Azure MCP / IaC 執行流程
4. 驗證輸出（RG / VNet / Subnet / NSG / VM / IP / NIC）

### `phase-1.md` ~ `phase-6.md`

每個 phase 只保留該階段的內容，不再讓單一文件跨太多責任。拆分方向應以現有 `buildup.md` 的 phase 邊界為準，不重新發明新的邏輯分段。

### `buildup.md`

改為過渡型總覽頁。內容應說明：

- 此專案的詳細建置步驟已拆分為各 phase 文件
- 提供 phase 導覽連結
- 若需要完整舊式閱讀路徑，可在此保留非常精簡的 phase 摘要，但不再複製全部細節

## Phase 0 Option B Content Model

`phase-0.md` 的 Option B 段落應明確區分三件事：

### 1. Pretasks on Mac mini

至少包含：

- Azure CLI
- Azure login / subscription selection
- Azure MCP server 可用
- Copilot CLI 可連到 Azure MCP
- SSH public key
- IaC template / params
- NSG allowed source IP/CIDR
- Azure quota / SKU availability

### 2. MCP Architecture Explanation

用非抽象語言解釋：

- Copilot CLI：協調者
- Azure MCP server：Azure 工具入口
- Azure API / ARM：真正執行端
- IaC：資源藍圖
- Mac mini：本地控制主機

### 3. Execution Flow

明確說明未來 Option B 會長這樣：

1. 使用者在 Mac mini 開啟本地 Copilot CLI
2. Copilot 透過 Azure MCP 驗證 Azure 能力
3. Copilot 套用 Bicep / IaC
4. Azure 建立 Resource Group / VNet / Subnet / NSG / NIC / VM / Public IP
5. Copilot 回報結果與驗證清單

## File Responsibilities

### Keep

- `architecture.md`: 架構決策與元件分配
- `commands.md`: 指令查表
- `flowchart.md`: 高層流程圖

### Change

- `index.md`: 導覽頁
- `buildup.md`: 過渡型總覽頁
- `phase-0.md` ~ `phase-6.md`: 詳細步驟頁

## Migration Strategy

採用 **漸進式重構**，而不是一次刪除舊入口：

1. 新增 phase 文件與 agenda 頁
2. 將 `buildup.md` 的內容依 phase 搬到新檔
3. 將 `buildup.md` 改成總覽 / 過渡頁
4. 保持舊連結仍可工作，避免導覽斷裂

## Success Criteria

完成後應滿足：

1. 使用者不需要再從 1600+ 行的 `buildup.md` 中尋找某個 phase
2. `Phase 0` 同頁即可看懂 Option A / Option B 的差異
3. `index.md` 能作為第一入口
4. `architecture.md` / `commands.md` / `flowchart.md` 仍保持原本參考價值
5. phase 文件切分後，責任邊界清楚，不重複大量內容

## Out of Scope

這份設計 **不直接實作** 以下內容：

- 實際安裝或驗證 Azure MCP server
- 實際建立 Azure 資源
- 將 Option B 做成可立即執行的完整自動化部署

這份設計只定義文件結構與 Option B 在 notebook 中的表達方式。
