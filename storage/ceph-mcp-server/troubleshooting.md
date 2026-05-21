---
title: Ceph MCP Server 故障排除
parent: Ceph MCP Server 安裝與設定
grand_parent: Storage
nav_order: 1
permalink: /storage/ceph-mcp-server/troubleshooting/
---

# Ceph MCP Server 故障排除

## 連線問題

### ❌ "Connection refused" 或 "Unable to reach Ceph Manager"

**症狀：**
```
ERROR: Failed to connect to Ceph Manager at https://10.10.10.21:8443
Connection refused
```

**檢查清單：**

1. **驗證 Ceph Manager 運行中**
   ```bash
   ssh ubuntu@10.10.10.21 "sudo ceph mgr stat"
   ```
   預期輸出：`mgr stat` 回應（不是 error）

2. **測試網路連通性**
   ```bash
   ping 10.10.10.21
   telnet 10.10.10.21 8443
   ```

3. **檢查防火牆**
   ```bash
   # 在 ceph-node-01 上
   ssh ubuntu@10.10.10.21 "sudo ufw status"
   ssh ubuntu@10.10.10.21 "sudo iptables -L | grep 8443"
   ```

4. **驗證 .env 內的 URL**
   ```bash
   source .env
   echo $CEPH_MANAGER_URL
   # 應該輸出: https://10.10.10.21:8443
   ```

5. **直接 curl 測試**
   ```bash
   curl -v -k https://10.10.10.21:8443/
   # 預期: 收到 HTTP 響應或重定向
   ```

---

## 認證問題

### ❌ "Unauthorized" 或 "Invalid credentials"

**症狀：**
```
ERROR: HTTP 401 - Unauthorized
Invalid username or password
```

**解決方案：**

1. **驗證 Ceph 使用者帳號**
   ```bash
   ssh ubuntu@10.10.10.21 "sudo ceph auth get client.admin"
   ```

2. **檢查密碼是否正確**
   ```bash
   source .env
   curl -k -u $CEPH_USERNAME:$CEPH_PASSWORD \
     $CEPH_MANAGER_URL/api/v1/health
   ```
   
   如果返回 401，密碼有誤。

3. **從 Ansible vault 重新抽取密碼**
   ```bash
   cd ~/Documents/copilot/notebook/storage/3node-ceph/ansible
   ansible-vault view inventory/group_vars/encrypted.yml | grep vault_ceph_dashboard_password
   ```

4. **重新設定 .env**
   ```bash
   cp .env.example .env
   # 編輯 .env，填入正確密碼
   ```

5. **驗證 Ceph 使用者有正確權限**
   ```bash
   ssh ubuntu@10.10.10.21 "sudo ceph auth get-or-create client.admin mds 'allow *' mon 'allow *' osd 'allow *' mgr 'allow *'"
   ```

---

## SSL 證書問題

### ❌ "SSL: CERTIFICATE_VERIFY_FAILED" 或 "self signed certificate"

**症狀：**
```
ERROR: SSL: CERTIFICATE_VERIFY_FAILED: certificate verify failed (_ssl.c:1123)
```

**解決方案：**

1. **Lab 環境：禁用 SSL 驗證**
   ```bash
   echo "CEPH_SSL_VERIFY=false" >> .env
   ```

2. **生產環境：取得正確的 CA 憑證**
   ```bash
   # 從 Ceph 節點複製證書
   scp ubuntu@10.10.10.21:/etc/ceph/ceph.crt ~/ceph-ca.crt
   
   # 在 .env 中指定
   echo "CEPH_CERT_PATH=$HOME/ceph-ca.crt" >> .env
   echo "CEPH_SSL_VERIFY=true" >> .env
   ```

3. **驗證 curl 可以訪問**
   ```bash
   # 不驗證證書
   curl -k https://10.10.10.21:8443/
   
   # 使用指定的 CA 證書
   curl --cacert ~/ceph-ca.crt https://10.10.10.21:8443/
   ```

---

## Python 與依賴問題

### ❌ "Python version not supported"

**症狀：**
```
ERROR: Python 3.9 is not supported. Required: >=3.11
```

**解決方案：**

1. **檢查 Python 版本**
   ```bash
   python3 --version
   ```

2. **升級 Python**
   ```bash
   # 使用 Homebrew
   brew install python@3.13
   brew link python@3.13
   
   # 驗證
   python3 --version
   ```

3. **建立虛擬環境（推薦）**
   ```bash
   python3.13 -m venv ~/ceph-mcp-env
   source ~/ceph-mcp-env/bin/activate
   python --version  # 應該是 3.13
   ```

### ❌ "ModuleNotFoundError" 或 "No module named ..."

**症狀：**
```
ModuleNotFoundError: No module named 'pydantic'
```

**解決方案：**

1. **重新安裝依賴**
   ```bash
   cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
   uv sync
   ```

2. **驗證 uv 已安裝**
   ```bash
   uv --version
   ```

3. **清除快取重新安裝**
   ```bash
   rm -rf .venv __pycache__
   uv sync --fresh
   ```

---

## MCP Server 啟動問題

### ❌ "Server failed to start" 或無輸出

