---
title: Commands
parent: Integration Watchdog
grand_parent: Home Assistant
nav_order: 2
---

# Home Assistant Integration Watchdog — API 指令紀錄

> 建立日期：2026-04-11
> 分類：homeassistant-integration-watchdog
> 環境：HA 2026.4.1 · http://192.168.50.71:8123

---

## 前置：產生 Long-Lived Access Token

1. HA → 左下角頭像（Profile）
2. Security → Long-Lived Access Tokens → **Create Token**
3. 名稱：`copilot-api`（用完記得刪除）

```bash
HA_URL="http://192.168.50.71:8123"
TOKEN="<your-long-lived-token>"
```

---

## Step 1：列出所有 Config Entries（取得 entry_id）

```bash
# 列出所有非系統 integration 的 domain + entry_id + title
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://192.168.50.71:8123/api/config/config_entries/entry \
| python3 -c "
import json, sys
entries = json.load(sys.stdin)
skip = {'homeassistant','met','sun','moon','statistics','history','logbook',
        'recorder','frontend','person','zone','backup','hassio','go2rtc',
        'radio_browser','thread','matter','cast','homekit'}
for e in sorted(entries, key=lambda x: x.get('domain','')):
    d = e.get('domain','')
    if d not in skip:
        print(f\"{d:35s} | {e.get('entry_id','')} | {e.get('title','')}\")
"
```

### 執行結果（2026-04-11）

```
androidtv_remote                    | 01JV54E4TQR9MABGQG1GEB61VY | 客廳電視
apple_tv                            | 01JV54E36KD0HYVBZ3PEFV76TA | 書房HomePod Mini
dlna_dmr                            | 01JV54E1MHB2GGE0540B83348E | 客廳電視
dlna_dmr                            | 01K5BWQVX8YSFHYY8ESWDKF5QM | 32" Smart Monitor M7
hacs                                | 01JV56F5XAHABYR5GX5ATMDBCN |
lg_thinq                            | 01JV5591HB9C3KTWSZEWG0DZ30 | LG ThinQ
panasonic_smart_app                 | 01JV59P8J1RJ9H2DVCV3J53CQH | mansion.lai.411@gmail.com
samsungtv                           | 01K5BYK510KF0PVRXSP5R28C3D | 32" Smart Monitor M7
smartthings                         | 01JVFETGN4SK49H6JP713Q7GS4 | 星都匯
localtuya                           | 01KPFZBPHQY8YYT4TQZD9TFEJV | localtuya
xiaomi_miot                         | 01JXJ6NQK07P96CRRF1DMED2VX | Xiaomi: 1769736625
```

---

## Step 2：驗證 integration_entities() 模板

{% raw %}
```bash
# 確認各 domain 名稱正確，template 可取到實體
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"template": "{{ integration_entities(\"panasonic_smart_app\") | count }}"}' \
  http://192.168.50.71:8123/api/template

# 一次確認全部（Python script）
python3 << 'EOF'
import json, urllib.request

HA_URL = "http://192.168.50.71:8123"
TOKEN = "<your-token>"

def render(tpl):
    req = urllib.request.Request(f"{HA_URL}/api/template",
        data=json.dumps({"template": tpl}).encode(),
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
        method="POST")
    with urllib.request.urlopen(req) as resp:
        return resp.read().decode().strip()

for domain in ['panasonic_smart_app', 'lg_thinq', 'smartthings', 'xiaomi_miot', 'localtuya']:
    count = render(f"{{{{ integration_entities('{domain}') | count }}}}")
    trigger_val = render(f"""{{% set ents = integration_entities('{domain}') %}}{{% set total = ents | count %}}{{% set unavail = ents | map('states') | select('equalto', 'unavailable') | list | count %}}{{{{ total }}}} total / {{{{ unavail }}}} unavail / trigger={{{{ total > 0 and unavail/total >= 0.5 }}}}""")
    print(f"{domain:30s}: {trigger_val}")
EOF
```
{% endraw %}

### 執行結果

```
panasonic_smart_app           : 56 total / 40 unavail / trigger=True   ← 雲端問題（非 crash）
lg_thinq                      : 10 total /  0 unavail / trigger=False  ✅
smartthings                   : 21 total /  0 unavail / trigger=False  ✅
xiaomi_miot                   : 14 total /  0 unavail / trigger=False  ✅
localtuya                     : 10 total /  0 unavail / trigger=False  ✅
```

---

## Step 3：建立 Automation via REST API

