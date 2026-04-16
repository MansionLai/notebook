---
title: Commands
parent: VM Watchdog
grand_parent: Home Assistant
nav_order: 2
---

# HomeAssistant VM Watchdog 指令手冊

> 建立日期：2026-04-11  
> 分類：commands  
> 環境：macOS 15 · VirtualBox 7.1.8 · launchd

---

## 部署指令（一次性設定）

### Step 1：建立 Watchdog Script

```bash
# 建立目錄
mkdir -p ~/.local/bin

# 建立 watchdog 腳本
cat > ~/.local/bin/homeassistant-vm-watchdog.sh << 'EOF'
#!/bin/bash
# HomeAssistant VM Watchdog
# • 開機自動啟動 VirtualBox VM（headless 模式）
# • VM crash 後自動重啟
# • 若 VM 已在運行，靜候直到結束再重啟
# • Log rotation：超過 1MB 自動輪替，保留最近 7 天

VM_NAME="HomeAssistant"
VBOX_HEADLESS="/usr/local/bin/VBoxHeadless"
VBOX_MANAGE="/usr/local/bin/VBoxManage"
LOG_FILE="${HOME}/Library/Logs/homeassistant-vm.log"
LOG_MAX_BYTES=$((1024 * 1024))   # 1 MB
LOG_MAX_DAYS=7                   # 保留天數
POLL_INTERVAL=60                 # 秒：偵測 VM 狀態的輪詢間隔（1 分鐘）

# ── Log 工具 ──────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [homeassistant-watchdog] $*" >> "$LOG_FILE"
}

rotate_log() {
    [ ! -f "$LOG_FILE" ] && return

    # 大於 1MB → 輪替（加時間戳後綴）
    local size
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt "$LOG_MAX_BYTES" ]; then
        local ts
        ts=$(date '+%Y%m%d-%H%M%S')
        mv "$LOG_FILE" "${LOG_FILE}.${ts}"
        log "Log rotated (was ${size} bytes → archived as .${ts})"
    fi

    # 刪除超過 7 天的舊輪替檔
    find "$(dirname "$LOG_FILE")" \
        -name "$(basename "$LOG_FILE").*" \
        -mtime +${LOG_MAX_DAYS} \
        -delete 2>/dev/null
}

# ── VM 狀態查詢 ───────────────────────────────────────────────────
get_vm_state() {
    "$VBOX_MANAGE" showvminfo "$VM_NAME" --machinereadable 2>/dev/null \
        | grep '^VMState=' | cut -d'"' -f2
}

# ── 主迴圈 ────────────────────────────────────────────────────────
log "Watchdog started for VM: $VM_NAME (interval=${POLL_INTERVAL}s, maxLog=${LOG_MAX_BYTES}B, retention=${LOG_MAX_DAYS}d)"

while true; do
    rotate_log
    STATE=$(get_vm_state)

    case "$STATE" in
        running|starting|restoring|saving)
            log "VM is '$STATE', monitoring..."
            sleep "$POLL_INTERVAL"
            ;;
        "")
            log "Could not query VM state, retrying in ${POLL_INTERVAL}s..."
            sleep "$POLL_INTERVAL"
            ;;
        *)
            log "VM state is '$STATE', launching headless..."
            "$VBOX_HEADLESS" --startvm "$VM_NAME" >> "$LOG_FILE" 2>&1
            EXIT_CODE=$?
            log "VBoxHeadless exited with code $EXIT_CODE (state: $(get_vm_state))"
            sleep 5
            ;;
    esac
done
EOF

# 賦予執行權限
chmod +x ~/.local/bin/homeassistant-vm-watchdog.sh
```

### Step 2：建立 launchd Plist

```bash
# 建立 plist 設定檔
cat > ~/Library/LaunchAgents/com.user.homeassistant-vm.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.homeassistant-vm</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/mansionlai/.local/bin/homeassistant-vm-watchdog.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/Users/mansionlai/Library/Logs/homeassistant-vm-error.log</string>
</dict>
</plist>
EOF
```

### Step 3：載入並啟用

```bash
# 載入 launchd agent（立即生效，重開機也自動載入）
launchctl load ~/Library/LaunchAgents/com.user.homeassistant-vm.plist

# 確認已載入（應顯示 PID 和 0 exit code）
launchctl list | grep homeassistant
# 輸出範例: 21006    0    com.user.homeassistant-vm
```

