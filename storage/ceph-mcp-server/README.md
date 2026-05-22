---
title: Ceph MCP Server (MON node / Copilot remote)
parent: Storage
nav_order: 30
permalink: /storage/ceph-mcp-server/
---

# Ceph MCP Server（最精簡版）

目標：在 **Ceph MON node** 直接啟動上游 `ceph-mcp-server`（remote / streamable-http），讓 **Mac mini** 上的 Copilot CLI 透過 **public IP** 連入。

> 本文件以 upstream `https://github.com/rajmohanram/ceph-mcp-server.git` 為準。

## 1) 在 MON node 安裝上游專案

```bash
mkdir -p ~/ceph-mcp-server
cd ~/ceph-mcp-server
git clone https://github.com/rajmohanram/ceph-mcp-server.git app
cd app
uv sync
```

## 2) 建立 `.env`（MON node）

```bash
cd ~/ceph-mcp-server
cp app/.env.example .env
nano .env
```

至少填這些值：

```bash
CEPH_MANAGER_URL=https://<your-ceph-mgr-ip>:8443
CEPH_USERNAME=admin
CEPH_PASSWORD=<your-password>
CEPH_SSL_VERIFY=false
MCP_SERVER_VERSION=0.1.0
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
```

## 3) 先檢查 `8000/tcp` 是否碰撞

```bash
ss -ltnp | egrep ':(8000|3300|6789|8443|6800)\b' || true
sudo lsof -iTCP:8000 -sTCP:LISTEN -n -P || true
```

說明：

- Ceph 常見埠：MON `3300/6789`、Dashboard 常見 `8443`、OSD 常見 `6800+`。
- **`8000` 通常不是 Ceph 預設埠**，但仍要實查是否被其他服務占用。
- 若 `8000` 已被占用，改成其他埠（例如 `18000`），並同步更新後續指令中的 URL。

## 4) 驗證 Ceph 認證（MON node）

```bash
cd ~/ceph-mcp-server
source .env
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"
```

看到 `token` 代表認證成功。

## 5) 在 MON node 啟動 MCP（systemd）

建立 service：

```bash
sudo tee /etc/systemd/system/ceph-mcp.service >/dev/null <<'EOF'
[Unit]
Description=Ceph MCP Server (remote streamable-http)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/ceph-mcp-server/app
EnvironmentFile=/root/ceph-mcp-server/.env
ExecStart=/usr/bin/env bash -lc 'uv run ceph-mcp-server'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

啟用並啟動：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ceph-mcp
sudo systemctl status ceph-mcp --no-pager
```

## 6) MON node 開放來源（僅允許 Mac mini 公網 IP）

```bash
# UFW 範例
sudo ufw allow from <MAC_MINI_PUBLIC_IP> to any port 8000 proto tcp
sudo ufw status
```

若使用其他防火牆，請做等效白名單規則（不要對全網開放 `8000`）。

## 7) Mac mini 新增 Copilot remote MCP

```bash
copilot mcp remove ceph-mcp
copilot mcp add --transport http ceph-mcp http://<MON_PUBLIC_IP>:8000/mcp
```

如果你前面有加 TLS 反向代理，改用 `https://.../mcp`。

## 8) 驗證配置

```bash
copilot mcp list
copilot mcp get ceph-mcp
```

預期看到：

- `ceph-mcp (remote)`
- `Transport: http`

## 補充

- 這個 upstream 版本是 `streamable-http`，不是 local stdio。
- Public IP 直連可用，但建議最少做來源 IP 限制；若要長期使用，建議加 TLS/反代與認證標頭。 
