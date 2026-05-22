# Ceph Lab NSG TCP/8000 + Bicep 持久化設計

日期：2026-05-22  
範圍：Azure Ceph Lab (`MANSION_CEPH_RESOURCE`) + `storage/3node-ceph/iac`

## 1. 目標

在現有 Ceph lab 立即允許 MCP server 連線（`TCP/8000`），並將同規則寫入 Bicep，確保未來 rebuild Ceph lab 後規則仍自動存在。

## 2. 現況摘要

1. Ceph VM NIC 綁定 `mansion-ceph-nsg`。  
2. 目前 inbound 有 `22/tcp` 與 `8443/tcp`（來源皆為 `allowedSourceCidr` 對應的固定來源），尚無 `8000/tcp`。  
3. Ceph lab IaC 在 `storage/3node-ceph/iac/modules/nsg.bicep` 定義 NSG 規則。

## 3. 設計方案

### 方案 A（採用）
1. 先更新 Azure 現況 NSG：新增 `AllowMCP8000`。  
2. 同步更新 Bicep：在 `modules/nsg.bicep` 加上 `TCP/8000` inbound 規則。  
3. 更新文件，讓操作與 IaC 一致。

**優點**：立即可用，且未來重建不回退。  
**缺點**：一次需要改 Azure 現況與 repo。

### 方案 B
只改 Bicep，不改現況 NSG，等下次重建才生效。  
缺點是目前無法立刻使用 MCP `8000/tcp`。

### 方案 C
只改現況 NSG，不改 Bicep。  
缺點是下次 rebuild 會遺失規則。

## 4. 實作邊界與規則

1. 來源限制：`TCP/8000` 只允許 `allowedSourceCidr`（不開 `0.0.0.0/0`）。  
2. 規則優先序：放在外部管理流量區段，低於 SSH（100）與既有管理規則，不影響內網互通規則（1000+）。  
3. 僅新增 MCP 所需埠，不調整既有 Ceph 內部子網規則。

## 5. 變更檔案

1. `storage/3node-ceph/iac/modules/nsg.bicep`  
2. `storage/3node-ceph/iac/README.md`  
3. `storage/3node-ceph/phase-0.md`

## 6. 驗證方式

1. Azure 查詢 NSG inbound 規則，確認 `AllowMCP8000` 存在且 `source=allowedSourceCidr`、`destinationPort=8000`。  
2. 檢查 Bicep 模組已包含同規則。  
3. 文件內容與實際部署規則一致。
