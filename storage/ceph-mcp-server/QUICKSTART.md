# Ceph MCP Server 快速參考

## 📦 安裝（第一次）

```bash
# 1. 進入資料夾
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# 2. Clone 源代碼
git clone https://github.com/rajmohanram/ceph-mcp-server.git src
cd src

# 3. 安裝依賴
uv sync

# 4. 回到上級目錄，設定環境
cd ..
cp src/.env.example .env
nano .env  # 填寫 CEPH_MANAGER_URL、CEPH_USERNAME、CEPH_PASSWORD

# 5. 驗證連線
source .env
curl -k -u $CEPH_USERNAME:$CEPH_PASSWORD $CEPH_MANAGER_URL/api/v1/health
```

## 🚀 啟動 MCP Server

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
source ../.env
uv run python -m ceph_mcp.server
```

## 🔧 常用命令

### 開發模式（DEBUG 日誌）

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
source ../.env
LOG_LEVEL=DEBUG uv run python -m ceph_mcp.server
```

### 執行測試

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run pytest -v
```

### 程式碼格式化

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run black src/ tests/
uv run isort src/ tests/
```

### 程式碼品質檢查

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run ruff check src/ tests/
uv run mypy src/
```

## ⚠️ 常見問題快速修復

| 問題 | 快速修復 |
|------|--------|
| `Connection refused` | 檢查 `curl -k $CEPH_MANAGER_URL` 是否可達 |
| `Unauthorized 401` | 驗證 `.env` 中的密碼：`curl -k -u admin:$CEPH_PASSWORD $CEPH_MANAGER_URL/api/v1/health` |
| `SSL verification failed` | 確認 `.env` 中 `CEPH_SSL_VERIFY=false` |
| `Python version error` | 更新 Python：`brew install python@3.13` |
| `Module not found` | 重新同步：`uv sync --fresh` |

## 📚 文檔

- **[README.md](README.md)** - 完整安裝指南
- **[troubleshooting.md](troubleshooting.md)** - 故障排除
- **[COPILOT_INTEGRATION.md](COPILOT_INTEGRATION.md)** - Copilot 整合配置
- **.env.example** - 環境變數範本

## 🧪 驗證步驟

```bash
# Step 1: 檢查 Python
python3 --version  # 需要 ≥3.11

# Step 2: 檢查 uv
uv --version

# Step 3: 測試 Ceph 連線
source .env
curl -k -u $CEPH_USERNAME:$CEPH_PASSWORD \
  $CEPH_MANAGER_URL/api/v1/health

# Step 4: 啟動 MCP Server
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
uv run python -m ceph_mcp.server

# 預期看到: "Server is ready for connections"
```

## 🔑 關鍵文件位置

- MCP Server 源代碼：`~/Documents/copilot/notebook/storage/ceph-mcp-server/src/`
- 環境設定檔：`~/Documents/copilot/notebook/storage/ceph-mcp-server/.env`
- 設定檔範本：`~/Documents/copilot/notebook/storage/ceph-mcp-server/.env.example`

## 💡 Tips

1. **首次啟動可能較慢** - Ceph 連線建立時間
2. **使用環境變數代替硬編碼密碼** - 安全性考慮
3. **Lab 環境可禁用 SSL 驗證** - `CEPH_SSL_VERIFY=false`
4. **生產環境需啟用 SSL** - `CEPH_SSL_VERIFY=true` + 提供 CA 證書
5. **查看日誌找出問題** - `LOG_LEVEL=DEBUG`
