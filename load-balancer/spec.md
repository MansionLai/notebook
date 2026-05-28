---
title: 規格書
parent: Load Balancer
nav_order: 99
---

# Load Balancer 主題規格書

> 本文件記錄使用者需求原文與我的理解，方便後續修改文檔方向。

---

## 使用者原始描述

> 「幫我再創一個主題, Load balancer, 先以 keepalived + haproxy 當作範例,
> 我一樣要在我的 Mac mini 上創兩台 vm, 分別是 keepalived master 和 slave,
> 我要使用 active-standby mode, 請幫我把 vm 使用固定 ip
> (192.168.50.211, 192.168.50.212), 並加上一個 VIP 192.168.50.250,
> 只有 master 會有 VIP.」

---

## 我的理解

### 目標

在 Mac mini 本機環境模擬一個 **高可用負載均衡器**，使用 Keepalived 管理 VIP 漂移、HAProxy 處理流量分發。重點是理解 Active-Standby 切換機制，以及如何在 VM 環境中複現這個架構。

### 環境

| 項目 | 我的假設 |
|------|---------|
| Host 機器 | Mac mini（macOS） |
| VM 工具 | Multipass（與 Netbox 主題一致） |
| VM OS | Ubuntu 22.04 |
| 家用網段 | `192.168.50.0/24`（從 IP 規劃推斷） |
| 路由器 IP | `192.168.50.1`（常見家用路由器預設） |
| VM 網路模式 | Multipass 橋接模式（bridged to en0）|

### 元件選擇

| 元件 | 用途 | 我的理解 |
|------|------|---------|
| **Keepalived** | VIP 管理、故障偵測 | 使用 VRRP 協定，master priority 100，slave priority 90 |
| **HAProxy** | 實際負載均衡 | 兩台 VM 配置相同，由 VIP 決定流量進入哪台 |

### IP 規劃

| 角色 | IP | 說明 |
|------|----|------|
| lb-master 固定 IP | `192.168.50.211` | 永遠存在，VM 啟動即有 |
| lb-slave 固定 IP | `192.168.50.212` | 永遠存在，VM 啟動即有 |
| VIP | `192.168.50.250` | 浮動 IP，正常情況在 master |

### Active-Standby 行為

- 正常：VIP `192.168.50.250` 綁在 lb-master
- Master 故障：~3-5 秒內 VIP 漂移到 lb-slave
- Master 恢復：VIP 自動回切到 lb-master（preempt）

---

## 文檔範圍（目前已創建）

| 文件 | 說明 |
|------|------|
| `index.md` | 主題導覽 |
| `architecture.md` | VRRP 原理、元件分工、切換流程圖 |
| `vm-setup.md` | Multipass 建 VM、netplan 設定靜態 IP |
| `keepalived-config.md` | Master/Slave 完整 keepalived.conf |
| `haproxy-config.md` | HAProxy frontend/backend/stats 配置 |
| `failover-testing.md` | 5 種故障切換測試情境 |

---

## 待確認事項（可能需要修正）

- [ ] VM 網卡介面名稱：文件中預設用 `ens4`，實際可能是 `enp0s2` 或其他，需要 `ip addr show` 確認
- [ ] 路由器 Gateway：文件假設 `192.168.50.1`，請確認你的實際路由器 IP
- [ ] HAProxy 後端：文件中的後端 (`192.168.50.101`, `.102`) 是佔位符，需替換為實際後端 IP
- [ ] Mac 網路介面：文件假設有線是 `en0`，請用 `multipass networks` 確認
- [ ] Multipass 版本：橋接網路的 `--network` 參數需要 Multipass 1.11+

---

## 未來可擴展的方向（使用者未提及，供參考）

- Active-Active 模式（兩台同時服務）
- 加上 SSL 終止（HAProxy TLS）
- 監控整合（Prometheus + Grafana 顯示 HAProxy stats）
- 與 Netbox 主題整合（用 Netbox 管理這些 IP 資產）
- 換成 Nginx 作為 Load Balancer 對比範例
