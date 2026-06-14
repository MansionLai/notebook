---
title: IaC README MCP vs Bicep FAQ Design
---

# IaC README MCP vs Bicep FAQ Design

## Problem

`kubernetes/3node-kubevirt/iac/README.md` 目前只有 IaC/Bicep 目錄的簡短導覽，缺少一段能回答實際使用情境的說明：如果已經能透過 Azure MCP 直接建立 Azure 資源，為什麼還需要 Bicep。

## Goal

在 README 中加入一段短而清楚的 FAQ，讓讀者快速理解：

1. Azure MCP 可以直接依需求建立資源。
2. Bicep 的主要價值是把基礎設施定義成可重複部署、可版控、可審查的宣告式配置。
3. MCP 與 Bicep 是互補關係，不是互斥選項。

## Chosen Approach

採用 **FAQ 問答格式**，而不是新開大型章節或把內容混進開頭介紹段落。

### Rationale

- 這段內容來自真實使用問題，直接用問答格式最自然。
- README 目前篇幅很短，FAQ 比正式教學章節更容易插入且不破壞閱讀節奏。
- 後續若再補其他常見問題，也可以延續同一個區塊。

## README Change Design

在現有簡介與「目前可先閱讀」之間，新增一個 FAQ 小節，包含：

- 問題：`沒有 IaC / Bicep，也可以直接透過 Azure MCP 建立 Azure resource 嗎？如果可以，為什麼還需要 Bicep？`
- 答案第一段：說明可以直接用 Azure MCP 建立資源，前提是權限足夠。
- 答案第二段：說明 Bicep 的價值在於一致性、可重複部署、版本控制、review 與變更預覽。
- 答案第三段：用一句總結收斂成「MCP 適合即時操作；Bicep 適合把環境正式定義下來」。

## Content Constraints

- 語氣維持中文、說明型、偏實務，不寫成教科書口吻。
- 不引入過長表格，避免 README 失焦。
- 不新增與本題無關的 IaC 教學內容。

## Expected Result

README 讀者能在 30 秒內理解：

- 直接操作 Azure MCP 是可行的。
- 這個 IaC 目錄存在的理由，是為了把已確認的 Azure 架構保存成可重建的 Bicep 定義。
