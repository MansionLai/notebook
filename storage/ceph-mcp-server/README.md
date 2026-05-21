---
title: Ceph MCP Server (Mac mini / Copilot stdio)
parent: Storage
nav_order: 30
permalink: /storage/ceph-mcp-server/
---

# Ceph MCP Server（最精簡版）

目標：在 **Mac mini** 上，讓 Copilot CLI 以 **local (stdio)** 方式新增 Ceph MCP Server（不使用 SSE）。

## 1) 一次性安裝

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
git clone https://github.com/rajmohanram/ceph-mcp-server.git src
cd src
uv sync
```

## 2) 建立 `.env`

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
cp src/.env.example .env
nano .env
```

至少填這些值：

```bash
CEPH_MANAGER_URL=https://20.89.53.16:8443
CEPH_USERNAME=admin
CEPH_PASSWORD=<your-password>
CEPH_SSL_VERIFY=false
MCP_SERVER_VERSION=0.1.0
```

## 3) 先驗證 Ceph 認證

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
source .env
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"
```

看到 `token` 代表認證成功。

## 4) 新增 Copilot local(stdio) MCP

```bash
copilot mcp remove ceph-mcp
copilot mcp add ceph-mcp -- bash -lc \
  'cd /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src && \
   set -a && source ../.env && set +a && \
   uv run ceph-mcp-server'
```

## 5) 驗證配置

```bash
copilot mcp list
copilot mcp get ceph-mcp
```

預期看到：

- `ceph-mcp (local)`
- `Type: local`

## 補充

- `src/` 與 `.env` 已在 `.gitignore`，不會被推送。
- 本資料夾僅保留最精簡文件流程。
