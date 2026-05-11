---
title: Cross-DC Migration Detail Runbook
parent: Ceph Cross-DC Migration
permalink: /storage/ceph-cross-dc-migration/detail_runbook/
---

# Cross-DC Migration Detail Runbook

本文件提供跨資料中心 Ceph 遷移的**實際執行手冊**，包含分階段步驟、前置驗證、cutover 檢查點、rollback 規則與指令參考。

關於遷移策略的分析與決策依據，請參考 [Solutions Overview](../solutions/)。關於場景與架構概述，請參考[主文件](../)。

---

## 1. Migration Principles

### 核心原則

1. **單一 Cluster 擴展模式**
   - 將 dc2 節點加入現有 cluster（而非建立第二 cluster）
   - 等待 CRUSH rebalance 完成資料搬遷
   - 最後移除 dc1 節點

2. **Rack-by-Rack 執行節奏**
   - 以 rack 為操作單位（每個 rack 包含 5 台 OSD 節點、50 個 OSDs）
   - 交替執行「加入 dc2 rack」→「等待 recovery」→「移除 dc1 rack」→「等待 recovery」
   - 總共 6 次操作週期（3 次加入 + 3 次移除）

3. **CRUSH 設計考量**
   - **不分離 datacenter bucket**：CRUSH 模型保持單一邏輯 dc
   - **Failure domain 維持 rack 級別**
   - Rack 命名不重複（dc1: o1/o2/o3, dc2: o4/o5/o6），避免混淆新舊節點

4. **最小化業務影響**
   - 每次 recovery 週期長度適中（數小時至一天），問題容易定位
   - Cluster 規模最多增加 33%（從 15 台增至 20 台），硬體資源壓力溫和
   - 每個階段都有明確的 gate criteria，確保可安全進入下一階段

---

## 2. KubeVirt / RBD Notes

### 現有 RBD Pool 配置

- **Pool 用途**：服務 KubeVirt 虛擬機的持久化儲存
- **Replication**：假設為 `size=3, min_size=2`（標準高可用配置）
- **PG 數量**：依據 pool 大小與 OSD 數量計算（應符合 Ceph best practice）

### KubeVirt VM 影響評估

**遷移期間 VM 行為**：

1. **I/O 延遲可能增加**
   - Recovery 過程中，部分 PG 處於 `degraded` 或 `misplaced` 狀態
   - VM 的 block device I/O 會經歷額外的網路跳轉與 backfill traffic
   - **建議**：監控 VM 應用層面的延遲指標，必要時調整 recovery throttling

2. **資料可用性無虞**
   - 只要 `min_size=2` 且 cluster 健康，VM 不會遭遇 I/O 中斷
   - CRUSH 保證每個 PG 的 replica 分布於不同 racks（failure domain）

3. **VM 遷移考量**
   - **無需遷移 VM**：Ceph RBD 遷移對 VM 透明，VM 持續運行於原 KubeVirt 節點
   - **可選操作**：若 VM 負載敏感，可於 cutover 前手動 live migrate 至低負載節點

### 監控重點

- **Ceph 層面**：
  - `ceph -s`：確認 health 狀態、PG 狀態分布
  - `ceph osd pool stats <pool>`：監控 recovery 進度與 I/O 統計
  - `ceph osd df tree`：檢查 OSD 使用率是否平衡

- **KubeVirt / VM 層面**：
  - VM guest OS 的 disk I/O latency（如透過 `iostat` 或應用監控）
  - KubeVirt virt-launcher pod 的 resource usage
  - 若有應用層 SLA，確認 latency 與 throughput 仍在可接受範圍

---

## 3. Detailed Phase Runbook

本節詳述 Rack-by-Rack 遷移的完整執行步驟。

### Phase 0: Pre-Migration Preparation

**目標**：確保 cluster 健康、備份關鍵配置、建立監控基線

#### 前置檢查清單

1. **Cluster Health Check**
   ```bash
   ceph -s
   # 必須為 HEALTH_OK，無 degraded/misplaced PGs
   
   ceph osd tree
   # 確認現有 dc1 的 rack 結構（o1, o2, o3）
   
   ceph osd df tree
   # 記錄 OSD 使用率基線
   ```

