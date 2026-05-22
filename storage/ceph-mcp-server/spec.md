# ceph-mcp-server Spec

最後更新：2026-05-22

## 1. Goal

在 Mac mini 上讓 Copilot CLI 透過 `local (stdio)` 使用 Ceph MCP Server，直接查詢與操作 Ceph cluster（不使用 SSE）。

## 2. Deployment Baseline

1. 工作目錄：`storage/ceph-mcp-server/`
2. 上游原始碼 clone 到：`storage/ceph-mcp-server/src/`
3. 執行環境：`uv` + 專案 `.venv`
4. 敏感資訊放在：`storage/ceph-mcp-server/.env`（已 gitignore）

## 3. Runtime Configuration

必要環境變數：

1. `CEPH_MANAGER_URL`
2. `CEPH_USERNAME`
3. `CEPH_PASSWORD`
4. `CEPH_SSL_VERIFY`
5. `MCP_SERVER_VERSION`

Copilot MCP config (`~/.copilot/mcp-config.json`) 需使用：

1. `type: local`
2. `command: bash`
3. 透過 `bash -lc` 先 `source ../.env` 再執行 `uv run ceph-mcp-server`

## 4. MCP Transport Requirement

1. FastMCP transport 必須是 `stdio`
2. 不可使用 `streamable-http`（會與 local mode 不相容）

## 5. Current Recognized State

1. Ceph auth API 可成功取得 token
2. Cluster health: `HEALTH_OK`
3. OSD count: `6`

## 6. Known Failure Patterns

1. `MCP error -32000: Connection closed`
   - 常見根因：server subprocess 啟動失敗（非 stdio 協議本身）
2. `ModuleNotFoundError: ceph_mcp`
   - 常見根因：套件入口或環境狀態異常
   - 建議修復：確認 `src/ceph_mcp/__init__.py` 存在，並執行 `uv sync --reinstall`

## 7. Reference

1. `storage/ceph-mcp-server/README.md`