{% raw %}
```python
import json, urllib.request, uuid

HA_URL = "http://192.168.50.71:8123"
TOKEN = "<your-token>"
AUTOMATION_ID = "43d56e8ed5cc4e72abce"   # 本次使用的 ID（固定，方便更新）

def make_reload_sequence(entry_id, label):
    return [
        {"action": "homeassistant.reload_config_entry",
         "data": {"entry_id": entry_id}},
        {"action": "notify.persistent_notification",
         "data": {
             "title": f"⚠️ {label} 自動修復",
             "message": f"偵測到 {label} 設備失聯，已於 {{{{ now().strftime('%Y-%m-%d %H:%M') }}}} 自動重新載入 Integration。"
         }},
        {"action": "notify.gmail",
         "data": {
             "title": f"⚠️ [HA] {label} Integration 自動修復",
             "message": f"時間：{{{{ now().strftime('%Y-%m-%d %H:%M:%S') }}}}\n事件：{label} 偵測到設備大量失聯（≥50%），已自動重新載入 Integration。\n\n— HomeAssistant 192.168.50.71:8123"
         }},
        {"delay": {"minutes": 5}}
    ]

automation = {
    "id": AUTOMATION_ID,
    "alias": "智慧家電 Integration 自動修復",
    "description": "偵測 Panasonic / LG / SmartThings / Xiaomi / LocalTuya 設備全線失聯（>=50%），自動 reload 並寄信通知",
    "trigger": [
        {"platform": "template", "id": "panasonic",
         "value_template": "{% set ents = integration_entities('panasonic_smart_app') %}{% set total = ents | count %}{{ total > 0 and (ents | map('states') | select('equalto', 'unavailable') | list | count) / total >= 0.5 }}",
         "for": {"minutes": 3}},
        {"platform": "template", "id": "lg_thinq",
         "value_template": "{% set ents = integration_entities('lg_thinq') %}{% set total = ents | count %}{{ total > 0 and (ents | map('states') | select('equalto', 'unavailable') | list | count) / total >= 0.5 }}",
         "for": {"minutes": 3}},
        {"platform": "template", "id": "smartthings",
         "value_template": "{% set ents = integration_entities('smartthings') %}{% set total = ents | count %}{{ total > 0 and (ents | map('states') | select('equalto', 'unavailable') | list | count) / total >= 0.5 }}",
         "for": {"minutes": 3}},
        {"platform": "template", "id": "xiaomi_miot",
         "value_template": "{% set ents = integration_entities('xiaomi_miot') %}{% set total = ents | count %}{{ total > 0 and (ents | map('states') | select('equalto', 'unavailable') | list | count) / total >= 0.5 }}",
         "for": {"minutes": 3}},
        {"platform": "template", "id": "localtuya",
         "value_template": "{% set ents = integration_entities('localtuya') %}{% set total = ents | count %}{{ total > 0 and (ents | map('states') | select('equalto', 'unavailable') | list | count) / total >= 0.5 }}",
         "for": {"minutes": 3}}
    ],
    "conditions": [],
    "action": [{
        "choose": [
            {"conditions": [{"condition": "trigger", "id": "panasonic"}],
             "sequence": make_reload_sequence("01JV59P8J1RJ9H2DVCV3J53CQH", "Panasonic Smart App")},
            {"conditions": [{"condition": "trigger", "id": "lg_thinq"}],
             "sequence": make_reload_sequence("01JV5591HB9C3KTWSZEWG0DZ30", "LG ThinQ")},
            {"conditions": [{"condition": "trigger", "id": "smartthings"}],
             "sequence": make_reload_sequence("01JVFETGN4SK49H6JP713Q7GS4", "SmartThings")},
            {"conditions": [{"condition": "trigger", "id": "xiaomi_miot"}],
             "sequence": make_reload_sequence("01JXJ6NQK07P96CRRF1DMED2VX", "Xiaomi Miot")},
            {"conditions": [{"condition": "trigger", "id": "localtuya"}],
             "sequence": make_reload_sequence("01KPFZBPHQY8YYT4TQZD9TFEJV", "LocalTuya")},
        ],
        "default": [{"action": "notify.persistent_notification",
                     "data": {"title": "✅ Automation 手動測試",
                              "message": "choose block 正常執行（手動觸發，未執行 reload）"}}]
    }],
    "mode": "parallel",
    "max": 5
}

# POST automation
req = urllib.request.Request(
    f"{HA_URL}/api/config/automation/config/{AUTOMATION_ID}",
    data=json.dumps(automation).encode(),
    headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    method="POST")
with urllib.request.urlopen(req) as resp:
    print(f"Create: HTTP {resp.status}", json.loads(resp.read()))  # → {'result': 'ok'}

# Reload automations 使其生效
req2 = urllib.request.Request(f"{HA_URL}/api/services/automation/reload",
    data=b"{}",
    headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    method="POST")
urllib.request.urlopen(req2)
print("Automations reloaded ✅")
```
{% endraw %}

---

## Step 4：驗證 Automation 狀態

```bash
# 查詢 automation entity 狀態
curl -s \
  -H "Authorization: Bearer $TOKEN" \
  http://192.168.50.71:8123/api/states/automation.zhi_hui_jia_dian_integration_zi_dong_xiu_fu \
| python3 -c "
import json, sys
d = json.load(sys.stdin)
print('state:', d['state'])
print('last_triggered:', d['attributes'].get('last_triggered'))
print('alias:', d['attributes'].get('friendly_name'))
"
```

