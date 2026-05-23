---
title: Folder Spec
parent: Storage
nav_order: 0
permalink: /storage/spec/
---

# Storage Folder Spec (Master)

最後更新：2026-05-22

## 1. Scope

這份 `storage/spec.md` 是總覽規格，聚焦三個專案：

1. `3node-ceph`
2. `ceph-cross-dc-migration`
3. `ceph-mcp-server`

各專案詳細規格已拆到子資料夾內各自的 `spec.md`。

## 2. Working Rules

1. AI agent 在 Mac mini 上協作維護 notebook repo，主要 focus 在 `storage/` 與 Ceph 相關內容。
2. 變更流程：由 `main` 切出 `ai/ceph` 分支進行修正，確認後再合併回 `main`。
3. 文件優先：所有架構、流程與自動化調整，需先反映在對應專案 spec。

## 3. Project Map

| Project | Purpose | Detail Spec |
|---|---|---|
| `3node-ceph` | Azure 上 3 節點 Ceph lab（安裝、自動化、觀測） | `storage/3node-ceph/spec.md` |
| `ceph-cross-dc-migration` | Ceph 跨資料中心遷移設計與 runbook | `storage/ceph-cross-dc-migration/spec.md` |
| `ceph-mcp-server` | Copilot CLI 使用 local(stdio) 連接 Ceph MCP Server | `storage/ceph-mcp-server/spec.md` |

## 4. Current Environment Snapshot

以目前可驗證狀態為準：

1. Ceph cluster health: `HEALTH_OK`
2. OSD 數量：`6`（osd.0 ~ osd.5）

## 5. Maintenance Principle

1. 共通規範放在本檔（Master）。
2. 專案需求、參數、步驟、驗收條件放在各專案 `spec.md`。
3. 專案調整時，先改子 spec；若影響共通規範，再同步更新本檔。