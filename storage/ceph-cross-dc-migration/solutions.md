---
title: Migration Strategy Comparison
parent: Ceph Cross-DC Migration
permalink: /storage/ceph-cross-dc-migration/solutions/
---

# Migration Strategy Comparison

## 前言

本文件比較三種**執行節奏（migration rhythm）**，協助選擇最適合的操作模式。

這些節奏都基於 **same-cluster migration** 模型（將 dc2 節點加入現有 cluster、等待 rebalance、再移除 dc1 節點），差異在於**批次大小與頻率**：

1. **Option 1 (Big Bang)**: 一次性加入所有 dc2 節點，再一次性移除所有 dc1 節點
2. **Option 2 (Rack-by-Rack)**: 以 rack 為單位交替新增與移除
3. **Option 3 (Node-by-Node)**: 以單一節點為單位交替新增與移除

---

## 比較的三種執行節奏

### Option 1: Big Bang — 先加入所有 dc2 OSD，再移除所有 dc1 OSD

**執行方式**：
1. 一次性加入 dc2 全部 15 台 OSD 節點（150 OSDs）
2. 等待 cluster 完成完整 rebalance
3. 一次性移除 dc1 全部 15 台 OSD 節點（150 OSDs）

**特性比較**：

| 評估面向 | 評分 | 說明 |
|---------|------|------|
| **Operational Simplicity** | ⭐⭐⭐⭐⭐ | 操作最簡單：僅兩次大批次操作 + 一次等待 |
| **Recovery Frequency** | ⭐ | 僅一次大規模 recovery，但持續時間極長（可能數天至一週） |
| **Cluster Scale Peak** | ⭐ | 最高負載：cluster 會暫時容納 30 台 OSD 節點（300 OSDs），為原始規模的 2 倍 |
| **pg_num Pressure** | ⭐ | 最高壓力：所有 PG 同時重新映射與搬遷，會產生極大的 CRUSH 計算與 I/O 壓力 |
| **Risk of Prolonged Migration** | ⭐ | 最高風險：單次 recovery 時間過長，若中途發生故障難以快速 rollback |
| **Operator Effort** | ⭐⭐⭐⭐⭐ | 最低人力：僅需兩次 orchestration 命令，無需重複監控 |

**優點**：
- 操作步驟最少，人工干預最低

**缺點**：
- Cluster 規模翻倍，硬體資源（CPU、RAM、network）壓力最大
- 所有 PG 同時搬遷，recovery 時間極長且不可中斷
- 若 recovery 過程出現問題（如硬體故障、網路中斷），難以快速定位與修復
- 線上服務受 I/O 延遲影響時間最長

---

### Option 2: Rack-by-Rack — 交替新增 dc2 rack / 移除 dc1 rack

**執行方式**：
1. 加入 dc2 的一個 rack（5 台 OSD 節點，50 OSDs）
2. 等待 recovery 完成
3. 移除 dc1 的一個 rack（5 台 OSD 節點，50 OSDs）
4. 等待 recovery 完成
5. 重複上述步驟，直到完成全部 3 個 racks 的遷移

**特性比較**：

| 評估面向 | 評分 | 說明 |
|---------|------|------|
| **Operational Simplicity** | ⭐⭐⭐ | 中等複雜度：需要 6 次批次操作（3 次加入 + 3 次移除）+ 6 次等待 |
| **Recovery Frequency** | ⭐⭐⭐ | 6 次 recovery 週期，每次持續時間中等（數小時至一天） |
| **Cluster Scale Peak** | ⭐⭐⭐ | 中等負載：cluster 暫時容納 20 台 OSD 節點（200 OSDs），為原始規模的 1.33 倍 |
| **pg_num Pressure** | ⭐⭐⭐ | 中等壓力：每次約 1/3 的 PG 重新映射，CRUSH 與 I/O 壓力可控 |
| **Risk of Prolonged Migration** | ⭐⭐⭐⭐ | 低風險：每個週期較短，問題容易定位；可在 rack 邊界暫停或 rollback |
| **Operator Effort** | ⭐⭐⭐ | 中等人力：需多次監控與操作，但頻率合理（每週期可能 1-2 天） |

**優點**：
- **安全性與可控性的最佳平衡點**：recovery 週期長度適中，問題易於定位
- Cluster 規模增長受控（最多增加 33%），硬體資源壓力溫和
- 每次操作影響範圍明確（rack 為自然邊界），便於問題追蹤與回退
- 若某個 rack 硬體有問題，可在該批次發現並處理，不影響全局

