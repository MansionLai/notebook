---
title: Ceph MCP Server 文檔
parent: Storage
has_children: true
nav_order: 30
permalink: /storage/ceph-mcp-server/
---

# Ceph MCP Server 文檔

在此資料夾內，您可以找到關於在 Mac mini 上安裝、設定與使用 **Ceph MCP Server** 的完整文檔。

## 📖 文檔導覽

### 開始閱讀

1. **[README.md](README.md)** ⭐ **開始這裡**
   - 完整的安裝與設定指南
   - 系統要求與前置條件
   - 環境設定詳解
   - Copilot 整合方法
   - 使用示例

2. **[QUICKSTART.md](QUICKSTART.md)** 🚀 **快速上手**
   - 5 分鐘快速安裝步驟
   - 常用命令速查
   - 常見問題快速修復
   - 驗證步驟

### 進階內容

3. **[COPILOT_INTEGRATION.md](COPILOT_INTEGRATION.md)** 🔧 **整合 Copilot**
   - 推薦 local(stdio) 整合方式（不使用 SSE）
   - 環境變數管理
   - 安全最佳實踐
   - 測試與調試

4. **[troubleshooting.md](troubleshooting.md)** 🆘 **故障排除**
   - 連線問題診斷
   - 認證失敗排查
   - SSL 證書問題
   - Python 依賴問題
   - MCP Server 啟動問題
   - 性能與超時調整

### 配置檔案

5. **.env.example** 📝 **環境變數範本**
   - Ceph 連線參數
   - SSL 配置
   - 日誌設定
   - API 限流選項

6. **mcp.json.example** ⚙️ **Copilot MCP 配置**
   - JSON 格式配置範本（local/stdio）
   - 可直接參考 `~/.copilot/mcp-config.json`

## 🎯 推薦工作流程

### 第一次安裝

```
1. 閱讀 README.md → 瞭解整體架構
   ↓
2. 按照 QUICKSTART.md → 完成安裝
   ↓
3. git clone 到 src/ → 下載 ceph-mcp-server 源代碼
   ↓
4. 驗證 .env 設定 → 測試 Ceph 連線
   ↓
5. 啟動 MCP Server → 確認運行正常
   ↓
6. 參考 COPILOT_INTEGRATION.md → 整合 Copilot
```

> 💡 **提示**：`src/` 資料夾已在 `.gitignore` 中，不會被 push 到 notebook repo。

### 遇到問題

```
1. 查看 troubleshooting.md → 找到相應症狀
   ↓
2. 按照步驟診斷 → 收集日誌
   ↓
3. 執行修復方案 → 驗證結果
   ↓
4. 仍無法解決？→ 提交 Issue
```

## 📋 快速檢查清單

在開始前，確認以下條件：

- [ ] Python ≥3.11 已安裝
- [ ] `uv` 套件管理工具已安裝
- [ ] Ceph 集群已完成 Phase 3 部署
- [ ] Ceph Manager API 可從 Mac mini 訪問（例：20.89.53.16:8443）
- [ ] 有效的 Ceph 使用者帳號與密碼
- [ ] 本資料夾已初始化（clone 源代碼到 `src/` 目錄）

## 🔑 關鍵路徑

| 項目 | 路徑 |
|------|------|
| 本文檔資料夾 | `~/Documents/copilot/notebook/storage/ceph-mcp-server/` |
| MCP Server 源代碼 | `~/Documents/copilot/notebook/storage/ceph-mcp-server/src/` |
| 環境設定檔 | `~/Documents/copilot/notebook/storage/ceph-mcp-server/.env` |
| Copilot 配置 | `~/.copilot/mcp-config.json` |

## 💡 有用的命令

```bash
# 查看目錄結構
tree ~/Documents/copilot/notebook/storage/ceph-mcp-server/

# 設定 local(stdio) MCP
copilot mcp add ceph-mcp -- bash -lc \
  'cd /Users/mansionlai/Documents/copilot/notebook/storage/ceph-mcp-server/src && \
   set -a && source ../.env && set +a && \
   uv run ceph-mcp-server'

# 測試 Ceph 認證
source .env
curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.ceph.api.v1.0+json" \
  -d "{\"username\":\"$CEPH_USERNAME\",\"password\":\"$CEPH_PASSWORD\"}" \
  "$CEPH_MANAGER_URL/api/auth"

# 檢查 MCP 設定
copilot mcp list
copilot mcp get ceph-mcp
```

## 🔗 相關資源

- **官方 Repo**: https://github.com/rajmohanram/ceph-mcp-server
- **MCP 規格**: https://modelcontextprotocol.io/
- **Ceph 文件**: https://docs.ceph.com/
- **Copilot CLI 文件**: https://github.com/github/copilot-cli

## 📞 需要幫助？

1. **查看常見問題** → [troubleshooting.md](troubleshooting.md)
2. **檢查日誌輸出** → 執行 `LOG_LEVEL=DEBUG` 模式
3. **驗證連線** → 執行 curl 測試
4. **提交 Issue** → GitHub repository

---

**最後更新**: 2026-05-21

**版本**: v0.1.0

**狀態**: ✅ Ready for Lab Use
