---
title: NetBox Backup and Disaster Recovery
parent: Netbox
nav_order: 6
---

# NetBox Backup and Disaster Recovery

本指南探討 NetBox 在 Kubernetes 環境下的三種災難復原策略，協助您達成「快速重建」與「資料回復」的目標。

## 方案比較表

| 方案 | 運作方式 | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| **IaC 重建 + 資料還原 (`pg_dump`)** | 使用 GitLab IaC 重建環境，手動匯入資料庫 | 極度乾淨、不依賴舊環境、易於升級 | 需維護還原腳本，資料庫還原時間稍長 | **推薦**：災難復原、版本升級 |
| **Kubernetes 快照 (Velero)** | 備份 PVC、Secrets、ConfigMaps 與資源 | 自動化程度高、可還原整個 Namespace | 依賴 K8s 環境，若叢集損毀需先重建叢集 | 叢集內局部故障、快速整組回滾 |
| **主備同步 (跨叢集)** | 兩套獨立叢集，單向同步資料庫 | RTO 極短 (切 DNS 即可) | 維護成本高、資料不一致風險 | 高可用性與異地災備 |

---

## 策略分析

### 1. IaC 重建 + 資料還原 (推薦)
這是您目前偏好的方式。架構穩定性最高，且不會有「帶入舊環境配置錯誤」的問題。
- **重建環境**：透過 GitLab 中的 `values.yaml` 與 `helm install` 快速拉起全新的叢集。
- **恢復資料**：使用 `pg_dump` 邏輯備份 SQL 資料。因為這是標準 SQL，即便從 v1.6.4 升級到 v2.x 也能成功。

### 2. Kubernetes 原生方案 (Velero)
Velero 是 K8s 社群的黃金標準，它不僅備份資料庫（如果結合 Restic 或 CSI Snapshot），還能一併備份 `Secrets` 和 `PVCs`。
- **優勢**：當您的 `netbox-superuser` Secret 或 `media` 資料夾非常複雜時，Velero 可以一鍵還原 Namespace 的所有狀態。
- **侷限**：如果您的叢集基礎設施壞得很徹底（例如 K3s 本身毀損），您需要先重建 K3s，才能安裝 Velero，再執行 `velero restore`。這與您「IaC 快速重建」的目標一致。

---

## 災難復原工作流程 (建議最佳實踐)

針對您希望「快速重建 + Restore 設定與資料」的需求，推薦 **混合策略**：

1.  **IaC (GitLab)**：負責「環境定義」(K8s Resources, Helm Values)。
2.  **邏輯備份 (`pg_dump`)**：負責「應用資料」(NetBox 業務資料)。
3.  **Velero**：負責「自動化備份 K8s 原生配置」(PVC, Secrets)。

### 實施建議：
*   **平時**：配置 Velero 自動備份 `netbox` Namespace 到 Azure Blob Storage。
*   **災難時**：
    1. 執行 IaC 重建基礎設施。
    2. 若只需還原 NetBox Namespace，直接執行 `velero restore`（速度最快）。
    3. 若遇特殊架構變更導致 Velero 無法還原，則改用 `pg_dump` 手動執行資料庫還原（最穩健）。

---

## 附錄：指令參考

### 使用 pg_dump 備份
```bash
# 備份 PostgreSQL
kubectl exec -it netbox-postgresql-primary-0 -n netbox -- \
  pg_dump -U netbox -d netbox -Fc > netbox-db-backup.dump
```

### 使用 Velero 備份 (前提：已安裝 Velero)
```bash
# 備份 netbox namespace
velero backup create netbox-backup --include-namespaces netbox
```

### 驗證建議
*   **每月演練**：不建議僅依賴備份檔，請確保 `deployment-steps.md` 中的「重建步驟」在每個季度至少執行一次測試。
*   **Secret 管理**：確保您的 `netbox-superuser` Secret 關鍵內容（如 `api_token`）同樣備份在安全的地方（例如 GitLab CI/CD Variable 或 Vault）。
