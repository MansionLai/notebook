# Copilot MCP Server 配置範本

## 方式 1：JSON 配置（推薦用於 Claude Code / Copilot CLI）

若 GitHub Copilot CLI 支援 MCP 伺服器配置，編輯 `~/.copilot/mcp.json`：

```json
{
  "mcpServers": {
    "ceph": {
      "command": "uv",
      "args": [
        "run",
        "--with-editable",
        "/Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src",
        "python",
        "-m",
        "ceph_mcp.server"
      ],
      "env": {
        "CEPH_MANAGER_URL": "https://10.10.10.21:8443",
        "CEPH_USERNAME": "admin",
        "CEPH_PASSWORD": "${VAULT_CEPH_PASSWORD}",
        "CEPH_SSL_VERIFY": "false",
        "LOG_LEVEL": "INFO"
      }
    }
  }
}
```

### 配置說明

- **command**: `uv` - 使用 UV 作為執行器
- **args**: 
  - `run` - 執行 Python 模組
  - `--with-editable` - 支援開發模式編輯
  - 路徑指向 ceph-mcp-server 源代碼
  - `python -m ceph_mcp.server` - 啟動 MCP Server
- **env**: 
  - `CEPH_MANAGER_URL` - Ceph Manager API 端點
  - `CEPH_PASSWORD` - 使用環境變數（勿直接寫密碼）
  - `CEPH_SSL_VERIFY` - Lab 環境設置為 false

---

## 方式 2：Shell 腳本包裝

建立 `~/.local/bin/ceph-mcp-server.sh`：

```bash
#!/bin/bash
set -e

# Ceph MCP Server 啟動腳本

CEPH_MCP_HOME="/Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server"

# 檢查目錄是否存在
if [ ! -d "$CEPH_MCP_HOME" ]; then
    echo "ERROR: Ceph MCP Server directory not found: $CEPH_MCP_HOME"
    exit 1
fi

# 切換到源代碼目錄
cd "$CEPH_MCP_HOME/src"

# 載入環境變數
if [ -f "$CEPH_MCP_HOME/.env" ]; then
    source "$CEPH_MCP_HOME/.env"
else
    echo "ERROR: .env file not found at $CEPH_MCP_HOME/.env"
    exit 1
fi

# 驗證必要的環境變數
if [ -z "$CEPH_MANAGER_URL" ]; then
    echo "ERROR: CEPH_MANAGER_URL not set"
    exit 1
fi

if [ -z "$CEPH_USERNAME" ]; then
    echo "ERROR: CEPH_USERNAME not set"
    exit 1
fi

if [ -z "$CEPH_PASSWORD" ]; then
    echo "ERROR: CEPH_PASSWORD not set"
    exit 1
fi

# 啟動 MCP Server
exec uv run python -m ceph_mcp.server
```

### 使用方式

```bash
# 賦予執行權限
chmod +x ~/.local/bin/ceph-mcp-server.sh

# 在 Copilot 配置中使用
# command: ~/.local/bin/ceph-mcp-server.sh
```

---

## 方式 3：Docker 容器（可選）

若要在容器中執行 MCP Server，建立 `Dockerfile`：

```dockerfile
FROM python:3.13-slim

WORKDIR /app

# 安裝 uv
RUN pip install --no-cache-dir uv

# 複製 ceph-mcp-server
COPY src /app/src
WORKDIR /app/src

# 安裝依賴
RUN uv sync

# 設定環境變數
ENV CEPH_SSL_VERIFY=false
ENV LOG_LEVEL=INFO

# 暴露 MCP 伺服器埠（如果適用）
# EXPOSE 8000

# 啟動 MCP Server
CMD ["uv", "run", "python", "-m", "ceph_mcp.server"]
```

### 構建與執行

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# 構建 Docker 映像
docker build -t ceph-mcp-server:latest .

# 執行容器（傳入 .env 變數）
docker run --rm \
  -e CEPH_MANAGER_URL=https://10.10.10.21:8443 \
  -e CEPH_USERNAME=admin \
  -e CEPH_PASSWORD=$CEPH_PASSWORD \
  -e CEPH_SSL_VERIFY=false \
  ceph-mcp-server:latest
