---
title: Ceph MCP Server (MON node / Copilot remote)
parent: Storage
nav_order: 30
permalink: /storage/ceph-mcp-server/
---

# Ceph MCP Server（最精簡版）

目標：在 **Ceph MON node** 直接啟動上游 `ceph-mcp-server`（remote / streamable-http），讓 **Mac mini** 上的 Copilot CLI 透過 **public IP** 連入。

> 本文件以 upstream `https://github.com/rajmohanram/ceph-mcp-server.git` 為準。

## 0) 先安裝 `uv` 包管理工具（MON node）

上游專案使用 `uv` 來管理 Python 依賴。請先安裝：

```bash
# Ubuntu/Debian 推薦做法
sudo apt-get update
sudo apt-get install -y python3-pip
pip install uv

# 或直接下載安裝
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**重要：配置 PATH**

`uv` 會被安裝到 `~/.local/bin`，需要確保它在 PATH 中：

```bash
# 檢查 PATH 是否包含 ~/.local/bin
echo $PATH | grep -q ".local/bin" && echo "✓ PATH is OK" || echo "✗ Need to add to PATH"

# 若不包含，則添加到 shell profile
# 選擇適合的選項（擇一執行）：

# Option A: 臨時生效（當前 session）
export PATH="$HOME/.local/bin:$PATH"

# Option B: 永久生效（推薦）- Ubuntu/bash 用戶
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Option C: 永久生效 - zsh 用戶
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

驗證安裝成功：

```bash
uv --version
# 應該看到版本號（例如 uv 0.11.x）
```

## 1) 在 MON node 安裝上游專案

```bash
mkdir -p ~/ceph-mcp-server
cd ~/ceph-mcp-server
git clone https://github.com/rajmohanram/ceph-mcp-server.git app
cd app
uv sync
```

## 2) 建立 `.env`（MON node）

### 獲取 Ceph Dashboard 密碼

Ceph 密碼存放在 **Mac mini 的 Ansible vault** 中。需要先在 Mac mini 解密獲取：

```bash
# Mac mini 上執行
cd storage/3node-ceph/ansible
ansible-vault view inventory/group_vars/all/encrypted.yml

# 找到 `vault_ceph_dashboard_password` 的值，例如：
# vault_ceph_dashboard_password: your-ceph-admin-password
```

或透過以下方法直接查看（如果有 vault 密碼）：

```bash
# 方法 1：直接查詢 vault 密鑰
cat storage/3node-ceph/ansible/.vault-pass  # 取得 vault 密碼

# 方法 2：透過 Ansible 命令查詢（無需互動）
cd storage/3node-ceph/ansible
ansible localhost -m debug -a "var=vault_ceph_dashboard_password" -e @inventory/group_vars/all/encrypted.yml
```

### 填寫 `.env` 文件

```bash
cd ~/ceph-mcp-server
cat > .env <<'EOF'
CEPH_MANAGER_URL=https://<your-ceph-mgr-ip>:8443
CEPH_USERNAME=admin
CEPH_PASSWORD=<從上面獲得的密碼>
CEPH_SSL_VERIFY=false
MCP_SERVER_VERSION=0.1.0
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
EOF

# 驗證
cat .env
```

備註：
- `CEPH_USERNAME` 預設是 `admin`
- `CEPH_MANAGER_URL` 是 Ceph 的 Dashboard URL（通常 `https://ceph-node-01:8443`）
- `CEPH_PASSWORD` 是從 Ansible vault 取得的 dashboard admin 密碼

## 3) 先檢查 `8000/tcp` 是否碰撞

```bash
ss -ltnp | egrep ':(8000|3300|6789|8443|6800)\b' || true
sudo lsof -iTCP:8000 -sTCP:LISTEN -n -P || true
```

說明：

- Ceph 常見埠：MON `3300/6789`、Dashboard 常見 `8443`、OSD 常見 `6800+`。
- **`8000` 通常不是 Ceph 預設埠**，但仍要實查是否被其他服務占用。
- 若 `8000` 已被占用，改成其他埠（例如 `18000`），並同步更新後續指令中的 URL。

## 4) 診斷 Ceph Dashboard 帳戶（MON node）

**重要：在確認密碼是否正確前，請先診斷 Ceph dashboard 帳戶是否存在。**

在 **ceph-node-01** 上執行以下命令（需要 `sudo`）。Ceph 19.x 使用 **`ac-user-*`** 命令格式：

