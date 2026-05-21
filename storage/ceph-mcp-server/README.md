---
title: Ceph MCP Server 安裝與設定
parent: Storage
nav_order: 30
permalink: /storage/ceph-mcp-server/
---

# Ceph MCP Server 安裝與設定

## 簡介

**Ceph MCP Server** 是一個 Model Context Protocol（MCP）服務器，讓 GitHub Copilot CLI 能夠通過自然語言與 Ceph 儲存集群互動，無需手動 SSH 執行 `ceph` 指令。

### 使用場景

```
使用者: "幫我檢查 Ceph 集群的健康狀況"
Copilot: (自動呼叫 MCP Server) → ceph -s → 解析結果 → 回報完整狀態
```

### 關鍵特性

- ✅ **自然語言查詢** - 用對話方式查詢 Ceph 狀態
- ✅ **遠程訪問** - 無需在 Ceph 節點上執行命令
- ✅ **安全認證** - Ceph Manager API 級別驗證
- ✅ **結構化輸出** - AI 友善的回應格式

---

## 前置條件

- Mac mini 已安裝 Python ≥3.11
- `uv` 套件管理工具
- Ceph 集群已部署並運行（Phase 3 已完成）
- Ceph Manager API 可從 Mac mini 訪問（公網 IP: `20.89.53.16:8443`）
- 有效的 Ceph 使用者帳號與密碼

### 驗證前置條件

```bash
# 檢查 Python 版本
python3 --version  # 需要 ≥3.11

# 檢查 uv 已安裝
uv --version

# 測試 Ceph Manager 可達性（替換為實際 IP）
curl -k https://20.89.53.16:8443/
```

---

## 安裝步驟

### 1️⃣ Clone Ceph MCP Server 源代碼

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# Clone 官方 repo 到 src/ 子目錄
git clone https://github.com/rajmohanram/ceph-mcp-server.git src
cd src
```

> ⚠️ **注意**：`src/` 目錄已被 `.gitignore` 忽略，不會被推送到 notebook repo。這是刻意設計，避免外部項目代碼混入版本控制。

### 2️⃣ 使用 uv 安裝依賴

```bash
# 在 src 目錄內
uv sync

# 驗證安裝
uv run ceph-mcp-server --help  # 如果有 help 選項
```

### 3️⃣ 準備環境設定檔

```bash
# 回到 ceph-mcp-server 資料夾
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# 複製環境變數範本
cp src/.env.example .env

# 編輯 .env，填入妳的 Ceph 集群資訊
# 參考下方「環境設定」一節
nano .env
```

### 4️⃣ 驗證 Ceph 連線

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# 直接測試認證（需要先設定 .env）
source .env
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"
```

預期看到類似：

```json
{
  "token": "eyJ..."
}
```

### 5️⃣ 啟動 MCP Server（測試）

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src

# 以 local(stdio) 方式運行（與 Copilot 實際執行模式一致）
set -a && source ../.env && set +a
uv run ceph-mcp-server
```

預期看到：

```
Starting Ceph MCP Server...
Connected to Ceph cluster successfully
Server is ready for connections
```

---

## 環境設定

### `.env` 檔案配置

根據實際 Ceph 集群填入以下值：

```bash
# Ceph Manager API 端點
# 格式: https://<public-ip>:8443
CEPH_MANAGER_URL=https://20.89.53.16:8443

# Ceph 使用者名稱
CEPH_USERNAME=admin

# Ceph 使用者密碼
# ⚠️ 建議使用 Ansible vault 中的密碼
# 可從 storage/3node-ceph/ansible/inventory/group_vars/encrypted.yml 取得
CEPH_PASSWORD=your_vault_ceph_dashboard_password

# SSL 驗證
# lab 環境設置為 false（自簽證書）
# 生產環境應設置為 true
CEPH_SSL_VERIFY=false

# 日誌級別
LOG_LEVEL=INFO

# API 請求限流（每分鐘最大請求數）
MAX_REQUESTS_PER_MINUTE=60
```

### 從 Ansible Vault 自動填充

若使用 Ansible vault 管理密碼：

```bash
cd storage/3node-ceph/ansible

# 解密並抽取 dashboard 密碼
ansible-vault view inventory/group_vars/encrypted.yml | grep vault_ceph_dashboard_password

# 複製密碼到 .env
```

---

## GitHub Copilot 整合

### 方式 1：Local (stdio) 配置（推薦）

使用 Copilot CLI 直接新增 local server（不走 SSE）：

```bash
# 建議先移除舊的 ceph-mcp 設定
copilot mcp remove ceph-mcp

# 新增 local(stdio) ceph-mcp
copilot mcp add ceph-mcp -- bash -lc \
  'cd /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src && \
   set -a && source ../.env && set +a && \
   uv run ceph-mcp-server'

# 驗證
copilot mcp list
copilot mcp get ceph-mcp
```

預期看到 `ceph-mcp (local)`。

### 方式 2：自定義腳本包裝

建立 `~/.local/bin/ceph-mcp-start.sh`：

```bash
#!/bin/bash
set -e

export CEPH_MCP_HOME="/Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server"
cd "$CEPH_MCP_HOME/src"

# 載入環境變數
source "$CEPH_MCP_HOME/.env"

