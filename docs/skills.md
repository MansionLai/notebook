# Notebook 文件撰寫與維護技巧（全域適用）

## 1. 新增文件時檢查 sidebar 結構
- 每次新增 Markdown 文件，務必檢查 frontmatter 是否包含正確的 `parent` 與 `nav_order`，確保文件會顯示在正確的側邊欄分類下。
- 範例：
  ```yaml
  ---
  title: 文件標題
  parent: 上層分類名稱
  nav_order: 3
  ---
  ```

## 2. 連結檢查
- 新增或修改文件後，請檢查所有內部連結是否正確（避免 404 not found）。
- 可用 VSCode Markdown Preview 或 Jekyll 本地預覽。

## 3. 文件順序與結構
- 文件順序應符合主題邏輯或操作流程。
- 調整 `nav_order` 以反映正確順序。

## 4. 文件命名與路徑
- 檔名與資料夾名稱請使用英文小寫、連字號分隔（如：kubernetes/cluster-setup.md）。

## 5. 重要設定文件
- 各主題資料夾應有 index.md 作為總覽與導航。
- 重要流程、設定、規範請獨立成檔並於 index.md 連結。

## 6. 版本控管
- 每次修改請 commit 並 push 至 GitHub，確保版本紀錄完整。

## 7. 實測與驗證
- 文件涉及操作流程時，建議實際操作並記錄過程與結果。
- 測試過程可補充於文件末尾。

---
如有新技巧或規範，請持續補充本文件，並適用於 notebook repo 內所有主題。