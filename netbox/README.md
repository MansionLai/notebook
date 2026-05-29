---
title: Netbox
nav_order: 5
has_children: true
permalink: /netbox/
---

# Netbox 本地實驗 3 節點部署指南

在 Mac-mini 上使用 Multipass + K3s + Helm chart 進行 Netbox、PostgreSQL、Redis 的本地開發/測試（local-lab）部署指南。

## 📚 文檔結構

本指南分為以下部分，建議按順序閱讀：

### 1. [Netbox 架構詳解](./architecture.md)
- Netbox 核心系統架構（UI層、業務邏輯層、數據層）
- PostgreSQL 和 Redis 的角色
- 整體數據流和通信機制
- 架構圖和流程圖

### 2. [Multipass + K3s 基礎設施搭建](./multipass-k3s-setup.md)
- 在 Mac-mini 上創建 3 個 Ubuntu VM
- 初始化 K3s 1 control plane + 2 worker 叢集
- 驗證叢集健康狀態
- K3s 叢集拓撲圖

### 3. [Helm Chart 深度指南](./helm-chart-guide.md)
- 官方 Netbox Helm chart 結構解析
- values.yaml 核心配置項詳解
- 副本數、資源限制、持久化存儲配置
- Helm 部署流程圖

### 4. [完整部署步驟](./deployment-steps.md)
- 逐步部署 Netbox Helm chart
- 部署 PostgreSQL StatefulSet
- 部署 Redis 緩存層
- 驗證所有 pod 狀態
- 配置 port-forward 訪問 Netbox UI

### 5. [配置參考表](./configuration-reference.md)
- Netbox pod 完整配置選項
- PostgreSQL StatefulSet 配置
- Redis 配置
- 網絡和存儲配置
- 適合作為速查手冊

### 6. [故障排查指南](./troubleshooting.md)
- 常見部署問題和解決方案
- Pod 日誌查詢方法
- 數據庫連接診斷
- Redis 緩存驗證
- 性能監控和優化建議

## 🎯 學習路線圖

建議按以下方式使用本指南：

| 階段 | 時間 | 學習目標 | 對應文檔 |
|------|------|---------|---------|
| 1. 基礎設施 | 第 1-3 天 | 理解 K3s 叢集和 Multipass | multipass-k3s-setup.md |
| 2. Helm 配置 | 第 4-6 天 | 掌握 Helm chart 結構和調整 | helm-chart-guide.md |
| 3. 部署驗證 | 第 7-9 天 | 完成部署和功能驗證 | deployment-steps.md, troubleshooting.md |
| 4. 文檔精通 | 第 10+ 天 | 精熟配置選項，可向同事介紹 | architecture.md, configuration-reference.md |

## 🏗️ 系統要求

- **Mac-mini** with macOS (tested on Monterey+)
- **Multipass** (lightweight VM manager)
- **K3s** (lightweight Kubernetes)
- **Helm 3** (package manager for Kubernetes)
- **kubectl** (Kubernetes CLI)
- **本地最小化安裝（local dev/test）**：3-node 預設規格為 control plane `2C/4G/20G`，兩台 workers 各 `1C/2G/15G`

## 📊 核心圖表

本指南包含以下圖表幫助理解系統：

- **架構圖** — 3 節點 K3s 叢集和 pod 分布
- **數據流圖** — Netbox、PostgreSQL、Redis 的通信
- **Helm 部署流程** — Chart 到 Kubernetes resources 的轉換
- **故障處置機制圖** — 本地實驗環境下的節點/服務恢復流程
- **配置參考表** — 所有重要設置的快速查詢

---

**最後更新:** 2026-05-29  
**作者:** @MansionLai  
**版本:** 1.0