**症狀：**
```
Starting Ceph MCP Server...
(沒有任何反應，或程式立即退出)
```

**調查步驟：**

1. **以 DEBUG 模式啟動**
   ```bash
   cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
   LOG_LEVEL=DEBUG uv run python -m ceph_mcp.server
   ```

2. **查看完整錯誤訊息**
   上述命令應該會輸出詳細的 stacktrace。

3. **檢查 .env 是否被載入**
   ```bash
   cd ~/Documents/copilot/notebook/storage/ceph-mcp-server
   source .env
   echo "CEPH_MANAGER_URL: $CEPH_MANAGER_URL"
   echo "CEPH_USERNAME: $CEPH_USERNAME"
   ```

4. **驗證 Ceph 連線**
   ```bash
   source .env
   curl -k -u $CEPH_USERNAME:$CEPH_PASSWORD \
     $CEPH_MANAGER_URL/api/v1/health
   ```

5. **檢查 Python 路徑**
   ```bash
   which python3
   which uv
   ```

---

## 在 Copilot 中整合失敗

### ❌ "MCP server not found" 或 "Server did not respond"

**症狀：**
```
Error initializing Ceph MCP tool: Server not found or failed to start
```

**解決方案：**

1. **驗證 MCP Server 可獨立運行**
   ```bash
   cd ~/Documents/copilot/notebook/storage/ceph-mcp-server/src
   uv run python -m ceph_mcp.server
   # 應該看到 "Server is ready"
   ```

2. **檢查 Copilot MCP 配置檔**
   ```bash
   cat ~/.copilot/mcp.json  # 或相應配置檔
   ```
   
   確認：
   - 命令路徑正確
   - 環境變數已設定
   - 指令可執行

3. **手動測試配置的命令**
   ```bash
   # 如果配置使用 uv，測試:
   uv run --with-editable \
     /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src \
     python -m ceph_mcp.server
   ```

4. **檢查 Copilot 日誌**
   ```bash
   # Copilot CLI 通常輸出到 stderr 或日誌檔
   # 查詢相關檔案位置文件
   ```

---

## API 速率限制

### ⚠️ "Rate limit exceeded"

**症狀：**
```
WARNING: Rate limit exceeded. Requests per minute: 60
```

**解決方案：**

1. **增加限流閾值**
   ```bash
   echo "MAX_REQUESTS_PER_MINUTE=120" >> .env
   ```

2. **實現請求快取**（未來優化）
   - MCP Server 可快取常見查詢結果
   - 減少重複 API 呼叫

---

## 性能與超時

### ⚠️ "Request timeout" 或 "Server took too long to respond"

**症狀：**
```
Timeout waiting for response from Ceph MCP Server (>30s)
```

**排查步驟：**

1. **檢查 Ceph 集群狀態**
   ```bash
   ssh ubuntu@10.10.10.21 "sudo ceph -s"
   ```
   
   如果集群有問題，查詢會變慢。

2. **測試單一 API 呼叫的時間**
   ```bash
   time curl -k -u admin:password \
     https://10.10.10.21:8443/api/v1/health
   ```

3. **增加超時時間**
   - 在 MCP Server 配置中調整 timeout 參數（如可用）

4. **檢查 Mac mini 資源**
   ```bash
   top  # 查看 CPU、RAM 使用率
   ```

---

## 資料與日誌

### 📊 查看完整日誌

```bash
# 以 DEBUG 級別運行
LOG_LEVEL=DEBUG uv run python -m ceph_mcp.server 2>&1 | tee ~/ceph-mcp.log

# 查看日誌
tail -f ~/ceph-mcp.log
```

### 📝 常見日誌訊息

| 訊息 | 含義 | 解決方案 |
|------|------|--------|
| `Connected to Ceph cluster successfully` | ✅ 連線成功 | 正常 |
| `Failed to authenticate` | ❌ 認證失敗 | 檢查密碼 |
| `API rate limited` | ⚠️ 限流 | 增加限流閾值 |
| `Cluster health: HEALTH_WARN` | ⚠️ 集群告警 | 檢查 Ceph 狀態 |

---

## 聯繫支持

若以上步驟都無法解決：

1. **檢查官方 Repo**
   - https://github.com/rajmohanram/ceph-mcp-server/issues

2. **收集診斷資訊**
   ```bash
   echo "=== Environment ===" > diagnostics.txt
   echo "Python: $(python3 --version)" >> diagnostics.txt
   echo "uv: $(uv --version)" >> diagnostics.txt
   echo "" >> diagnostics.txt
   
   echo "=== Ceph Connection ===" >> diagnostics.txt
   source .env
   curl -k -u $CEPH_USERNAME:$CEPH_PASSWORD \
     $CEPH_MANAGER_URL/api/v1/health 2>&1 >> diagnostics.txt
   echo "" >> diagnostics.txt
   
   echo "=== MCP Server Log ===" >> diagnostics.txt
   LOG_LEVEL=DEBUG uv run python -m ceph_mcp.server 2>&1 | head -100 >> diagnostics.txt
   
   # 分享 diagnostics.txt（移除敏感資訊）
   ```

3. **提交 Issue**
   - 附上診斷檔案
   - 詳細描述症狀與已嘗試的解決方案