2. **Backup CRUSH Map**
   ```bash
   ceph osd getcrushmap -o /backup/crushmap.$(date +%Y%m%d).bin
   crushtool -d /backup/crushmap.$(date +%Y%m%d).bin -o /backup/crushmap.$(date +%Y%m%d).txt
   ```

3. **Verify MON Quorum**
   ```bash
   ceph mon stat
   # 確認 3 個 MON 都在 quorum 中
   ```

4. **Record Baseline Metrics**
   - 記錄當前 cluster 的 IOPS、throughput、latency 基線
   - 記錄 VM 應用層的效能基線（若有監控）

5. **Network Connectivity Test**
   ```bash
   # 從 dc1 節點測試到 dc2 節點的連通性
   ping -c 10 <dc2-node-ip>
   iperf3 -c <dc2-node-ip> -t 30
   # 確認 latency < 5ms，bandwidth 符合預期
   ```

#### Gate Criteria (進入 Phase 1 前)

- ✅ Cluster health = `HEALTH_OK`
- ✅ 所有 PGs 為 `active+clean`
- ✅ CRUSH map 已備份
- ✅ dc1 ↔ dc2 網路連通性驗證完成
- ✅ 監控系統已就緒，可追蹤 recovery 進度

---

### Phase 1: Add dc2 Rack o4 (First Batch)

**目標**：加入 dc2 第一個 rack（o4）的 5 台 OSD 節點

#### 執行步驟

1. **Add OSD Nodes to Cluster**
   ```bash
   # 使用 cephadm 加入 dc2 rack o4 的 5 台節點
   # dc2 節點位置資訊固定為 datacenter=dc2, room=r2
   # 假設節點名稱為 osd-dc2-o4-{01..05}

   for node in osd-dc2-o4-{01..05}; do
     ceph orch host add $node --labels osd --location datacenter=dc2 room=r2 rack=o4
   done
   ```

   補一句說明：

   - dc1 既有節點對應 `datacenter=dc1 room=r1`
   - `datacenter` 與 `room` 用來補充拓樸資訊
   - failure domain 仍然是 `rack`

2. **Deploy OSDs**
   ```bash
   # 使用 cephadm 自動部署 OSD（假設已有 OSD spec）
   ceph orch apply -i /path/to/osd-spec-dc2-o4.yaml
   
   # 或手動指定每台節點的 disks
   # 範例：對每個節點的 10 顆 disk 執行
   ceph orch daemon add osd osd-dc2-o4-01:/dev/sdb
   # ... 重複 10 顆 disk
   ```

3. **Verify OSD Creation**
   ```bash
   ceph osd tree | grep o4
   # 確認 50 個新 OSDs 已 up 且 in
   
   ceph osd df tree | grep o4
   # 檢查新 OSDs 的狀態與初始 weight
   ```

4. **Monitor Recovery Progress**
   ```bash
   watch -n 5 'ceph -s'
   # 觀察 PGs 進入 remapped/backfilling 狀態
   
   ceph osd pool stats
   # 檢查 recovery rate 與 backfill throughput
   ```

#### Recovery Throttling (Optional)

若 recovery 對線上業務影響過大，可調整 throttling 參數：

```bash
# 降低 recovery 優先級
ceph tell osd.* config set osd_recovery_max_active 1
ceph tell osd.* config set osd_max_backfills 1

# 限制 recovery bandwidth
ceph tell osd.* config set osd_recovery_sleep_hdd 0.1
```

#### Gate Criteria (進入 Phase 2 前)

- ✅ 50 個新 OSDs (rack o4) 已 `up` 且 `in`
- ✅ Cluster health = `HEALTH_OK`，所有 PGs 恢復為 `active+clean`
- ✅ Recovery 完成（`ceph -s` 顯示 0 個 degraded/misplaced PGs）
- ✅ OSD 使用率已重新平衡（無單一 OSD 超載）
- ✅ VM I/O latency 恢復正常（若先前有異常）

**預估時間**：數小時至一天（視資料量與網路頻寬而定）

---

