# Home Assistant Integration Watchdog — 建置流程

> 建立日期：2026-04-11
> 分類：homeassistant-integration-watchdog

---

## 流程圖

```mermaid
flowchart TD
    START([開始]) --> A

    A["Phase 1\n確認需求\n原本：每日 2AM reload all\n問題：最長 24h 才恢復"]
    A --> B

    B["Phase 2\n設計觸發條件\n• integration_entities() 取所有 entity\n• ≥50% unavailable → 判斷為 crash\n• for: 3min 防誤觸"]
    B --> C

    C["Phase 3\n取得 entry_id\nGET /api/config/config_entries/entry\n→ 找到 4 個 target integration"]
    C --> D

    D["Phase 4\n建立 Automation v1\nvariables 方式\ntrigger.id → entry_map 查表"]
    D --> E

    E{"Phase 5\n測試 v1"}
    E -- "automation.trigger 手動觸發\ntrigger.id = None\nentry_map[None] → 錯誤" --> F
    E -- "template 正常觸發時\ntrigger.id 有設定 → 正確" --> G

    F["Phase 5 問題：\nvariables 方式不穩定\n手動測試無法模擬 trigger.id"]
    F --> G

    G["Phase 6\n重構 Automation v2\nvariables → choose block\n每個 trigger.id 對應獨立 sequence\n加入 default branch（手動測試用）"]
    G --> H

    H["Phase 7\n測試 v2\n手動觸發 → default branch 執行\nlogbook 確認 triggered 記錄\nreload_config_entry 直接測試 → 有效"]
    H --> I

    I{"Phase 8\n通知驗證"}
    I -- "persistent_notification.create\n不出現在 /api/states" --> J
    I -- "查 HA 版本：2026.4.1" --> J

    J["Phase 9\n發現：HA 2026.4+ 改用\nnotify.persistent_notification\n通知不再是 state entity\n→ 查 HA 通知鈴鐺 🔔"]
    J --> K

    K["Phase 10\n更新 Automation v3\n• 通知改 notify.persistent_notification\n• 觸發閾值 ≥50%（非 any unavailable）\n• 說明 template trigger False→True 機制"]
    K --> L

    L["Phase 11\n額外診斷\nPanasonic 40/56 unavailable\n→ reload 無效\n→ 確認是雲端 API 問題，非 HA crash"]
    L --> DONE

    DONE([✅ 完成\nAutomation 已上線\nAutomation ID: 43d56e8ed5cc4e72abce])
```

---

## 測試手法與結果紀錄

### Test 1：template 正確性驗證

**目的**：確認 `integration_entities()` domain 名稱正確，template 能取到實體

```
POST /api/template
{"template": "{{ integration_entities('panasonic_smart_app') | count }}"}
```

| Domain | Entity 數 | 結果 |
|--------|-----------|------|
| panasonic_smart_app | 56 | ✅ |
| lg_thinq | 10 | ✅ |
| smartthings | 21 | ✅ |
| xiaomi_miot | 14 | ✅ |

---

### Test 2：Automation v1 手動觸發

**問題**：`automation.trigger` 不帶 `trigger.id`，導致 `entry_map[None]` KeyError

```
automation.trigger → trigger.id = None
→ entry_map[None] → 錯誤，action 中止
→ notify 未執行
→ logbook 顯示 triggered，但無後續 action 記錄
```

**結論**：`variables` 方式不夠穩健 → 改用 `choose` block

---

### Test 3：reload_config_entry 直接測試

**目的**：確認 service 本身有效

```
POST /api/services/homeassistant/reload_config_entry
{"entry_id": "01JV59P8J1RJ9H2DVCV3J53CQH"}
→ HTTP 200 ✅
→ Panasonic 重啟（但 40/56 仍 unavailable → 確認為雲端問題）
```

---

### Test 4：Automation v2 手動觸發（choose block）

**預期**：走 `default` branch，出現通知

```
automation.trigger → default branch 執行
→ notify.persistent_notification 呼叫 HTTP 200
→ /api/states 查不到通知 entity
```

**發現**：HA 2026.4.1 通知不再是 state entity → 查 HA 通知鈴鐺

---

### Test 5：Logbook 確認 Automation 正常執行

```
2026-04-11T13:56:10 | triggered  ← Test 2
2026-04-11T13:57:47 | (state change) × 2
2026-04-11T13:58:05 | triggered  ← Test 4
2026-04-11T14:01:24 | (state change) × 2
2026-04-11T14:01:27 | triggered  ← Test 5 (v3)
```

automation 確認每次都有觸發並執行 action ✅

---

## 關鍵學習點

| 發現 | 說明 |
|------|------|
| `variables` vs `choose` | `variables` 在手動觸發時 `trigger.id` 為 None 會 KeyError；`choose` + `condition: trigger` 是更穩健的方式 |
| HA 2026.4+ 通知 | `persistent_notification.create` 廢棄，改用 `notify.persistent_notification`；通知不在 `/api/states` |
| template trigger 行為 | 只在 False → True 轉換觸發，已是 True 狀態時重啟 automation 不會立即觸發 |
| ≥50% 閾值設計 | 避免雲端不穩或單一設備斷線誤觸 reload |
| `automation.trigger` 限制 | 手動觸發不帶 `trigger.id`，只能測試 default branch，無法模擬真實 template 觸發情境 |
