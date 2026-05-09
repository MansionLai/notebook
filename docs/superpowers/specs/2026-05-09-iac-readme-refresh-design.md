---
title: IaC README Refresh Design
---

# IaC README Refresh Design

## Problem

`kubernetes/3node-kubevirt/iac/README.md` 已經加入基本 FAQ，但內容仍落後於目前實際進度，也還保留了過時的導覽區塊。

目前主要落差如下：

1. 狀態仍寫成「Bicep 實作尚未開始」，但實際上已經有第一版 Bicep。
2. FAQ 只有文字，缺少一眼能看懂的 Azure MCP vs Bicep 對照表。
3. `目前可先閱讀` 區塊已不再必要。
4. `後續預計會放在這裡的內容` 仍是 placeholder，尚未反映目前目錄裡已存在的檔案。

## Goal

把 `kubernetes/3node-kubevirt/iac/README.md` 強化成一個更準確的 IaC landing page，讓讀者可以快速理解：

1. 目前 IaC / Bicep 已經有第一版實作。
2. Azure MCP 與 Bicep 的差異與分工。
3. 這個目錄裡有哪些關鍵檔案、各自負責什麼。
4. 後續若 Bicep 內容持續更新，README 的狀態描述也必須同步更新。

## Chosen Approach

維持 README 作為**輕量導覽頁**，不把它擴成完整部署教學。

具體調整如下：

- 更新狀態文字，反映「已開始實作且有第一版」。
- 保留 FAQ 問答，但在答案中加入一個簡潔對照表。
- 刪除 `目前可先閱讀`。
- 把原本的 placeholder 清單改成實際檔案導覽，每個項目附上：
  - GitHub Pages 完整網址
  - 一句極短說明

## Rationale

- README 應該先做到**準確導覽**，而不是變成完整操作手冊。
- 對照表比純文字更容易讓使用者快速理解 MCP 與 Bicep 的差異。
- 既然 `main.bicep`、`main.bicepparam` 與 `modules/` 已存在，README 應直接導向它們，而不是繼續寫成未來規劃。
- 這頁會被當作入口頁閱讀，因此狀態不應落後於實作進度。

## README Change Design

### 1. 更新狀態區塊

把目前狀態改成已反映第一版實作的敘述，語氣保持簡潔，例如：

> 目前狀態：Bicep 已開始實作，目錄中已有第一版 `main.bicep`、`main.bicepparam` 與 `modules/` 結構。

另外在設計上明確記錄一條維護規則：

- 若未來 Bicep 實作有明顯里程碑更新，這個狀態描述也要一起更新。

### 2. 強化 FAQ

保留現有 FAQ 主題：

`沒有 IaC / Bicep，也可以直接透過 Azure MCP 建立 Azure resource 嗎？如果可以，為什麼還需要 Bicep？`

FAQ 答案會包含：

- 簡短文字說明
- 一個 Markdown 對照表，欄位至少包含：
  - 方式
  - 比較像
  - 強項
  - 弱點

表格內容聚焦兩列：

- Azure MCP 直接建資源
- Bicep / IaC

### 3. 移除過時導覽區塊

刪除整個 `## 目前可先閱讀` 區塊與其單一 spec 連結。

### 4. 取代 placeholder 清單

把 `## 後續預計會放在這裡的內容` 改寫成已存在內容的導覽區，例如可改為：

- `## 目前目錄內容`

此區塊至少包含下列項目：

- `main.bicep`
- `main.bicepparam`
- `modules/`

每個項目都要有：

1. GitHub Pages 完整網址
2. 一句超短介紹

若 `modules/` 適合拆開導覽，也可列出：

- `modules/network.bicep`
- `modules/nsg.bicep`
- `modules/nic.bicep`
- `modules/vm.bicep`

但前提是整體仍維持簡潔，不要讓 README 變成過度冗長的索引。

## Content Constraints

- 維持繁體中文、實務導向、導覽頁語氣。
- 使用 GitHub Pages 完整網址，不使用相對連結或 GitHub blob 連結。
- 不在這次變更中補完整部署教學、驗證步驟或大篇幅 Bicep 說明。
- 內容應控制在「入口頁可快速掃描」的密度。

## Expected Result

更新後的 README 應讓讀者快速獲得以下資訊：

- 目前 IaC / Bicep 不是空白目錄，而是已有第一版實作。
- 即使可直接用 Azure MCP 建資源，Bicep 仍有其價值。
- 這個目錄有哪些核心檔案，以及每個檔案大致用途。
- README 的狀態文字未來需要隨 Bicep 進度持續同步。