### Phase 2: Remove dc1 Rack o1 (First Batch)

**目標**：移除 dc1 第一個 rack（o1）的 5 台 OSD 節點

#### 執行步驟

1. **Mark OSDs Out**
   ```bash
   # 取得 rack o1 的所有 OSD IDs
   ceph osd tree | grep 'rack o1' -A 50 | grep osd | awk '{print $1}' > /tmp/o1-osds.txt
   
   # 逐一標記 out（觸發 data migration）
   for osd_id in $(cat /tmp/o1-osds.txt); do
     ceph osd out osd.$osd_id
   done
   
   # 驗證
   ceph osd tree | grep o1
   # 應看到對應 OSDs 顯示 out
   ```

2. **Wait for Data Migration**
   ```bash
   watch -n 5 'ceph -s'
   # 等待所有 PGs 再次恢復為 active+clean
   
   ceph pg dump | grep -v active+clean
   # 確認無 degraded/misplaced PGs
   ```

3. **Stop OSD Daemons**
   ```bash
   for osd_id in $(cat /tmp/o1-osds.txt); do
     ceph orch daemon stop osd.$osd_id
   done
   ```

4. **Purge OSDs from CRUSH**
   ```bash
   for osd_id in $(cat /tmp/o1-osds.txt); do
     ceph osd purge osd.$osd_id --yes-i-really-mean-it
   done
   
   # 驗證
   ceph osd tree | grep o1
   # 應不再顯示 rack o1 的 OSDs
   ```

5. **Remove Hosts from Cluster**
   ```bash
   for node in osd-dc1-o1-{01..05}; do
     ceph orch host rm $node --force
   done
   ```

#### Gate Criteria (進入 Phase 3 前)

- ✅ Rack o1 的 50 個 OSDs 已從 CRUSH map 移除
- ✅ Cluster health = `HEALTH_OK`，所有 PGs 恢復為 `active+clean`
- ✅ OSD 使用率已重新平衡（剩餘 OSDs 無超載）
- ✅ 物理節點已從 orchestrator 移除

**預估時間**：數小時至一天

---

### Phase 3: Add dc2 Rack o5 (Second Batch)

**執行步驟**：同 Phase 1，但目標為 dc2 rack o5

```bash
# Add nodes
for node in osd-dc2-o5-{01..05}; do
  ceph orch host add $node --labels osd --location rack=o5
done

# Deploy OSDs
ceph orch apply -i /path/to/osd-spec-dc2-o5.yaml

# Monitor recovery
watch -n 5 'ceph -s'
```

#### Gate Criteria (進入 Phase 4 前)

- ✅ 50 個新 OSDs (rack o5) 已 `up` 且 `in`
- ✅ Cluster health = `HEALTH_OK`，所有 PGs 恢復為 `active+clean`

---

### Phase 4: Remove dc1 Rack o2 (Second Batch)

**執行步驟**：同 Phase 2，但目標為 dc1 rack o2

```bash
# Mark out
ceph osd tree | grep 'rack o2' -A 50 | grep osd | awk '{print $1}' | \
  xargs -I {} ceph osd out osd.{}

# Wait for recovery
watch -n 5 'ceph -s'

# Purge OSDs
ceph osd tree | grep 'rack o2' -A 50 | grep osd | awk '{print $1}' | \
  xargs -I {} ceph osd purge osd.{} --yes-i-really-mean-it

# Remove hosts
for node in osd-dc1-o2-{01..05}; do
  ceph orch host rm $node --force
done
```

#### Gate Criteria (進入 Phase 5 前)

- ✅ Rack o2 的 50 個 OSDs 已從 CRUSH map 移除
- ✅ Cluster health = `HEALTH_OK`

---

### Phase 5: Add dc2 Rack o6 (Third Batch)

**執行步驟**：同 Phase 1，但目標為 dc2 rack o6

```bash
# Add nodes
for node in osd-dc2-o6-{01..05}; do
  ceph orch host add $node --labels osd --location rack=o6
done

# Deploy OSDs
ceph orch apply -i /path/to/osd-spec-dc2-o6.yaml

# Monitor recovery
watch -n 5 'ceph -s'
```