---

## 日常管理指令

### 查看狀態與 Log

```bash
# 查看 watchdog 是否在運行（第一欄為 PID）
launchctl list | grep homeassistant

# 即時查看 log（Ctrl+C 停止）
tail -f ~/Library/Logs/homeassistant-vm.log

# 查看最後 20 行 log
tail -20 ~/Library/Logs/homeassistant-vm.log

# 查看錯誤 log
tail -f ~/Library/Logs/homeassistant-vm-error.log

# 查看 VM 目前狀態
VBoxManage showvminfo HomeAssistant --machinereadable | grep VMState
```

### 停止 / 重啟 VM

```bash
# ── 優雅關機（ACPI 電源按鈕，HA 會自行 shutdown）──────
VBoxManage controlvm HomeAssistant acpipowerbutton
# ⚠️ Watchdog 偵測到 VM stopped 後會自動重啟！
# 若要永久停止，先 unload 再關機：

# ── 永久停止（停用 watchdog + 關閉 VM）────────────────
launchctl unload ~/Library/LaunchAgents/com.user.homeassistant-vm.plist
VBoxManage controlvm HomeAssistant acpipowerbutton

# ── 強制關閉 VM（緊急用）────────────────────────────
launchctl unload ~/Library/LaunchAgents/com.user.homeassistant-vm.plist
VBoxManage controlvm HomeAssistant poweroff
```

### 啟用 / 停用 Watchdog

```bash
# 停用 watchdog（下次開機不再自動啟動）
launchctl unload ~/Library/LaunchAgents/com.user.homeassistant-vm.plist

# 重新啟用 watchdog
launchctl load ~/Library/LaunchAgents/com.user.homeassistant-vm.plist

# 重啟 watchdog（修改 plist 後需執行）
launchctl unload ~/Library/LaunchAgents/com.user.homeassistant-vm.plist
launchctl load ~/Library/LaunchAgents/com.user.homeassistant-vm.plist
```

---

## 測試 Crash Recovery

```bash
# Step 1：確認 VM 正在運行
VBoxManage showvminfo HomeAssistant --machinereadable | grep VMState
# 預期: VMState="running"

# Step 2：模擬 crash（強制斷電）
VBoxManage controlvm HomeAssistant poweroff

# Step 3：等待 ~20 秒後確認 VM 已自動重啟
sleep 20 && VBoxManage showvminfo HomeAssistant --machinereadable | grep VMState
# 預期: VMState="running"

# Step 4：查看 log 確認 watchdog 偵測到 crash 並重啟
tail -10 ~/Library/Logs/homeassistant-vm.log
# 預期輸出:
# 2026-04-11 XX:XX:XX [homeassistant-watchdog] VM state is 'aborted', launching headless...
# 2026-04-11 XX:XX:XX [homeassistant-watchdog] VBoxHeadless exited with code 0 ...
```

---

## 疑難排解

```bash
# Watchdog 未啟動：檢查 plist 語法
plutil -lint ~/Library/LaunchAgents/com.user.homeassistant-vm.plist

# 查看 launchd 載入錯誤
launchctl error $(launchctl list | grep homeassistant | awk '{print $3}') 2>/dev/null

# 手動測試腳本（不透過 launchd）
bash ~/.local/bin/homeassistant-vm-watchdog.sh

# 清除 log 並重新追蹤
> ~/Library/Logs/homeassistant-vm.log
tail -f ~/Library/Logs/homeassistant-vm.log

# VBoxManage 找不到 VM：確認 VM 名稱
VBoxManage list vms
```

---

## 檔案位置速查

| 檔案 | 路徑 |
|------|------|
| Watchdog 腳本 | `~/.local/bin/homeassistant-vm-watchdog.sh` |
| launchd plist | `~/Library/LaunchAgents/com.user.homeassistant-vm.plist` |
| 正常 log | `~/Library/Logs/homeassistant-vm.log` |
| 錯誤 log | `~/Library/Logs/homeassistant-vm-error.log` |

---

## 參考資料

- [launchd.info — plist 設定詳解](https://www.launchd.info/)
- [VirtualBox CLI 文件](https://www.virtualbox.org/manual/ch08.html)
- [Apple launchctl man page](https://ss64.com/osx/launchctl.html)
