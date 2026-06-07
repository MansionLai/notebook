---
title: Netbox
nav_order: 5
has_children: true
permalink: /netbox/
---

# Netbox Azure VM 3 節點部署指南

在 Azure VM 上使用 3-node K3s + Helm chart 進行 NetBox、PostgreSQL、Redis 的部署指南。所有基礎設施範例統一使用 resource group `mansion_k3s_netbox`。

## 📚 文檔結構

本指南分為以下部分，建議按順序閱讀：

### 1. [Netbox 架構詳解](./architecture.md)
- Netbox 核心系統架構（UI層、業務邏輯層、數據層）
- PostgreSQL 和 Redis 的角色
- 整體數據流和通信機制
- 架構圖和流程圖

### 2. [Azure VM + K3s 基礎設施搭建](./azure-vm-k3s-setup.md)
- 在 Azure VM 上創建 3 個 Ubuntu VM
- 初始化 K3s 1 control plane + 2 worker 叢集
- 驗證叢集健康狀態
- Azure VM 叢集拓撲圖

### 3. [完整部署步驟](./deployment-steps.md)
- 官方 Netbox Helm chart 結構解析
- 逐步部署 Netbox Helm chart
- 部署 PostgreSQL StatefulSet
- 部署 Redis 緩存層
- 驗證所有 pod 狀態
- 配置 port-forward 訪問 NetBox UI（8080；若從 VM 外部連線需先放行 NSG）

### 4. [配置參考表](./configuration-reference.md)
- NetBox pod 完整配置選項
- PostgreSQL StatefulSet 配置
- Redis 配置
- 網絡和存儲配置
- 適合作為速查手冊

### 5. [故障排查指南](./troubleshooting.md)
- 常見部署問題和解決方案
- Pod 日誌查詢方法
- 數據庫連接診斷
- Redis 緩存驗證
- 性能監控和優化建議

### 6. [備份與災難復原](./backup_and_disaster_recovery.md)
- NetBox 備份策略
- 災難復原流程
- 恢復測試與自動化建議

## 🎯 學習路線圖

建議按以下方式使用本指南：

| 階段 | 時間 | 學習目標 | 對應文檔 |
|------|------|---------|---------|
| 1. 基礎設施 | 第 1-3 天 | 理解 Azure VM 與 K3s 叢集 | azure-vm-k3s-setup.md |
| 2. 部署與驗證 | 第 4-7 天 | 掌握 Helm 結構、完成部署與驗證 | deployment-steps.md, troubleshooting.md |
| 3. 文檔精通 | 第 8+ 天 | 精熟配置選項，可向同事介紹 | architecture.md, configuration-reference.md |


## 🏗️ 系統要求

- **Azure subscription**
- **Azure VM** 3-node K3s cluster
- **K3s** (lightweight Kubernetes)
- **Helm 3** (package manager for Kubernetes)
- **kubectl** (Kubernetes CLI)
- **管理機 / jumpbox**：可 SSH 與執行 `kubectl`、`helm`
- **Azure VM 叢集建議**：control plane `2C/4G/64G`，兩台 workers 各 `2C/4G/64G`

## 📊 核心圖表

本指南包含以下圖表幫助理解系統：

- **架構圖** — Azure VM 3 節點 K3s 叢集和 pod 分布
- **數據流圖** — Netbox、PostgreSQL、Redis 的通信
- **Helm 部署流程** — Chart 到 Kubernetes resources 的轉換
- **故障處置機制圖** — Azure VM 與 K8s 服務恢復流程
- **配置參考表** — 所有重要設置的快速查詢

---

**最後更新:** 2026-05-29  
**作者:** @MansionLai  
**版本:** 1.0