#### Gate Criteria (進入 Phase 6 前)

- ✅ 50 個新 OSDs (rack o6) 已 `up` 且 `in`
- ✅ Cluster health = `HEALTH_OK`

---

### Phase 6: Remove dc1 Rack o3 (Third Batch)

**執行步驟**：同 Phase 2，但目標為 dc1 rack o3（最後一個 dc1 rack）

```bash
# Mark out
ceph osd tree | grep 'rack o3' -A 50 | grep osd | awk '{print $1}' | \
  xargs -I {} ceph osd out osd.{}

# Wait for recovery
watch -n 5 'ceph -s'

# Purge OSDs
ceph osd tree | grep 'rack o3' -A 50 | grep osd | awk '{print $1}' | \
  xargs -I {} ceph osd purge osd.{} --yes-i-really-mean-it

# Remove hosts
for node in osd-dc1-o3-{01..05}; do
  ceph orch host rm $node --force
done
```

#### Final Validation

- ✅ 所有 dc1 racks (o1, o2, o3) 已完全移除
- ✅ 僅剩 dc2 racks (o4, o5, o6) 的 150 個 OSDs
- ✅ Cluster health = `HEALTH_OK`
- ✅ OSD 使用率平衡（無單一 OSD 超過 80%）

---

### Phase 7: MON Migration

**目標**：將 3 個 MON 節點從 dc1 遷移至 dc2

#### 執行步驟

1. **Add dc2 MONs (one by one)**
   ```bash
   # 加入第一個 dc2 MON（暫時變為 4 個 MON）
   ceph orch daemon add mon mon-dc2-01 --location rack=m4
   
   # 等待 MON 加入 quorum
   ceph mon stat
   # 確認 4 個 MON 都在 quorum
   
   # 加入第二個 dc2 MON（暫時變為 5 個 MON）
   ceph orch daemon add mon mon-dc2-02 --location rack=m5
   
   ceph mon stat
   # 確認 5 個 MON 都在 quorum
   
   # 加入第三個 dc2 MON（暫時變為 6 個 MON）
   ceph orch daemon add mon mon-dc2-03 --location rack=m6
   
   ceph mon stat
   # 確認 6 個 MON 都在 quorum
   ```

2. **Remove dc1 MONs (one by one)**
   ```bash
   # 移除第一個 dc1 MON
   ceph orch daemon rm mon.mon-dc1-01 --force
   
   ceph mon stat
   # 確認剩餘 5 個 MON 都在 quorum
   
   # 移除第二個 dc1 MON
   ceph orch daemon rm mon.mon-dc1-02 --force
   
   ceph mon stat
   # 確認剩餘 4 個 MON 都在 quorum
   
   # 移除第三個 dc1 MON（最後一個）
   ceph orch daemon rm mon.mon-dc1-03 --force
   
   ceph mon stat
   # 確認僅剩 3 個 dc2 MON 都在 quorum
   ```

3. **Remove dc1 MON Hosts**
   ```bash
   for node in mon-dc1-{01..03}; do
     ceph orch host rm $node --force
   done
   ```

#### Gate Criteria (MON Migration Complete)

- ✅ 僅剩 3 個 dc2 MON 在 quorum 中
- ✅ Cluster health = `HEALTH_OK`
- ✅ 所有 dc1 MON 節點已從 orchestrator 移除

---

## 4. Cutover Gates

每個 Phase 必須滿足以下條件才能進入下一階段：

### Recovery Completion Gate

```bash
# 檢查 PG 狀態
ceph pg stat | grep -q 'active+clean' && echo "PASS: All PGs active+clean" || echo "FAIL"

# 檢查無 degraded PGs
ceph -s | grep -q 'degraded\|misplaced' && echo "FAIL: Degraded PGs exist" || echo "PASS"

# 檢查 recovery 完成
ceph -s | grep -q 'recovering\|backfilling' && echo "FAIL: Recovery in progress" || echo "PASS"
```

### Cluster Health Gate

```bash
# 必須為 HEALTH_OK 或 HEALTH_WARN（僅接受已知的非關鍵 warning）
ceph health detail
```

