# Copilot CLI Custom Agents Design

**Date:** 2026-04-10  
**Topic:** @coder and @note-taker agents for GitHub Copilot CLI

---

## Problem Statement

使用者需要兩個專用的 Copilot CLI agent：
1. `@coder`：負責技術面（程式碼分析、架構設計、debug）
2. `@note-taker`：負責將學習內容整理為 Markdown 筆記並 push 到 GitHub

---

## Architecture

### Agent 格式
Copilot CLI 的 agent 為 `.md` 檔，放置於：
```
~/.copilot/installed-plugins/superpowers-marketplace/superpowers/agents/
```

每個檔案包含：
- **YAML frontmatter**：`name`、`description`（含觸發範例）、`model`
- **System prompt**：agent 的行為指引

### 備份策略
兩個 agent 檔案同時備份至 `MansionLai/notebook` repo 的 `agents/` 目錄，防止 superpowers plugin 更新時遺失。

---

## @coder Agent

**檔案**：`agents/coder.md`  
**Model**：`inherit`

### 能力
- 閱讀並分析原始碼（架構、設計模式、相依關係）
- 識別 bug、效能瓶頸、安全漏洞
- 提供重構建議（SOLID、DRY、Clean Code）
- 撰寫新功能程式碼，遵循專案現有風格
- 解釋技術概念與架構決策

### 觸發時機
- 使用者需要 code review
- 使用者需要分析某段程式碼的行為
- 使用者需要設計新功能的技術方案

---

## @note-taker Agent

**檔案**：`agents/note-taker.md`  
**Model**：`inherit`  
**Notebook Repo**：`git@github.com:MansionLai/notebook.git`  
**本地工作目錄**：`/tmp/notebook-sync`

### 能力
- 將口述或貼上的學習內容轉換為結構化 `.md` 筆記
- 自動判斷分類並放入對應目錄（或建立新目錄）
- 使用 Mermaid 語法生成架構圖、流程圖
- 自動 git pull → 建立/修改檔案 → git commit → git push

### 目錄判斷規則
| 內容類型 | 目錄 |
|----------|------|
| 系統架構、服務設計、元件關係 | `architecture/` |
| 流程、工作流、狀態機 | `flowchart/` |
| CLI 指令、API、設定參數 | `commands/` |
| 其他新主題 | 自動建立新目錄（英文小寫、kebab-case）|

### 筆記結構範例
```markdown
# 主題名稱

## 概述
簡短說明。

## 架構圖 / 流程圖（適用時）
\`\`\`mermaid
graph TD
    A --> B
\`\`\`

## 重點說明
- 條列式重點

## 常用指令（適用時）
\`\`\`bash
指令範例
\`\`\`

## 參考
- 來源連結
```

### Git 操作流程
```
1. cd /tmp/notebook-sync (如不存在則 git clone)
2. git pull
3. 建立/修改 .md 檔
4. git add .
5. git commit -m "notes: <主題> - <類型>"
6. git push
```

---

## Backup Strategy

建立 `agents/` 目錄於 notebook repo，存放 `coder.md` 和 `note-taker.md`。  
在 `README.md` 中加入還原說明：
```bash
cp agents/coder.md ~/.copilot/installed-plugins/superpowers-marketplace/superpowers/agents/
cp agents/note-taker.md ~/.copilot/installed-plugins/superpowers-marketplace/superpowers/agents/
```

---

## Error Handling

- **Notebook repo clone 失敗**：note-taker 應提示使用者確認 SSH key 是否設定
- **Push 失敗**：顯示錯誤訊息並保留本地已生成的 `.md` 檔案
- **目錄判斷不確定**：列出選項請使用者確認
