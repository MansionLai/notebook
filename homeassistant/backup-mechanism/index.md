---
layout: default
title: 備份機制與保留策略
parent: Home Assistant
nav_order: 3
---

# 🛡️ 備份機制與保留策略 (Google Drive Backup)

> 建立日期：2026-07-27  
> 目的：紀錄 Home Assistant 備份至 Google Drive 的機制，並規範備份檔案的生命週期。

## 備份種類說明

Home Assistant 會產生兩種主要備份，並同步至 Google Drive：

### 1. 完整定期備份 (Full Backup)
- **觸發方式**：由「Home Assistant Google Drive Backup」附加元件自動排程觸發。
- **檔名特徵**：`Full Backup YYYY-MM-DD HH:MM:SS.tar` (使用真實的備份時間命名)。
- **用途**：每天例行性備份系統所有設定檔、附加元件及資料庫，作為最穩定的還原點。
- **保留策略設定**：
  - 本地 HA 儲存空間：保留 4 份
  - Google Drive 雲端：**保留 14 天** (14 份)

### 2. 升級前保護備份 (Automatic Backup)
- **觸發方式**：當您手動點擊「更新 HA Core」或「更新附加元件」時，系統預設觸發的手術前快照。
- **檔名特徵**：`Automatic backup 2026.x.x.tar` (使用**升級前**的系統版本號命名，**數字代表版本號，而非日期**)。
- **用途**：防止更新失敗導致系統死機，若更新失敗可立即透過此備份回滾到原本的版本。

## 注意事項

- 當發現 `Automatic backup` 的修改日期與檔名上的數字對不起來時，請不用擔心，因為檔名上的數字是「系統版本號」，與日期無關。
- Google Drive 上的備份保留天數若不足 14 天，請進入 HA 的 `Google Drive Backup` UI 介面，將 `Generations (Days to keep in Google Drive)` 修改為 14。