### OSD Balance Gate

```bash
# 檢查 OSD 使用率標準差（應 < 10%）
ceph osd df tree | awk '/osd\./ {print $7}' | \
  awk '{sum+=$1; sumsq+=$1*$1} END {print sqrt(sumsq/NR - (sum/NR)^2)}'
# 若標準差 > 10，考慮手動 reweight 或等待進一步 rebalance
```

### VM Health Gate (Optional)

```bash
# 檢查 KubeVirt VM 的 I/O latency 是否恢復基線
# 依據實際監控系統執行（如 Prometheus query）
```

---

## 5. Rollback Rules

### 何時需要 Rollback

1. **Recovery 失敗**：
   - PG 持續處於 `degraded` 超過預期時間（如 > 24 小時）
   - 出現大量 `incomplete` 或 `stale` PGs

2. **硬體故障**：
   - 新加入的 dc2 節點出現硬體問題（disk failure, network issue）
   - 無法在短時間內修復

3. **效能劣化**：
   - VM I/O latency 超過 SLA（如 p99 > 100ms）
   - 應用層報告不可接受的效能下降

4. **網路問題**：
   - dc1 ↔ dc2 網路中斷或延遲飆升
   - Cluster 出現 network partition 風險

### Rollback 步驟

#### Case 1: 剛加入 dc2 rack，尚未移除 dc1 rack

**操作**：將新加入的 dc2 rack OSDs 標記 out 並移除

```bash
# 假設在 Phase 1，剛加入 rack o4
# 取得 rack o4 的所有 OSD IDs
ceph osd tree | grep 'rack o4' -A 50 | grep osd | awk '{print $1}' > /tmp/o4-osds.txt

# 標記 out
for osd_id in $(cat /tmp/o4-osds.txt); do
  ceph osd out osd.$osd_id
done

# 等待資料搬回 dc1 racks
watch -n 5 'ceph -s'

# 移除 OSDs
for osd_id in $(cat /tmp/o4-osds.txt); do
  ceph osd purge osd.$osd_id --yes-i-really-mean-it
done

# 移除 hosts
for node in osd-dc2-o4-{01..05}; do
  ceph orch host rm $node --force
done
```

**結果**：恢復為原始的 dc1-only cluster 狀態

---

#### Case 2: 已移除部分 dc1 rack，需 rollback

**限制**：若已移除 dc1 rack o1，則無法完全 rollback（因資料已搬離且節點已移除）

**緩解措施**：
- 若 dc1 rack o1 的節點與 disks 仍可存取，可嘗試重新加入：
  ```bash
  # 重新加入 dc1 rack o1 節點
  for node in osd-dc1-o1-{01..05}; do
    ceph orch host add $node --labels osd --location rack=o1
  done
  
  # 重新部署 OSDs（需 disks 資料仍存在）
  ceph orch apply -i /path/to/osd-spec-dc1-o1.yaml
  ```

- 若節點已無法恢復，則：
  - **保持當前狀態**（dc2 部分 racks + dc1 部分 racks 混合模式）
  - 等待 cluster health 穩定後，評估繼續遷移或維持混合模式

**建議**：Rollback 的最佳時機是在**每個 Phase 的 gate criteria 檢查點之前**。一旦跨越 gate 進入下一 Phase，rollback 難度與風險顯著增加。

---

### Rollback Decision Matrix

| Phase | Rollback 難度 | 建議行動 |
|-------|-------------|---------|
| Phase 1（加入 dc2 o4） | ⭐ 簡單 | 直接移除 dc2 o4，恢復原狀 |
| Phase 2（移除 dc1 o1） | ⭐⭐⭐ 困難 | 若需 rollback，需重新加入 dc1 o1（若硬體仍可用） |
| Phase 3-6 | ⭐⭐⭐⭐ 極困難 | 不建議 rollback，應專注於修復當前問題並繼續前進 |
| Phase 7（MON 遷移） | ⭐⭐ 中等 | 可逐一移除 dc2 MON 並重新加入 dc1 MON |

---

## 6. Command Reference

### 常用監控指令

