# Copilot Ceph MCP 整合（Local / stdio）

## 推薦方式：Copilot CLI local(stdio)

此方式由 Copilot 直接啟動 `ceph-mcp-server` 子程序，不使用 HTTP/SSE。

### 1) 準備 `.env`

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
nano .env
```

至少確認：

```bash
CEPH_MANAGER_URL=https://20.89.53.16:8443
CEPH_USERNAME=admin
CEPH_PASSWORD=<your-password>
CEPH_SSL_VERIFY=false
MCP_SERVER_VERSION=0.1.0
```

### 2) 新增 local MCP server

```bash
# 若先前有 sse 版本，先移除
copilot mcp remove ceph-mcp

# 新增 local(stdio) server
copilot mcp add ceph-mcp -- bash -lc \
  'cd /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src && \
   set -a && source ../.env && set +a && \
   uv run ceph-mcp-server'
```

### 3) 驗證配置

```bash
copilot mcp list
copilot mcp get ceph-mcp
```

預期：

- `ceph-mcp (local)`
- `Type: local`

---

## 備援方式：手動編輯 `~/.copilot/mcp-config.json`

```json
{
  "mcpServers": {
    "ceph-mcp": {
      "type": "local",
      "command": "bash",
      "args": [
        "-lc",
        "cd /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src && set -a && source ../.env && set +a && uv run ceph-mcp-server"
      ],
      "tools": [
        "*"
      ]
    }
  }
}
```

---

## 常用命令

```bash
# 查看所有 MCP servers
copilot mcp list

# 查看 ceph-mcp 詳情
copilot mcp get ceph-mcp

# 刪除 ceph-mcp
copilot mcp remove ceph-mcp
```

---

## 常見問題

### 1) `copilot mcp list` 沒看到 ceph-mcp

- 先執行 `copilot mcp add ...`（不是 `/mcp show`）
- 再執行 `copilot mcp list`

### 2) 認證失敗（401）

先驗證 Ceph API auth：

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
source .env
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"
```

### 3) 連線逾時

- 確認 Azure NSG 已允許 Mac mini 公網 IP 連到 8443
- 確認 `.env` 內 `CEPH_MANAGER_URL` 使用可連線位址（例如 `https://20.89.53.16:8443`）

