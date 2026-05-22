# Kubernetes Domain Spec (總綱)

本檔是 `kubernetes/` 底下所有小主題的**總規格入口**。  
原則：共用規範放這裡；實作細節放各子題 `spec.md`。

## 1) Agent Scope 與操作原則

1. AI agent 運行於 Mac mini，協助維護 `notebook repo`，並聚焦 `kubernetes/` 目錄。
2. 若有分支工作流程，預設由 `main` 切分支（例如 `ai/k8s`）後再合回 `main`。
3. 操作 Azure 資源時，優先透過 Azure MCP。

## 2) 子題導覽

| 子題 | 規格檔 | 說明 |
|---|---|---|
| 3node-kubevirt | `kubernetes/3node-kubevirt/spec.md` | Azure 上的 3 節點 K8s + KubeVirt Lab |
| 3node-multipass | `kubernetes/3node-multipass/spec.md` | Mac Mini 本機 Multipass 的 3 節點純 K8s Lab |

## 3) 共用規範

### 3.1 Naming & Resource Boundary

- 專案專屬資源需有一致前綴（例如 `mansion_kubevirt_*` / `mansion-kubevirt-*`，依各子題實際 IaC 為準）。
- 共用資源（例如 shared vnet）集中在 shared resource group（例如 `mansion-shared-resource`）。

### 3.2 規格維護原則

- 本檔只放：
  - 共用規範
  - 子題索引
  - 跨子題共同決策
- 各子題 `spec.md` 必須固定包含：
  - `Scope & Goal`
  - `Target Architecture`
  - `Naming Convention`
  - `Execution Guardrails`
  - `Agent Bootstrap`
  - `Current Status Snapshot`
  - `Definition of Done`

## 4) Current Status Snapshot（跨子題）

- `3node-kubevirt`：已有 Phase 0~6 文件與 IaC，適合用於 Azure + KubeVirt 實作驗證。
- `3node-multipass`：已有 Step 0~6 buildup 導向，適合本機純 K8s 基礎學習與演練。

## 5) Agent 快速啟動（跨子題）

新 agent 重啟時，建議先讀：
1. 本檔 `kubernetes/spec.md`（總綱）
2. 目標子題 `kubernetes/<topic>/spec.md`
3. 該子題 `buildup.md` / `commands.md` / `architecture.md`
