# 📓 Notebook

> [!IMPORTANT]
> **AI AGENTS**: This repository is **Spec-Driven**.
> 1. **Read the Specs**: Always reference the "Entry Point" specs below before starting any task.
> 2. **Branching**: All AI modifications MUST start from `main` and branch into `ai/<topic>` (e.g., `ai/ceph`, `ai/k8s`).
> 3. **Infrastructure**: Azure operations must use Azure MCP; Kubernetes logic follows v1.31 standards.

個人學習筆記與實作專案，由 AI Agent 輔助維護。

## 🗺️ 專案版圖 (Entry Points)

| 領域 | 核心目標 | 入口文件 (Master Spec) |
| :--- | :--- | :--- |
| **Storage** | Ceph 叢集建置、跨 DC 遷移、MCP Server 開發 | [`storage/spec.md`](./storage/spec.md) |
| **Kubernetes** | KubeVirt (Azure VM) 與 Multipass (Local) Lab | [`kubernetes/spec.md`](./kubernetes/spec.md) |
| **Automation** | Ansible Playbooks 與 Bicep IaC 模板 | 見各專案 `iac/` 或 `ansible/` |
| **Docs/Plans** | 長期規劃、設計文檔、決策紀錄 | [`docs/`](./docs/) |

## 📁 目錄結構

```text
notebook/
├── storage/        # 儲存技術 (Ceph focus)
├── kubernetes/     # 容器編排 (K8s & KubeVirt)
├── homeassistant/  # 家庭自動化觀測
├── docs/           # 跨專案的設計規格與歷史計畫 (specs/ & plans/)
└── agents/         # 自訂 AI Agent 配置與備份 (Copilot/Gemini)
```

## 🛠️ 產出與開發規範 (Output Standards)

為確保多 Agent 協作的一致性，請遵循以下規範：

### 1. 技術筆記 (Note-taking)
- **目錄結構**：
  - 架構/組件關係 -> `architecture/`
  - 業務/技術流程 -> `flowchart/` (優先使用 Mermaid 語法)
  - CLI 指令集 -> `commands/`
- **命名規則**：英文小寫 kebab-case (如 `ceph-cluster-setup.md`)。
- **語言**：回應與筆記內容以 **繁體中文** 為主。

### 2. 自動化與測試環境 (Automation & Labs)
- **IaC (Bicep)**：所有 Resource 名稱需加上專案 Prefix (如 `mansion-kubevirt-xxx`)，共用資源置於 `mansion-shared-resource`。
- **Ansible**：遵循 Role-based 結構，變數需定義於 `group_vars` 或 `host_vars`，避免 Hard-coding。
- **環境隔離**：測試環境建立指令必須包含「清理 (Cleanup)」或「銷毀 (Destroy)」的對應操作，確保 Lab 成本可控。

### 3. 協作準則 (Protocol)
- **文件優先**：任何架構變動必須先反映在對應的 `spec.md`。
- **環境感知**：本 Repo 運行於 Mac Mini M4，開發環境包含 Azure Cloud 與 Local Multipass。

---

> (註：關於 Copilot 自訂 Agent 的備份與還原細節，請參閱 [agents/README.md](./agents/README.md))