```bash
# Cluster 整體狀態
ceph -s

# PG 統計
ceph pg stat
ceph pg dump | head -n 20

# OSD 狀態與使用率
ceph osd tree
ceph osd df tree
ceph osd status

# Recovery 進度
ceph osd pool stats
ceph -w  # 持續監控（按 Ctrl+C 退出）

# CRUSH map 查看
ceph osd crush tree
ceph osd crush dump

# MON 狀態
ceph mon stat
ceph quorum_status -f json-pretty

# Health 詳情
ceph health detail
```

### Recovery Throttling 調整

```bash
# 降低 recovery 優先級（減少對線上業務影響）
ceph tell osd.* config set osd_recovery_max_active 1
ceph tell osd.* config set osd_max_backfills 1
ceph tell osd.* config set osd_recovery_sleep_hdd 0.1

# 恢復預設值（加速 recovery）
ceph tell osd.* config set osd_recovery_max_active 3
ceph tell osd.* config set osd_max_backfills 1
ceph tell osd.* config set osd_recovery_sleep_hdd 0
```

### CRUSH Map 操作

```bash
# 匯出 CRUSH map
ceph osd getcrushmap -o crushmap.bin
crushtool -d crushmap.bin -o crushmap.txt

# 編輯 CRUSH map（若需手動調整）
vim crushmap.txt

# 編譯並匯入
crushtool -c crushmap.txt -o crushmap-new.bin
ceph osd setcrushmap -i crushmap-new.bin
```

### OSD 權重調整

```bash
# 查看 OSD 權重
ceph osd tree | grep osd

# 手動調整 OSD 權重（若 rebalance 需要）
ceph osd crush reweight osd.<id> <weight>

# 自動 reweight（based on utilization）
ceph osd reweight-by-utilization 110  # 110 = 10% threshold
```

### 緊急操作

```bash
# 暫停 recovery（緊急情況）
ceph osd set norecover
ceph osd set nobackfill

# 恢復 recovery
ceph osd unset norecover
ceph osd unset nobackfill

# 暫停 scrubbing（減少 cluster 負載）
ceph osd set noscrub
ceph osd set nodeep-scrub

# 恢復 scrubbing
ceph osd unset noscrub
ceph osd unset nodeep-scrub
```

---

## 相關連結

- **[← 回到主文件](../)**  
  返回 Ceph Cross-DC Migration 主題入口，查看場景說明與架構圖

- **[← 遷移策略分析](../solutions/)**  
  查看 Rack-by-Rack 方案的選擇理由與其他方案的比較

---

## 附錄：常見問題

### Q1: Recovery 時間過長怎麼辦？

**A**: 檢查以下因素：
1. 網路頻寬是否飽和（使用 `iperf3` 測試）
2. OSD disk I/O 是否瓶頸（使用 `iostat` 檢查）
3. 考慮提高 recovery throttling 參數（見上方 Command Reference）
4. 若非緊急，可維持保守設定，讓 recovery 慢速進行以減少業務影響

### Q2: PG 出現 incomplete 怎麼處理？

**A**: 
```bash
# 檢查 incomplete PG
ceph pg dump | grep incomplete

# 查看該 PG 的詳細資訊
ceph pg <pgid> query

# 若確認無法恢復，可嘗試強制 mark complete（慎用）
ceph pg <pgid> mark_unfound_lost revert
```

### Q3: 如何驗證 CRUSH placement 正確？

**A**:
```bash
# 查看某個 PG 的 OSD 分布
ceph pg map <pgid>

# 驗證 replica 是否分布於不同 racks
ceph pg dump | awk '{print $1, $16}' | head -n 20
# 檢查 acting OSD set 是否跨越不同 racks
```

### Q4: MON migration 是否必須在 OSD migration 之後？

**A**: 建議順序為**先完成 OSD migration，再進行 MON migration**。理由：
- OSD migration 是資料搬遷的主要工作，需大量時間與監控
- MON migration 較快且風險較低（quorum 可容許短暫變化）
- 分開執行可降低操作複雜度與 troubleshooting 難度

若需同步進行，建議在 Phase 3-4 期間（OSD migration 中期）穿插進行 MON 遷移。