### 預期結果

```
state: on
last_triggered: None   ← 尚未自動觸發（正常）
alias: 智慧家電 Integration 自動修復
```

---

## Step 5：手動觸發測試

```bash
# 手動觸發（不設定 trigger.id，走 default branch）
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "automation.zhi_hui_jia_dian_integration_zi_dong_xiu_fu"}' \
  http://192.168.50.71:8123/api/services/automation/trigger
```

預期行為：
- HA 通知鈴鐺出現「✅ Automation 手動測試」訊息
- Logbook 記錄 `triggered` 事件
- **不會執行 reload**（因為 trigger.id 未設定，走 default branch）

---

## Step 6：直接測試 reload_config_entry

```bash
# 直接 reload 特定 integration（繞過 automation，確認 service 有效）
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entry_id": "01JV59P8J1RJ9H2DVCV3J53CQH"}' \
  http://192.168.50.71:8123/api/services/homeassistant/reload_config_entry
```

> ⚠️ 此指令會暫時重啟 Panasonic integration，設備短暫斷線

---

## Step 7：查看觸發 Logbook

```bash
python3 << 'EOF'
import json, urllib.request
from datetime import datetime, timezone, timedelta

HA_URL = "http://192.168.50.71:8123"
TOKEN = "<your-token>"

since = (datetime.now(timezone.utc) - timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
req = urllib.request.Request(
    f"{HA_URL}/api/logbook/{since}?entity_id=automation.zhi_hui_jia_dian_integration_zi_dong_xiu_fu",
    headers={"Authorization": f"Bearer {TOKEN}"}
)
with urllib.request.urlopen(req) as resp:
    for entry in json.loads(resp.read()):
        print(f"{entry.get('when','')[:19]} | {entry.get('message','(state change)')}")
EOF
```

---

## 常見問題排查

### Q: Automation 狀態是 on 但從不觸發

Template trigger 只在 **False → True 轉換**時觸發。若 HA 重啟時 integration 已失聯（template 啟動就是 True），需等 integration 恢復後再次 crash。

### Q: 設備 unavailable 但 reload 沒有效果

- 代表是**雲端 API / 設備本身問題**，非 HA integration crash
- 例如：Panasonic 雲端維護、設備斷電
- 此情況下 reload 無效，需等雲端服務恢復

### Q: 通知沒有出現

- HA 2026.4+ 通知不在 `/api/states`，查看 HA 介面右上角通知鈴鐺 🔔
- 若完全沒出現，檢查 `notify.persistent_notification` service 是否存在：
  ```bash
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://192.168.50.71:8123/api/services | python3 -c "
  import json,sys; svcs=json.load(sys.stdin)
  n=[d for d in svcs if d.get('domain')=='notify']
  print(list(n[0]['services'].keys()) if n else 'notify domain not found')
  "
  ```

### Q: 想更新 automation 觸發閾值

直接 POST 相同的 `AUTOMATION_ID`（`43d56e8ed5cc4e72abce`），HA 會覆蓋更新，然後 reload automations。

---

## Gmail SMTP 設定（HA configuration.yaml）

在 `/config/configuration.yaml` 加入以下設定後重啟 HA：

```yaml
notify:
  - name: gmail
    platform: smtp
    server: smtp.gmail.com
    port: 587
    starttls: true
    sender: "你的email@gmail.com"
    username: "你的email@gmail.com"
    password: "app-password-無空格"   # Google App Password（16碼去空格）
    recipient:
      - "你的email@gmail.com"
```

> **App Password 產生**：https://myaccount.google.com/apppasswords
> 需先開啟 Google 帳號兩步驟驗證

驗證 notify.gmail 已載入：

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  http://192.168.50.71:8123/api/services \
| python3 -c "
import json,sys
svcs=json.load(sys.stdin)
n=next((d for d in svcs if d.get('domain')=='notify'),None)
print(list(n['services'].keys()) if n else 'not found')
"
# 預期出現 'gmail' 在列表中
```

發送測試信：

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"[HA] 測試","message":"Gmail 通知設定成功！"}' \
  http://192.168.50.71:8123/api/services/notify/gmail
```

---

## HA REST API 快速參考

| 用途 | Method | Endpoint |
|------|--------|----------|
| 列出所有 config entries | GET | `/api/config/config_entries/entry` |
| 建立/更新 automation | POST | `/api/config/automation/config/<id>` |
| 查詢 automation config | GET | `/api/config/automation/config/<id>` |
| 呼叫 service | POST | `/api/services/<domain>/<service>` |
| Reload automations | POST | `/api/services/automation/reload` |
| 查詢 entity 狀態 | GET | `/api/states/<entity_id>` |
| 渲染 template | POST | `/api/template` |
| Logbook 查詢 | GET | `/api/logbook/<ISO8601_timestamp>` |
| HA config/version | GET | `/api/config` |