```

---

## 方式 4：系統服務（生產環境）

建立 systemd 服務單位 `~/.config/systemd/user/ceph-mcp-server.service`：

```ini
[Unit]
Description=Ceph MCP Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=mansionlai
WorkingDirectory=/Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server
EnvironmentFile=/Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/.env
ExecStart=/usr/local/bin/uv run python -m ceph_mcp.server
Restart=on-failure
RestartSec=10

# 日誌
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ceph-mcp

[Install]
WantedBy=default.target
```

### 啟用服務

```bash
# 重新載入 systemd
systemctl --user daemon-reload

# 啟動服務
systemctl --user start ceph-mcp-server

# 設定開機自啟
systemctl --user enable ceph-mcp-server

# 查看狀態
systemctl --user status ceph-mcp-server

# 查看日誌
journalctl --user -u ceph-mcp-server -f
```

---

## 環境變數管理

### 方法 A：`.env` 檔案

```bash
# 在 $CEPH_MCP_HOME/.env 中設定
CEPH_MANAGER_URL=https://10.10.10.21:8443
CEPH_USERNAME=admin
CEPH_PASSWORD=actual_password
CEPH_SSL_VERIFY=false
```

### 方法 B：系統環境變數

```bash
# 在 ~/.bashrc 或 ~/.zshrc 中
export CEPH_MANAGER_URL=https://10.10.10.21:8443
export CEPH_USERNAME=admin
export CEPH_PASSWORD=actual_password
export CEPH_SSL_VERIFY=false

# 重新載入
source ~/.bashrc
```

### 方法 C：密鑰管理系統（推薦生產環境）

使用 HashiCorp Vault、AWS Secrets Manager 或類似服務：

```bash
# 從 Vault 取得密碼
export CEPH_PASSWORD=$(vault kv get -field=password secret/ceph/admin)

# 啟動 MCP Server
uv run python -m ceph_mcp.server
```

### 方法 D：Ansible Vault 整合

```bash
# 在 ceph-mcp-server 啟動前自動解密
cd ~/Documents/copilot/notebook/storage/3node-ceph/ansible

CEPH_PASSWORD=$(ansible-vault view inventory/group_vars/encrypted.yml | \
  grep vault_ceph_dashboard_password | cut -d':' -f2 | xargs)

export CEPH_PASSWORD

# 啟動 MCP Server
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run python -m ceph_mcp.server
```

---

## 安全最佳實踐

### ✅ 推薦

- ☑️ 將 `.env` 加入 `.gitignore`
- ☑️ 使用環境變數而非硬編碼密碼
- ☑️ 使用專用的 Ceph 服務帳號（而非 admin）
- ☑️ 生產環境啟用 SSL 驗證
- ☑️ 定期輪換密碼
- ☑️ 監控 MCP Server 日誌
- ☑️ 限制 MCP Server 的網路訪問

### ❌ 應避免

- ❌ 將密碼提交到 Git
- ❌ 使用根賬戶或 admin 帳號
- ❌ 禁用 SSL 驗證於生產環境
- ❌ 將敏感日誌輸出到控制台
- ❌ 允許不受限的外部訪問

---

## 測試配置

### 驗證 MCP Server 連線

```bash
# 1. 手動啟動 MCP Server
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run python -m ceph_mcp.server

# 2. 在另一個終端測試
curl -k -u admin:password https://10.10.10.21:8443/api/v1/health

# 3. 查看 MCP Server 日誌是否有回應
```

### 測試 Copilot 整合

```bash
# 1. 啟動 Copilot CLI
copilot

# 2. 測試 Ceph MCP 工具
ask: "檢查 Ceph 集群狀態"

# 預期看到來自 MCP Server 的回應
```

---

## 調試與開發

### 啟用詳細日誌

```bash
LOG_LEVEL=DEBUG uv run python -m ceph_mcp.server
```

### 執行單位測試

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run pytest -v
```

### 執行集成測試

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run pytest -m "integration" -v
```

---

## 相關資源

- [Ceph MCP Server README](../README.md)
- [故障排除指南](../troubleshooting.md)
- [Model Context Protocol 文件](https://modelcontextprotocol.io/)
- [GitHub Copilot 文件](https://docs.github.com/en/copilot)
