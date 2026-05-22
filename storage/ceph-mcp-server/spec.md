---
title: Ceph MCP Server Spec
parent: Storage
nav_exclude: true
permalink: /storage/ceph-mcp-server/spec/
---

# ceph-mcp-server Spec

最後更新：2026-05-22

## 1. Goal

在 **Ceph MON node** 直接部署 upstream `ceph-mcp-server`，以 `streamable-http` 對外提供 `tcp/8000`，並讓 **Mac mini Copilot CLI** 透過 **public IP** 串接。

## 2. Deployment Baseline

1. 上游來源：`https://github.com/rajmohanram/ceph-mcp-server.git`
2. MON node 目錄：`~/ceph-mcp-server/app`
3. 執行環境：`uv` + 專案 `.venv`
4. 敏感資訊：`~/ceph-mcp-server/.env`
5. 啟動方式：`systemd` 常駐服務 `ceph-mcp.service`

## 3. Runtime Configuration

必要環境變數：

1. `CEPH_MANAGER_URL`
2. `CEPH_USERNAME`
3. `CEPH_PASSWORD`
4. `CEPH_SSL_VERIFY`
5. `MCP_SERVER_VERSION`
6. `SERVER_HOST=0.0.0.0`
7. `SERVER_PORT=8000`

Copilot CLI 需用 remote MCP（HTTP）：

1. `copilot mcp add --transport http ceph-mcp http://<MON_PUBLIC_IP>:8000/mcp`
2. 若反代啟用 TLS，改為 `https://<FQDN>/mcp`

## 4. MCP Transport Requirement

1. 以 upstream 現況為準：`transport="streamable-http"`
2. endpoint path 為 `/mcp`
3. 本版不採用 local stdio 模式

## 5. Current Recognized State

1. 部署目標：MON node 開 `tcp/8000`
2. 客戶端目標：Mac mini Copilot CLI 經 public IP 連入
3. 優先策略：維持單機（不新增 VM）

## 6. Port Collision Check (Required)

檢查命令：

1. `ss -ltnp | egrep ':(8000|3300|6789|8443|6800)\b'`
2. `sudo lsof -iTCP:8000 -sTCP:LISTEN -n -P`

判斷：

1. Ceph 常見埠不含 `8000`（多為 `3300/6789/8443/6800+`）
2. 若 `8000` 已被其他服務占用，需改埠（例如 `18000`）並同步調整 Copilot URL

## 7. Known Failure Patterns

1. `MCP error -32000: Connection closed`
   - 常見根因：public IP 不通、ACL/防火牆阻擋、service 未啟動
2. `HTTP timeout / connection refused`
   - 常見根因：`SERVER_HOST` 綁定錯誤、`8000` 未開放、service crash
3. `401/403`（若前面加了反代驗證）
   - 常見根因：header/token 未帶入 Copilot MCP config

## 8. Security Baseline

1. 僅允許 Mac mini 公網 IP 連 `8000/tcp`
2. 避免 `0.0.0.0:8000` 全網開放且無 ACL
3. 長期運行建議加 TLS 反向代理（Nginx/Caddy）與驗證標頭

## 9. Reference

1. `storage/ceph-mcp-server/README.md`
2. `https://github.com/rajmohanram/ceph-mcp-server.git`