# 啟動 MCP Server
uv run ceph-mcp-server
```

賦予執行權限：

```bash
chmod +x ~/.local/bin/ceph-mcp-start.sh
```

然後在 Copilot 設定中指向此腳本。

---

## 使用示例

### 查詢集群健康狀況

```
user@copilot> 幫我檢查 Ceph 集群健康狀況

Copilot: 正在查詢集群狀態...

✅ **集群健康狀態**
- 整體狀態：HEALTH_OK
- 在線主機：3/3
- OSD 狀態：6/6 up, 6/6 in
- Pool 數量：2 (system_pool, k8s_rbd_pool)
- 容量使用率：18.5%

🟢 無警告或錯誤信息
```

### 查詢主機詳情

```
user@copilot> 告訴我 ceph-node-01 的詳細資訊

Copilot: 查詢中...

🖥️ **ceph-node-01**
- 狀態：Online
- 服務：mon, mgr, osd.0, osd.1
- 資源：CPU: 4, RAM: 16GB
- 角色：Monitor, Manager, OSD Host
```

### 疑難排解

```
user@copilot> 我的 Ceph 集群有什麼警告？

Copilot: 掃描中...

🟡 **2 個警告**

1. **WARN_OSD_NEARFULL**
   - 1 個 OSD 接近滿載
   - 建議：增加存儲或刪除未使用數據

2. **WARN_POOL_BACKFILLFULL**
   - 1 個 pool 的 backfill 已滿
   - 建議：調整 pool 配置或增加 OSD
```

---

## 可用工具

MCP Server 提供 4 個主要工具：

| 工具 | 說明 | 用途 |
|------|------|------|
| `get_cluster_health` | 獲取集群整體健康狀況 | "集群怎樣？" |
| `get_host_status` | 列出所有主機狀態 | "哪些主機在線？" |
| `get_health_details` | 詳細的健康檢查訊息 | "集群有什麼警告？" |
| `get_host_details` | 查詢特定主機詳情 | "node-01 的配置？" |

---

## 開發與維護

### 本地開發模式

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src

# 以開發模式安裝（可編輯）
uv pip install -e .

# 運行開發伺服器
LOG_LEVEL=DEBUG uv run ceph-mcp-server
```

### 執行測試

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src

# 執行全部測試
uv run pytest

# 執行特定測試
uv run pytest tests/test_api.py -v

# 跳過集成測試
uv run pytest -m "not integration"
```

### 程式碼品質檢查

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src

# 格式化
uv run black src/ tests/
uv run isort src/ tests/

# Lint 檢查
uv run ruff check src/ tests/

# 型別檢查
uv run mypy src/

# 一鍵全檢
uv run ruff check src/ tests/ && uv run mypy src/ && uv run pytest
```

---

## 常見問題與排除

詳見 [troubleshooting.md](./troubleshooting.md)

### 快速檢查清單

- [ ] Python ≥3.11 已安裝
- [ ] `uv` 套件管理工具已安裝
- [ ] `.env` 已填寫正確的 Ceph 連線資訊
- [ ] Ceph Manager API 可從 Mac mini 訪問
- [ ] 環境變數已正確導出（`source .env`）
- [ ] 測試 curl 連線成功

---

## 後續步驟

1. ✅ 完成安裝與驗證
2. 🔄 在 Copilot 中整合 MCP Server
3. 🧪 測試自然語言查詢
4. 📊 監控使用情況與性能
5. 🔒 生產環境安全加固（SSL、防火牆等）

---

## Git 管理

### ✅ 被 Git 追蹤的檔案（會 Push 到 notebook repo）

- `README.md` - 安裝指南
- `QUICKSTART.md` - 快速參考
- `COPILOT_INTEGRATION.md` - Copilot 整合方法
- `troubleshooting.md` - 故障排除指南
- `.env.example` - 環境變數範本（不含密碼）
- `mcp.json.example` - Copilot local(stdio) 配置範本
- `index.md` - 文檔導覽

### ❌ 被 .gitignore 忽略的檔案（不會 Push）

- `src/` - Ceph MCP Server 源代碼（來自外部 repo）
- `.env` - 實際環境設定（含敏感資訊）

### 為什麼這樣設計？

1. **安全性**：`.env` 含有 Ceph 密碼，不應提交到版本控制
2. **獨立性**：`src/` 是外部項目，由其官方 repo 維護，無需在 notebook 中追蹤
3. **依賴管理**：notebook repo 只提供配置與文檔，MCP Server 本身保持獨立
4. **易維護**：使用者可自行選擇 MCP Server 的版本，無需跟著 notebook 更新

### 驗證 .gitignore 設定

```bash
# 查看 .gitignore 中的相關規則
cat ~/Documents/copilot/notebook/.gitignore | grep ceph-mcp

# 預期輸出：
# /storage/ceph-mcp-server/src/
# /storage/ceph-mcp-server/.env
```

### 確認 src/ 不會被追蹤

```bash
cd ~/Documents/copilot/notebook/storage/ceph-mcp-server

# Clone 源代碼
git clone https://github.com/rajmohanram/ceph-mcp-server.git src

# 檢查 git status
cd ~/Documents/copilot/notebook
git status

# 預期：src/ 目錄不在 status 輸出中
```



- [Ceph MCP Server 官方 Repo](https://github.com/rajmohanram/ceph-mcp-server)
- [Model Context Protocol 文件](https://modelcontextprotocol.io/)
- [Ceph 官方文件](https://docs.ceph.com/)
- [本實驗室 3-Node Ceph 部署指南](../3node-ceph/)
