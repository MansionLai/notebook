---
title: Load Balancer
nav_order: 6
has_children: true
permalink: /load-balancer/
---

# Load Balancer 高可用實驗室

在 Mac mini 上使用 Multipass 創建兩台 VM，實作 **Keepalived + HAProxy** 的 Active-Standby 高可用負載均衡架構。

## 📚 文檔結構

| 文件 | 內容 |
|------|------|
| [架構概覽](./architecture) | VRRP 原理、VIP 漂移機制、整體設計 |
| [VM 環境搭建](./vm-setup) | Multipass 建立兩台 VM、設定固定 IP |
| [Keepalived 配置](./keepalived-config) | Master/Slave VRRP 設定、健康檢查 |
| [HAProxy 配置](./haproxy-config) | 前端/後端配置、stats 頁面 |
| [故障切換測試](./failover-testing) | 驗證 VIP 漂移、切換時間量測 |

## 🏗️ 環境規劃

| 角色 | VM 名稱 | IP | 說明 |
|------|---------|-----|------|
| Master | lb-master | `192.168.50.211` | 正常情況持有 VIP |
| Slave | lb-slave | `192.168.50.212` | Master 故障時接管 |
| VIP | — | `192.168.50.250` | 對外服務的浮動 IP |

## 🎯 學習目標

- 理解 VRRP 協定和 Keepalived 工作原理
- 學會在 Mac mini 上用 Multipass 建立橋接網路 VM
- 掌握 HAProxy 基本配置
- 實際演練故障切換流程
