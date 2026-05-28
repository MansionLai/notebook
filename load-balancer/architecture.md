---
title: 架構概覽
parent: Load Balancer
nav_order: 1
---

# Load Balancer 架構概覽

## 整體架構

```mermaid
graph TB
    Client["🖥️ Client<br/>任意裝置"]

    subgraph MAC["Mac mini (Host)"]
        subgraph VMs["Multipass VMs (橋接網路)"]
            subgraph MASTER["lb-master · 192.168.50.211"]
                KA_M["Keepalived<br/>(MASTER · priority 100)"]
                HP_M["HAProxy"]
            end
            subgraph SLAVE["lb-slave · 192.168.50.212"]
                KA_S["Keepalived<br/>(BACKUP · priority 90)"]
                HP_S["HAProxy"]
            end
            VIP["⭐ VIP: 192.168.50.250<br/>(平時綁在 Master)"]
        end
    end

    Backend1["Backend Server 1"]
    Backend2["Backend Server 2"]

    Client -->|"連線到 VIP :80"| VIP
    VIP --> HP_M
    HP_M --> Backend1
    HP_M --> Backend2
    KA_M <-->|"VRRP 心跳 (multicast)"| KA_S
    KA_M -->|"持有 VIP"| VIP
```

## VRRP 協定原理

**VRRP（Virtual Router Redundancy Protocol）** 是一種讓多台機器共用一個虛擬 IP 的協定。

```mermaid
sequenceDiagram
    participant M as lb-master
    participant S as lb-slave
    participant VIP as VIP 192.168.50.250

    Note over M,S: 正常狀態
    M->>S: VRRP Advertisement (每1秒)
    M->>VIP: 持有 VIP (ARP binding)
    Note over S: 收到心跳，保持 BACKUP 狀態

    Note over M,S: Master 故障
    M--xS: 心跳中斷 (3秒後超時)
    S->>S: 等待 Master Down Interval
    S->>VIP: 搶佔 VIP (Gratuitous ARP)
    Note over S: 升為 MASTER

    Note over M,S: Master 恢復
    M->>M: 重啟 Keepalived
    M->>S: 發送高優先級 Advertisement
    S->>S: 降回 BACKUP
    M->>VIP: 重新持有 VIP (preempt)
```

## Active-Standby vs Active-Active

| 模式 | 說明 | 本實驗 |
|------|------|--------|
| **Active-Standby** | 同時只有一台工作，另一台待命 | ✅ 使用此模式 |
| Active-Active | 兩台同時服務，需要 ECMP 或 DNS 輪詢 | 較複雜，進階主題 |

## 元件角色分工

```mermaid
graph LR
    subgraph "每台 VM 上的元件"
        KA["Keepalived<br/>━━━━━━━━━━━<br/>• 管理 VIP 歸屬<br/>• VRRP 心跳<br/>• 監控 HAProxy 健康<br/>• 自動 failover"]
        HP["HAProxy<br/>━━━━━━━━━━━<br/>• 接收流量<br/>• 負載分發<br/>• 健康檢查後端<br/>• Stats 儀表板"]
        KA -->|"HAProxy 掛掉時<br/>降低優先級觸發切換"| HP
    end
```

### Keepalived 負責
- 透過 **VRRP** 在兩台機器間協商 VIP 歸屬
- 監控本機 HAProxy 是否存活（`vrrp_script`）
- HAProxy 死掉時自動降低 priority，觸發 VIP 漂移到 Slave

### HAProxy 負責
- 接收到達 VIP 的流量
- 根據設定的演算法（Round Robin / Least Conn 等）分發到後端
- 對後端做健康檢查，自動移除掛掉的後端

## 故障切換流程

```mermaid
flowchart TD
    A["Master 正常運行<br/>VIP: 192.168.50.250 在 Master"] --> B{Master 故障?}
    B -->|No| A
    B -->|Yes| C["Slave 偵測到心跳中斷<br/>(Master Down Interval: ~3秒)"]
    C --> D["Slave 發送 Gratuitous ARP<br/>宣告自己持有 VIP"]
    D --> E["網路設備更新 ARP 表"]
    E --> F["新連線導向 Slave 的 HAProxy"]
    F --> G{Master 恢復?}
    G -->|No| F
    G -->|Yes| H["Master 重新廣播高優先級 VRRP"]
    H --> I["Slave 釋放 VIP"]
    I --> A
```

## IP 規劃總結

| 用途 | IP | 備註 |
|------|----|------|
| lb-master 固定 IP | `192.168.50.211` | VM 靜態 IP，永遠存在 |
| lb-slave 固定 IP | `192.168.50.212` | VM 靜態 IP，永遠存在 |
| VIP（虛擬 IP） | `192.168.50.250` | 會在兩台間漂移 |
| Mac mini（Host） | `192.168.50.x` | 你的 Mac mini 實際 IP |
