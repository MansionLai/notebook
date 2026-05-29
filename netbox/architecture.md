---
title: Netbox 架構詳解
parent: Netbox
nav_order: 1
---

# Netbox 架構詳解

> **Profile 標籤**
> - **Minimal local-lab profile**：本地最小化部署請先遵循 [`deployment-steps.md`](./deployment-steps.md) 的精簡參數與 [`README.md`](./README.md) 的最小 VM sizing。  
> - **HA/production profile**：本文中的多副本與高可用架構段落屬於 HA/production 設計導向。  
> ⚠️ 若採最小 VM 規格，請使用 `deployment-steps.md` 的降配設定，勿直接套用 HA 預設。

## 概述

Netbox 是一個網絡資源管理系統（Network Resource Management Platform），用於管理和文檔化網絡基礎設施。本文檔詳細介紹 Netbox 的系統架構和各個組件的角色。

## 系統架構層次

```
┌─────────────────────────────────────────┐
│         用戶界面層 (Presentation)        │
│   Web UI + REST API + GraphQL API      │
├─────────────────────────────────────────┤
│       業務邏輯層 (Application)          │
│  Netbox Core Service + WebServer       │
│  • 用戶認證和授權                       │
│  • 業務規則和工作流                     │
│  • 緩存層（Redis）                      │
├─────────────────────────────────────────┤
│         數據存儲層 (Data)                │
│  PostgreSQL Database                   │
│  • 設備信息                             │
│  • 網絡拓撲                             │
│  • 用戶和權限數據                       │
└─────────────────────────────────────────┘
```

## 核心組件詳解

### 1. Netbox Web Server 和 API

**責任:**
- 提供 Web 用戶界面（Django-based）
- 提供 REST API 和 GraphQL API
- 處理用戶認證和授權
- 執行業務邏輯驗證

**在 K8s 中的部署:**
```
Netbox Deployment (3 replicas)
├── Pod 1 (Netbox Container)
├── Pod 2 (Netbox Container)
└── Pod 3 (Netbox Container)
```

**依賴:**
- PostgreSQL（數據庫）
- Redis（會話和緩存）

**性能特性:**
- Stateless（無狀態），支持水平擴展
- 支持多副本負載均衡
- 副本之間共享 PostgreSQL 和 Redis

### 2. PostgreSQL 數據庫

**責任:**
- 持久化存儲所有 Netbox 數據
- 管理用戶、設備、IP、電路等信息
- 支持複雜的 SQL 查詢

**在 K8s 中的部署:**
```
PostgreSQL StatefulSet (1 primary + 2 replicas)
├── Pod 0 - Primary (read/write)
├── Pod 1 - Replica (read-only)
└── Pod 2 - Replica (read-only)
```

**持久化存儲:**
- 每個 Pod 連接 PersistentVolume
- StatefulSet 保證 Pod 身份穩定
- 數據在 Pod 重啟後保留

### 3. Redis 緩存層

**責任:**
- 存儲 Netbox 用戶會話
- 緩存頻繁訪問的數據
- 提高應用性能

**在 K8s 中的部署:**
```
Redis Deployment (3 replicas)
├── Pod 1 - Redis Instance
├── Pod 2 - Redis Instance
└── Pod 3 - Redis Instance
```

## 數據流和通信機制

### 用戶請求流程

```
User (Web Browser / API Client)
    │
    ▼
Kubernetes Service (ClusterIP or NodePort)
    │
    ├─► Netbox Pod 1
    ├─► Netbox Pod 2
    └─► Netbox Pod 3
        │
        ├──────────────────────┬──────────────────────┐
        ▼                      ▼                      ▼
    PostgreSQL             Redis                (其他服務)
    Primary Pod            Replicas
    (read/write)           (session/cache)
```

## 副本和高可用設計

### Netbox Pod 副本 (3)

```
優勢:
✓ 負載均衡 — 平均分散用戶請求
✓ 故障轉移 — 1 個 Pod 故障，另外 2 個繼續服務
✓ 滾動更新 — 更新期間無中斷

Kubernetes 通過 Deployment 自動管理:
- Pod 健康檢查 (readiness/liveness probes)
- 故障 Pod 自動重啟
- 版本更新時的滾動部署
```

### PostgreSQL 主從複製 (1 + 2)

```
主節點 (Primary)
  │ 流複製
  ├──► 從節點 1 (Replica)
  └──► 從節點 2 (Replica)

優勢:
✓ 讀操作分散 — 從節點可處理讀請求
✓ 備份 — 從節點可作為備份源
✗ 寫操作集中 — 所有寫入仍通過主節點
```

## 網絡通信設計

### Service 類型

```
Netbox Service
├── Type: ClusterIP (內部) 或 NodePort (外部)
├── Port: 8001 (HTTP)
└── Selector: app=netbox

PostgreSQL Service
├── Type: ClusterIP
├── Port: 5432
└── Selector: app=postgresql

Redis Service
├── Type: ClusterIP
├── Port: 6379
└── Selector: app=redis
```

## 下一步

閱讀 [multipass-k3s-setup.md](./multipass-k3s-setup.md) 了解如何構建基礎設施。
