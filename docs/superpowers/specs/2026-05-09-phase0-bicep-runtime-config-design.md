---
title: Phase 0 Bicep Runtime Config Design
---

# Phase 0 Bicep Runtime Config Design

## Problem

Phase 0 Bicep 已可成功部署，但目前 repo 內的預設值仍與實際可部署條件不一致：

1. `japaneast` 目前無法使用 Ubuntu 24.04 (`0001-com-ubuntu-server-noble / 24_04-lts-gen2`)。
2. `Standard_D2s_v5` / `Standard_D4s_v5` 在目前訂閱與區域組合下不可用。
3. SSH 公鑰其實已成功寫入 VM，但使用者容易因為登入帳號誤用 `mansionlai` 而被拒絕；實際建立的管理帳號是 `ubuntu`。

## Goal

讓 Phase 0 Bicep 的預設值直接對齊這次已驗證可部署的組合，並補上最小必要文件，避免後續重跑時再次卡在映像、容量或 SSH 使用方式上。

## Chosen Approach

採用已驗證成功的 runtime 值作為新的 Bicep 預設：

- Ubuntu 映像改為 `0001-com-ubuntu-server-jammy / 22_04-lts-gen2`
- VM size 改為：
  - master: `Standard_D2s_v4`
  - infra: `Standard_D4s_v4`
  - worker: `Standard_D4s_v4`

並在 IaC README 補一小段 SSH 使用說明，明確標示：

- 管理帳號是 `ubuntu`
- 連線格式是 `ssh ubuntu@<public-ip>`

## Alternatives Considered

### 1. 只保留現況，不更新 repo

把這次成功部署依靠的 runtime override 留在操作記錄裡，不修改 repo 預設值。

**不採用原因：**
- 下次重跑時還會再次撞到相同錯誤。
- repo 內容與真實可部署條件不一致。

### 2. 保持 Ubuntu 24.04 與 v5 規格，但改區域

改用支援 `noble` 與 v5 容量的 Azure region。

**不採用原因：**
- 目前 Phase 0 已在 `japaneast` 成功建立。
- 這會擴大變更範圍，從「修正可部署預設值」變成「改整個區域策略」。

### 3. 推薦方案：固定為目前已驗證可用的組合

這次直接把 repo 預設值收斂到已證實可用的 image 與 VM sizes，之後若 Azure 容量與映像供應變化，再做下一次更新。

**採用原因：**
- 變更最小
- 與目前成功部署結果一致
- 可立即提升後續重跑成功率

## Scope

### In Scope

- 更新 `kubernetes/3node-kubevirt/iac/main.bicepparam`
- 若需要，更新 `kubernetes/3node-kubevirt/iac/main.bicep` 相關預設說明
- 更新 `kubernetes/3node-kubevirt/iac/README.md`，補上 SSH 使用說明

### Out of Scope

- 改 Azure region
- 導入 deployment stack / destroy automation
- 調整網路拓樸、VM 數量或 subnet 設計
- 把 admin username 從 `ubuntu` 改成 `mansionlai`

## Implementation Design

### 1. Bicep 預設值更新

在參數檔中直接改成已成功部署的值：

- `imageOffer = '0001-com-ubuntu-server-jammy'`
- `imageSku = '22_04-lts-gen2'`
- `masterVmSize = 'Standard_D2s_v4'`
- `infraVmSize = 'Standard_D4s_v4'`
- `workerVmSize = 'Standard_D4s_v4'`

保留：

- `imagePublisher = 'Canonical'`
- `imageVersion = 'latest'`
- `adminUsername = 'ubuntu'`

### 2. README SSH 說明

在 IaC README 補一段極短操作說明，內容聚焦：

- 這次 Phase 0 VM 的 SSH 管理帳號是 `ubuntu`
- 連線範例：`ssh ubuntu@<public-ip>`
- 若本機預設使用其他帳號，可明確指定 `-i ~/.ssh/id_ed25519`

### 3. 驗證方式

更新後需要重新做最小驗證：

1. `az bicep build --file main.bicep`
2. `az deployment group what-if` 使用更新後的預設值
3. SSH 以 `ubuntu` 帳號驗證一次

## Expected Result

完成後應達成：

1. repo 內 Bicep 預設值與目前可部署條件一致
2. 後續重跑 Phase 0 時，不需要再次手動覆寫 image 與 VM size
3. README 能直接提醒使用者 SSH 應使用 `ubuntu` 帳號
