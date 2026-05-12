# Ceph Solutions Comparison Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh `storage/ceph-cross-dc-migration/solutions.md` so it compares MON-vs-OSD migration sequencing first, then compares the three OSD migration rhythms using RBD performance impact and migration danger level as the primary criteria.

**Architecture:** Keep the work scoped to `solutions.md` and preserve the page's role as the strategy layer between the landing page and the runbook. Reorganize the page into two major comparison sections plus a short final recommendation summary, while keeping the existing cross-links back to the landing page and `detail_runbook.md`.

**Tech Stack:** Markdown, Jekyll/Just-the-Docs front matter, git, grep

---

## File Structure

- Modify: `storage/ceph-cross-dc-migration/solutions.md`
  - replace the current OSD-only comparison framing
  - add the MON-first vs OSD-first section
  - reframe the OSD rhythm comparison around RBD performance impact and migration danger level
  - preserve the related-links section and runbook cross-links
- Verify: `docs/superpowers/specs/2026-05-12-ceph-solutions-comparison-refresh.md`

### Task 1: Rewrite the strategy comparison page

**Files:**
- Modify: `storage/ceph-cross-dc-migration/solutions.md`
- Verify: `docs/superpowers/specs/2026-05-12-ceph-solutions-comparison-refresh.md`

- [ ] **Step 1: Verify the current page still uses the old OSD-only structure**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync/.worktrees/ceph-solutions-comparison-refresh
grep -nE '^## 比較的三種執行節奏$|^## 推薦方案：Option 2 \\(Rack-by-Rack\\)$' storage/ceph-cross-dc-migration/solutions.md
```

Expected: both old section headings are present before rewriting.

- [ ] **Step 2: Replace the intro and main body with the new two-layer comparison**

Rewrite `storage/ceph-cross-dc-migration/solutions.md` so the page follows this structure:

```md
## 前言

本文件回答兩個決策問題：

1. 先轉移 MON node，還是先轉移 OSD node？
2. 若先處理 OSD，應採用哪一種 OSD 轉移節奏？

主要比較重點為：

- user 連線 `RBD pool` 的 performance 影響
- 作業過程中的危險程度

---

## 1. 先轉移 MON node，還是先轉移 OSD node？

### Option A: 先轉移 MON node

- 先調整 quorum / monitor topology
- bulk data movement 延後到 OSD 階段

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact** | 低 | 此階段對資料面直接影響較小，但後續 OSD rebalance 壓力仍然存在 |
| **Migration danger level** | 高 | MON 變動直接影響 quorum 與 cluster control plane，作業失誤風險較高 |

### Option B: 先轉移 OSD node

- 保持現有 MON quorum 穩定
- 先完成主要資料搬遷
- 後續再處理 monitor placement

| 比較面向 | 評估 | 說明 |
|---------|------|------|
| **RBD pool performance impact** | 中 | 主要效能影響集中在 OSD rebalance / recovery，但 control plane 保持穩定 |
| **Migration danger level** | 中低 | 在最吃重的資料搬遷階段避免同時變動 quorum，整體較安全 |

### 本段建議

- **建議先轉移 OSD，再轉移 MON**
- 原因是 user 看到的主要效能波動本來就來自 OSD rebalance，因此更應避免在同一時間引入 MON quorum 風險

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
| **Overall migration duration** | 最短或中等 | 若過程順利可能較快，但單次 recovery 視窗很長 |

### 本段建議

- **建議採用櫃進櫃出（rack-by-rack）**
- 它比全進全出安全，也比一進一出更實際，是 service impact 與操作可行性的最佳平衡

---

## 3. 最終建議

1. **先轉 OSD，再轉 MON**
2. **OSD 採用櫃進櫃出**

如果最優先考量是單次對 user I/O 的干擾最低，可選一進一出；如果最優先考量是命令數量最少，可選全進全出；但對大多數實際 migration 來說，櫃進櫃出通常是最穩妥的折衷。
```

Preserve:

- front matter
- page title
- related links section
- the final cross-link to `../detail_runbook/`

- [ ] **Step 3: Verify the new decision-oriented structure**

Run:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync/.worktrees/ceph-solutions-comparison-refresh
grep -nE '^## 1\\. 先轉移 MON node，還是先轉移 OSD node？$|^## 2\\. OSD 轉移節奏比較$|^## 3\\. 最終建議$' storage/ceph-cross-dc-migration/solutions.md
grep -nE 'RBD pool performance impact|Migration danger level|先轉 OSD，再轉 MON|OSD 採用櫃進櫃出|Detail Runbook' storage/ceph-cross-dc-migration/solutions.md
```

Expected:

- the three new top-level headings are present
- the key comparison criteria and final recommendations are present
- the runbook cross-link is still present

- [ ] **Step 4: Commit the refresh**

```bash
cd /Users/mansionlai/Documents/code/notebook-sync/.worktrees/ceph-solutions-comparison-refresh
git add storage/ceph-cross-dc-migration/solutions.md docs/superpowers/plans/2026-05-12-ceph-solutions-comparison-refresh.md
git commit -m "docs: refresh ceph migration comparison page"
```
