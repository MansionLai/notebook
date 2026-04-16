---
title: Setup Flowchart
parent: VM Watchdog
grand_parent: Home Assistant
nav_order: 3
---

# HomeAssistant VM Watchdog 部署流程

> 建立日期：2026-04-11  
> 分類：flowchart  
> 前置條件：macOS 15、VirtualBox 7.1.8 已安裝、HomeAssistant VM 已建立

---

## 總覽

```mermaid
flowchart TD
    A([開始]) --> B[Step 1\n建立 Watchdog Script]
    B --> C[Step 2\n建立 launchd plist]
    C --> D[Step 3\n載入並啟用 launchd Agent]
    D --> E[Step 4\n移除舊的 .app Login Item]
    E --> F[Step 5\n驗證運作]
    F --> G([部署完成 ✅])
```

---

## Step 1：建立 Watchdog Script

```mermaid
flowchart TD
    S([開始]) --> DIR["mkdir -p ~/.local/bin"]
    DIR --> WRITE["建立 homeassistant-vm-watchdog.sh\n內容：無限輪詢 VM 狀態"]
    WRITE --> CHMOD["chmod +x ~/.local/bin/homeassistant-vm-watchdog.sh"]
    CHMOD --> CHK{腳本可執行?}
    CHK -- Yes --> DONE([Step 1 完成])
    CHK -- No --> FIX["確認路徑與權限"]
    FIX --> CHMOD
```

**腳本邏輯：**

```mermaid
flowchart TD
    START(["腳本啟動"]) --> LOG1["log: Watchdog started"]
    LOG1 --> LOOP["while true 無限迴圈"]
    LOOP --> QUERY["VBoxManage showvminfo\n取得 VMState"]
    QUERY --> STATE{VMState?}
    STATE -- "running / starting\n/ restoring / saving" --> SLEEP1["log: VM is running\nsleep 15s"]
    SLEEP1 --> LOOP
    STATE -- "空字串\n(VBox 未就緒)" --> SLEEP2["log: retrying...\nsleep 15s"]
    SLEEP2 --> LOOP
    STATE -- "stopped / aborted\n/ poweroff / saved" --> LAUNCH["log: launching headless\nVBoxHeadless --startvm HomeAssistant\n(blocking: 等 VM 結束)"]
    LAUNCH --> EXIT["VBoxHeadless 退出\nlog exit code"]
    EXIT --> SLEEP3["sleep 5s"]
    SLEEP3 --> LOOP
```

---

## Step 2：建立 launchd Plist

```mermaid
flowchart TD
    S([在 Mac 執行]) --> FILE["建立\n~/Library/LaunchAgents/\ncom.user.homeassistant-vm.plist"]
    FILE --> CONFIG["設定內容：\nLabel / ProgramArguments\nRunAtLoad=true\nKeepAlive=true\nThrottleInterval=30\nLog 路徑"]
    CONFIG --> DONE([Step 2 完成])
```

---

## Step 3：載入並啟用

```mermaid
flowchart TD
    S([在 Mac 執行]) --> LOAD["launchctl load\n~/Library/LaunchAgents/com.user.homeassistant-vm.plist"]
    LOAD --> CHK{"launchctl list | grep homeassistant\n顯示 PID?"}
    CHK -- Yes --> LOG["tail ~/Library/Logs/homeassistant-vm.log\n確認 Watchdog started"]
    LOG --> DONE([Step 3 完成 ✅])
    CHK -- No --> ERR["查看 error log\ntail ~/Library/Logs/homeassistant-vm-error.log"]
    ERR --> DBG["確認：\n1. 腳本路徑正確\n2. 腳本有執行權限\n3. VM 名稱正確"]
    DBG --> RELOAD["launchctl unload → launchctl load"]
    RELOAD --> CHK
```

---

## Step 4：移除舊的 .app Login Item

```mermaid
flowchart LR
    A([開啟 System Settings]) --> B["General → Login Items"]
    B --> C["找到 open_homeassistant_vm.app"]
    C --> D["點 ➖ 移除"]
    D --> E([舊方案已停用 ✅])
```

---

## Step 5：驗證流程

```mermaid
flowchart TD
    V1["確認 watchdog 正常運行\nlaunchctl list | grep homeassistant"] --> V2["確認 VM 正在運行\nVBoxManage showvminfo HomeAssistant --machinereadable\n→ VMState=running"]
    V2 --> V3["模擬 VM crash 測試\nVBoxManage controlvm HomeAssistant poweroff"]
    V3 --> V4["等待 ~20s"]
    V4 --> V5{"VM 是否自動重啟?"}
    V5 -- Yes --> V6["查看 log 確認重啟紀錄\ntail ~/Library/Logs/homeassistant-vm.log"]
    V6 --> DONE([✅ 全部驗證通過])
    V5 -- No --> DBG["查看 error log\n確認 watchdog 仍在運行"]
```

---

## 重開機驗證流程

```mermaid
sequenceDiagram
    participant Mac as macOS Boot
    participant LD as launchd
    participant WD as Watchdog Script
    participant VB as VBoxHeadless
    participant VM as HomeAssistant VM

    Mac->>LD: 用戶登入
    LD->>WD: RunAtLoad 觸發啟動
    WD->>WD: 查詢 VM 狀態 (stopped)
    WD->>VB: exec VBoxHeadless --startvm HomeAssistant
    VB->>VM: 啟動 VM
    VM-->>VB: VM 運行中 (blocking)
    Note over VM: 正常運行...
    VM-xVB: VM crash / 意外結束
    VB-->>WD: VBoxHeadless 退出 (exit code != 0)
    WD->>WD: sleep 5s，重新輪詢
    WD->>VB: 重新啟動 VBoxHeadless
    VB->>VM: VM 重啟
```

---

## 參考資料

- [launchd plist keys 說明](https://www.launchd.info/)
- [VBoxHeadless 無頭模式](https://www.virtualbox.org/manual/ch07.html)