```bash
# 1. 列出所有 dashboard 帳戶
sudo ceph dashboard ac-user-list

# 2. 檢視 admin 帳戶詳細資訊
sudo ceph dashboard ac-user-show admin

# 3. 檢查 dashboard service 是否運行
sudo ceph orch ps --daemon-type mgr

# 4. 查看 MGR 日誌以了解問題
sudo ceph log last 50 mgr
```

### 預期輸出

若帳戶正確設置，應看到：

```bash
$ sudo ceph dashboard ac-user-list
admin

$ sudo ceph dashboard ac-user-show admin
# 會顯示帳戶信息
```

### 若帳戶不存在或密碼不對

可以重新設置或建立帳戶（密碼從 stdin 讀取）：

```bash
# 方法 1：設置 admin 帳戶密碼
echo "your-new-password" | sudo ceph dashboard ac-user-set-password admin

# 方法 2：若帳戶不存在，建立新帳戶
echo "your-new-password" | sudo ceph dashboard ac-user-create admin administrator

# 方法 3：使用 --force-password 強制設置
echo "your-new-password" | sudo ceph dashboard ac-user-set-password admin --force-password

# 確認帳戶已設置
sudo ceph dashboard ac-user-show admin
```

### 常見問題排查（Ceph 19.x）

| 錯誤 | 可能原因 | 解決方案 |
|---|---|---|
| `no valid command found` | 命令格式錯誤（如 `user-list` 應為 `ac-user-list`） | 使用正確格式：`sudo ceph dashboard ac-user-list` |
| `Permission denied` | 沒有 sudo 權限 | 改用 `sudo` 執行 |
| `Command not found` | Ceph 工具未安裝 | 確認 Phase 2 已完成，`ceph-common` 已安裝 |
| Dashboard 帳戶不存在 | 帳戶未被建立 | 使用 `echo "password" \| sudo ceph dashboard ac-user-create admin administrator` 建立 |
| 密碼錯誤 | Ansible vault 密碼與實際設置不同步 | 使用上面的命令重置密碼 |

## 4) 驗證 Ceph 認證（MON node）

```bash
cd ~/ceph-mcp-server
source .env

# 打印變數確認
echo "CEPH_MANAGER_URL=$CEPH_MANAGER_URL"
echo "CEPH_USERNAME=$CEPH_USERNAME"
echo "CEPH_PASSWORD=***" # 不打印實際密碼

# 測試連線和認證
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"
```

**成功的回應**應該看到 `token` 值：

```json
{
  "token": "eyJhbGc...",
  "username": "admin",
  "roles": ["administrator"],
  ...
}
```

**若看到 `invalid_credentials` 錯誤**，請檢查：

1. **Dashboard 帳戶是否存在** - 在 ceph-node-01 上執行：
   ```bash
   sudo ceph dashboard user-list
   sudo ceph dashboard user-show admin
   ```

2. **密碼是否正確** - 比較三個來源：
   - 從 `ansible-vault view inventory/group_vars/all/encrypted.yml` 看到的密碼
   - `.env` 文件中設置的密碼（確保無多餘空格）
   - Ceph 中實際儲存的密碼

3. **如果都不匹配，重置密碼**（在 ceph-node-01 上）：
   ```bash
   # 重置 admin 密碼
   sudo ceph dashboard user-set-password admin newpassword123
   
   # 或建立新帳戶
   sudo ceph dashboard user-create admin administrator
   
   # 確認已更新
   sudo ceph dashboard user-show admin
   
   # 然後更新 .env 並重新測試
   ```

4. **Dashboard 服務是否正常運行**：
   ```bash
   # 在 ceph-node-01 檢查
   sudo ceph orch ps --daemon-type mgr
   sudo ceph mgr module ls | grep -i dashboard
   ```

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
User=ubuntu
WorkingDirectory=/home/ubuntu/ceph-mcp-server/app
EnvironmentFile=/home/ubuntu/ceph-mcp-server/.env
ExecStart=/usr/bin/env bash -lc 'uv run ceph-mcp-server'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

**注意**：改成 `User=ubuntu`、`WorkingDirectory=/home/ubuntu/ceph-mcp-server/app`、`EnvironmentFile=/home/ubuntu/ceph-mcp-server/.env`（根據你實際的 username 和路徑調整）

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