**缺點**：
- 需要 6 次操作與監控週期，人工介入次數較多
- 總遷移時間較長（但風險降低）

---

### Option 3: Node-by-Node — 交替新增 dc2 node / 移除 dc1 node

**執行方式**：
1. 加入 dc2 的一台 OSD 節點（10 OSDs）
2. 等待 recovery 完成
3. 移除 dc1 的一台 OSD 節點（10 OSDs）
4. 等待 recovery 完成
5. 重複上述步驟，直到完成全部 15 台節點的遷移

**特性比較**：

| 評估面向 | 評分 | 說明 |
|---------|------|------|
| **Operational Simplicity** | ⭐ | 最複雜：需要 30 次批次操作（15 次加入 + 15 次移除）+ 30 次等待 |
| **Recovery Frequency** | ⭐⭐⭐⭐⭐ | 30 次 recovery 週期，每次持續時間短（數小時） |
| **Cluster Scale Peak** | ⭐⭐⭐⭐⭐ | 最低負載：cluster 最多增加 1 台節點（10 OSDs），僅增加約 6.7% |
| **pg_num Pressure** | ⭐⭐⭐⭐⭐ | 最低壓力：每次僅約 6-7% 的 PG 重新映射，CRUSH 與 I/O 壓力最小 |
| **Risk of Prolonged Migration** | ⭐⭐⭐⭐⭐ | 最低風險：每次影響範圍最小，問題極易定位與修復 |
| **Operator Effort** | ⭐ | 最高人力：需要 30 次手動操作與監控，持續數週 |

**優點**：
- 每次 recovery 影響最小，cluster 負載波動最低
- 問題定位最容易（僅涉及單一節點）
- 對線上服務影響最小

**缺點**：
- **操作複雜度過高**：30 次重複操作極易疲勞與人為錯誤
- 總遷移時間最長，可能持續數週甚至一個月
- 過於保守，未充分利用 cluster 的 rebalance 能力
- 運維人力成本過高

---

## 推薦方案：Option 2 (Rack-by-Rack)

### 選擇理由

**Option 2 (Rack-by-Rack)** 是三者中**安全性與實用性的最佳平衡點**，理由如下：

1. **風險可控**：
   - 每次 recovery 週期長度適中（數小時至一天），問題容易在有限時間內發現與處理
   - 若某個 rack 有硬體問題，可在單一批次內發現並隔離，不影響其他 racks

2. **操作負擔合理**：
   - 6 次操作週期是人工可管理的頻率（每週期 1-2 天）
   - 不會像 Option 3 產生 30 次重複操作的疲勞與錯誤風險

3. **硬體資源壓力溫和**：
   - Cluster 規模最多增加 33%（從 15 台增至 20 台），遠低於 Option 1 的 100% 增長
   - CPU、RAM、網路頻寬壓力在合理範圍內

4. **Rack 是自然的操作邊界**：
   - Rack 是 Ceph 的 failure domain，也是實體部署的自然單位
   - 以 rack 為批次大小符合 CRUSH 模型，便於 troubleshooting

5. **充分利用 Ceph rebalance 能力**：
   - 每次搬遷約 1/3 的資料，充分發揮 cluster 的平行處理能力
   - 不會像 Option 3 過於保守，浪費 rebalance 效率

### 不推薦 Option 1 的原因

- Cluster 規模翻倍的資源壓力過大，可能導致硬體瓶頸（CPU、RAM、network saturation）
- 單次 recovery 時間過長（可能數天至一週），難以在合理時間內完成，且中途無法中斷
- 若出現問題，rollback 或定位困難，風險過高

### 不推薦 Option 3 的原因

- 30 次重複操作的人力成本過高，且極易產生操作疲勞與人為錯誤
- 總遷移時間過長（可能數週至一個月），拉長專案週期
- 過於保守，未充分利用 Ceph 的 rebalance 能力，浪費效率

---

## 相關連結

- **[← 回到主文件](../)**  
  返回 Ceph Cross-DC Migration 主題入口，查看架構概述與場景說明

- **[→ 執行步驟詳細手冊](../detail_runbook/)**  
  前往 Detail Runbook，取得分階段執行步驟、前置驗證與 rollback 規則

---

## 後續行動

選定 Option 2 (Rack-by-Rack) 後，請參考 [Detail Runbook](../detail_runbook/) 取得：

- 分階段執行步驟（Phase 0-7）
- 每個階段的 gate criteria 與驗證檢查點
- CRUSH map 更新範例指令
- Cutover 前後的檢查清單
- Rollback 策略與條件
