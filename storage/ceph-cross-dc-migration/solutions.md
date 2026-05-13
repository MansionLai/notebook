---
title: Migration Strategy Comparison
parent: Ceph Cross-DC Migration
permalink: /storage/ceph-cross-dc-migration/solutions/
---

# Migration Strategy Comparison

## 前言

本文件回答兩個決策問題：

1. 先轉移 MON node，還是先轉移 OSD node？
2. 若先處理 OSD，應採用哪一種 OSD 轉移節奏？

主要比較重點為：

- user 連線 `RBD pool` 的 performance 影響
- 作業過程中的危險程度
- **Operator effort** 與 **Overall migration duration** 為次要參考準則，用於比較 OSD 轉移節奏的可操作性與總時程

---

## 1. 先轉移 MON node，還是先轉移 OSD node？

### Option A: 先轉移 MON node

- 先調整 quorum / monitor topology
- bulk data movement 延後到 OSD 階段

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact（第一階段）** | 低 | 在第一階段（MON relocation）對資料面直接影響較小；但後續仍會發生 OSD rebalance，整體仍會對資料面造成影響。 |
| **Migration danger level** | 高 | MON 變動直接影響 quorum 與 cluster control plane，作業失誤風險較高 |

### Option B: 先轉移 OSD node

- 保持現有 MON quorum 穩定
- 先完成主要資料搬遷
- 後續再處理 monitor placement

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact（第一階段）** | 中 | 在第一階段（OSD rebalance 開始時）即為中等影響，因為 rebalance 立刻開始落地；MON quorum 在此階段保持穩定。 |
| **Migration danger level** | 中低 | 在最吃重的資料搬遷階段避免同時變動 quorum，整體較安全 |

### 本段建議

- **建議先轉移 OSD，再轉移 MON**
- 原因：先執行 OSD 資料搬遷，並在整體資料移動完成且 cluster state 經驗證穩定後，再調整 MON placement 或 quorum。此序列可在搬遷期間維持已驗證的 MON quorum，降低同時變動 control plane 與資料平面的風險。

---

## 2. OSD 轉移節奏比較

### Option A: 一進一出

- 加入 1 台 dc2 OSD node
- recovery 完成後移除 1 台 dc1 OSD node
- 反覆執行直到全部完成

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact** | 最低 | 每次資料搬遷波動最小，對 user I/O 的尖峰衝擊最低 |
| **Migration danger level** | 最低 | 每一步 blast radius 最小，問題定位最容易 |
| **Operator effort** | 最高 | 操作次數最多，容易拖長遷移週期 |
| **Overall migration duration** | 最長 | 整體執行時間最久 |

### Option B: 櫃進櫃出

- 加入 1 個 dc2 rack
- recovery 完成後移除 1 個 dc1 rack
- 反覆執行直到全部完成

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact** | 中 | 單次波動大於一進一出，但仍屬可控範圍 |
| **Migration danger level** | 中低 | 以 rack 為邊界，影響範圍明確，便於觀察與回退 |
| **Operator effort** | 中 | 操作次數合理，可控性佳 |
| **Overall migration duration** | 中 | 比一進一出短，比全進全出長 |

### Option C: 全進全出

- 一次性加入全部 dc2 OSD nodes
- 完成 full rebalance 後，再一次性移除全部 dc1 OSD nodes

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact** | 最高 | recovery 壓力最大，user 連線 RBD pool 的 latency 波動最明顯 |
| **Migration danger level** | 最高 | 單次變動範圍最大，故障定位與中途調整都最困難 |
| **Operator effort** | 最低 | 命令次數最少 |
| **Overall migration duration** | 理論上較短（依批次數） | 若以批次計算可能較少，但因每次 recovery 視窗很長，實際總耗時未必短於櫃進櫃出 |

### 本段建議

- **建議採用櫃進櫃出（rack-by-rack）**
- 理由：全進全出主要被排除，因其 **Migration danger level = 最高**（單次變動範圍大，故障定位與中途調整最困難）。一進一出雖然對 user I/O 影響最低，但因為 **Operator effort 高且 Overall migration duration 最長**，在實務上管理成本與總時程代價過高，因此不是首選；櫃進櫃出在安全性與可行性之間提供最佳折衷。

---

## 3. 最終建議

1. **先轉 OSD，再轉 MON**
2. **OSD 採用櫃進櫃出**

如果最優先考量是單次對 user I/O 的干擾最低，可選一進一出；但對大多數實際 migration 來說，櫃進櫃出通常是最穩妥的折衷。

---

## 相關連結

- **[← 回到主文件](../)**  
  返回 Ceph Cross-DC Migration 主題入口，查看架構概述與場景說明

- **[→ MON Migration Runbook](../detail_runbook/)**  
  前往 MON Migration Runbook（monitor relocation、Rook external 協調、ceph-csi / KubeVirt 驗證）

- **[→ OSD Migration Runbook](../osd-migration/)**  
  前往 OSD Migration Runbook（以機櫃為單位遷移、觀察 recovery/backfill、RBD workload 與 gate criteria）

