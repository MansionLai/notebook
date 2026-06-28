---
title: MultiNetworkPolicy iptables Priority in KubeVirt
parent: Concepts
grand_parent: Kubernetes
nav_order: 2
---

# MultiNetworkPolicy 在 KubeVirt VM Pod 中的 iptables 規則順序與 Priority 機制解析

> 建立日期：2026-06-24  
> 分類：concepts/kubevirt  
> 版本：KubeVirt v1.5.0, Kubernetes v1.31.0, Multus CNI v4.2.4, Multus-NetworkPolicy

---

## 概述

在 Kubernetes 中，標準的 `NetworkPolicy` 僅能控制 Pod 的主網路介面（通常是 `eth0`）。當我們使用 **Multus CNI** 為 KubeVirt VM Pod 串接多個次要網路介面（Secondary Network Interfaces，例如 `net1`）時，需要透過 **MultiNetworkPolicy**（由 Kubernetes Network Plumbing Working Group 維護）來對這些次要介面進行網路存取控制。

本文件旨在深入探討：當我們對同一個 VM Pod 套用多筆 `MultiNetworkPolicy` 時，其產生的 `iptables` 規則順序與優先級（Priority）是如何運作的，以及如何進行控制與調優。

---

## MultiNetworkPolicy 的優先級與順序機制

### 1. 宣告式邏輯：累加性（Additive / Logical OR）
與 Kubernetes 標準的 `NetworkPolicy` 相同，`MultiNetworkPolicy` 的設計哲學是**累加的（Additive）**。
* **只有 Allow 規則：** `MultiNetworkPolicy` 的規格中，規則（Ingress/Egress）僅支援白名單（Allow-list）。當 Pod 被任何政策選中時，該 Pod 預設會進入「預設拒絕（Default Deny）」狀態，只有符合政策中宣告的流量才會被允許通過。
* **邏輯或（OR）關係：** 如果一個 Pod 被多個 `MultiNetworkPolicy` 選擇，則生效的規則是所有政策中 Allow 規則的**聯集（Union）**。
* **順序無關性（Semantic Order Independence）：** 在純 `Allow` 規則的累加模型中，流量只要匹配其中任何一條規則就會被 `ACCEPT`。因此，不論哪一條規則放在 `iptables` 鏈的最前面，最終的網路存取控制結果都是一樣的。

### 2. `multi-networkpolicy-iptables` 的實作機制
`multus-networkpolicy` 主要是透過 `multi-networkpolicy-iptables` 守護行程（DaemonSet）在各個節點上運作：
1. **進入 Pod Network Namespace：** 當 `MultiNetworkPolicy` 資源或 Pod 發生變更時，Daemon 會利用 Linux 的 `nsenter` 進入目標 Pod 的網路命名空間（Namespace）。
2. **解析與轉換規則：** Daemon 會查詢所有與該 Pod 相關聯的 `MultiNetworkPolicy`（透過 Pod Selector 與 policy-for 標記），並將其轉換成對應次要介面（如 `net1` 轉為 `knet1` 或對應的 `tap0` 橋接介面）的 `iptables` 鏈（例如 `MULTI-INGRESS` 與 `MULTI-EGRESS`）。
3. **沒有使用者定義的 Priority 欄位：** 在 `MultiNetworkPolicy` 的 CRD 規格中，**沒有**提供類似 `priority` 或 `order` 的欄位供使用者手動調整政策排序。
4. **Daemon 內部排序：** 程式碼在產生 `iptables` 規則時，雖然會依據政策的獲取順序將規則依序插入 `iptables` 鏈中，但由於全都是 `ACCEPT` 規則，因此順序的先後僅微幅影響 `iptables` 的封包比對效能（先匹配到的先 ACCEPT），並不影響安全性決策。
5. **動態對齊與覆寫：** `multi-networkpolicy-iptables` 會定期執行對齊（Reconciliation Loop）。如果您手動進入 Pod 的 Namespace 並使用 `iptables -I` 或 `iptables -A` 修改規則順序，這些手動修改將會在下一次同步時被 Daemon 覆寫還原。

---

## 如果需要控制規則優先級或實作 Deny，該如何處理？

若您的情境中需要更精細的控制，例如「特定 IP 優先阻擋（Deny）」或「有明確優先級的防火牆規則」，單靠 `MultiNetworkPolicy` 是無法直接達成的。以下是可行的替代與折衷方案：

### 方案 A：在 KubeVirt VM 內部的 Guest OS 進行控制（推薦）
由於 KubeVirt 執行的是完整的虛擬機器，VM 擁有自己獨立的 Guest OS（例如 Linux 或 Windows）與核心網路命名空間。
* **作法：** 直接在 VM 內部設定防火牆（例如 `iptables`、`nftables`、`firewalld` 或 `ufw`）。
* **優點：** 
  * 支援豐富的 `Deny` / `Reject` 規則與明確的順序控制。
  * 這些規則是在 Guest OS 內部生效，Kubernetes 宿主機上的 `multi-networkpolicy-iptables` Daemon 無法觸及也無法覆寫它們。
* **缺點：** 需要進入 VM 內部進行配置，管理上較為分散。可透過雲端初始化工具（`cloud-init`）在 VM 建立時自動載入防火牆規則。

### 方案 B：評估 Kubernetes 1.31+ 的 AdminNetworkPolicy (ANP)
Kubernetes 在近年引入了 `AdminNetworkPolicy` (ANP) 與 `BaselineAdminNetworkPolicy` (BANP)，這兩者支援：
* **明確的優先級 (Priority)：** 範圍為 0 到 1000（數字越小優先級越高）。
* **多元的動作 (Action)：** 支援 `Allow`、`Deny` 與 `Pass`。
* **限制：** 目前 ANP 規格與生態系主要仍是針對叢集的主網路介面（Default CNI）。若要在 Multus 次要介面上使用，需要確認您所使用的 CNI/擴充套件是否支援將 ANP 套用至次要網路（目前大部分 Multus 的次要網路仍只支援 `MultiNetworkPolicy`，因此此方案需視未來社群演進而定）。

### 方案 C：使用支援多網路且具備 Policy 功能的進階 CNI
有些進階 CNI（例如 **OVN-Kubernetes**）本身就支援建立多個邏輯網路（Logical Networks）作為次要網路，並且能套用更豐富的網路存取控制清單（ACLs）。如果您的叢集架構允許，可以考慮將 Multus 後端的 CNI 替換成具備原生 Policy 與優先級控制的 CNI。

---

## 結論與最佳實踐建議

1. **針對一般的 Allow 情境：**
   不需要刻意控制 `MultiNetworkPolicy` 的順序。您可以放心地 apply 多筆政策，`multi-networkpolicy-iptables` 會自動彙整所有白名單規則，並將結果聯集套用。
2. **針對需要 Deny 或優先級順序的情境：**
   建議將這些精細的防火牆邏輯下放到 **KubeVirt VM Guest OS 內部**，結合 `cloud-init` 進行自動化配置。這是目前在 Multus CNI 架構下最穩定、最靈活且不會被 Kubernetes 控制器覆寫的作法。
3. **排查與驗證方法：**
   若要確認 VM Pod 內部實際的 `iptables` 規則順序，可於宿主機上執行以下指令來進入 Pod 的網路空間進行檢視：
   ```bash
   # 1. 找出 VM Pod 的 Container ID 或 Pause Container PID
   # 2. 使用 nsenter 查看該 namespace 的 iptables 規則
   nsenter -t <Pause_Container_PID> -n iptables -nvL --line-numbers
   ```

---

## 實務案例分析：使用 Allow Log 驗證特定 IP 的流量匹配與規則遮蔽（Shadowing）問題

### 1. 場景描述
* **Rule A (主要規則)**：允許 10 個 IP（`192.168.1.1` ~ `192.168.1.10`）通行，但**未啟用** Allow Log 功能（以節省記錄空間）。
* **Rule B (測試/驗證規則)**：僅允許 `192.168.1.1` 通行，且**啟用** Allow Log 功能（透過 NFLOG 搭配 fluent-bit 將日誌送至 OpenSearch）。
* **目的**：想藉由 Rule B 產生的日誌，來驗證 `192.168.1.1` 是否真的有流量通過。如果沒有收到日誌，則計劃將 Rule A 縮減，排除 `192.168.1.1`。

### 2. 潛在風險：iptables 規則遮蔽（Shadowing）產生的「偽陰性（False Negative）」
由於 `MultiNetworkPolicy` 會被編譯成 `iptables` 鏈中的多條規則，若直接同時套用這兩筆 Policy，會遇到 `iptables` 從上到下比對的順序問題：

* **當 Rule A 被排在 Rule B 上方時**：
  1. 來自 `192.168.1.1` 的封包到達次要網路介面。
  2. 比對到 Rule A，因為符合 `192.168.1.1 ~ 10` 的範圍，封包直接被 `ACCEPT` 並結束比對。
  3. 由於 Rule A 沒有設定 NFLOG，因此**不會產生任何日誌**。
  4. 封包根本沒有機會走到下方的 Rule B。
  * **結果**：OpenSearch 中完全找不到 `192.168.1.1` 的日誌，這會讓您誤以為 `192.168.1.1` 沒有任何匹配流量，進而錯誤地將其從 Rule A 中剔除。然而此時流量其實是一直正常通行的，只是被 Rule A 「遮蔽」了日誌。

* **當 Rule B 被排在 Rule A 上方時**：
  1. 來自 `192.168.1.1` 的封包先比對到 Rule B。
  2. 符合 `192.168.1.1` 且觸發 NFLOG 記錄，封包被 `ACCEPT`。
  3. 其他 IP（`192.168.1.2 ~ 10`）不符合 Rule B，繼續往下比對，最後符合 Rule A 被 `ACCEPT`。
  * **結果**：日誌能夠正常產生並送至 OpenSearch，測試成功。

由於無法保證 `multi-networkpolicy-iptables` 在 Pod 中建立這兩筆 Policy 規則時的順序（通常為非決定性，或依名稱排序），因此直接同時 Apply 兩筆 Policy 進行測試是非常危險且不可靠的。

---

### 3. 推薦的驗證方案

為了解決上述 Shadowing 導致的偽陰性問題，建議採用以下三種方案之一進行測試：

#### 方案一：先在 Rule A 中將該 IP 排他（最推薦，最穩健）
這是最可靠的測試方式，完全避開了 iptables 規則先後順序的干擾。
1. **修改 Rule A**：將 Rule A 的範圍限制在 `192.168.1.2 ~ 192.168.1.10`（暫時排除 `192.168.1.1`）。
2. **套用 Rule B**：建立 Rule B（允許 `192.168.1.1` 且開啟 NFLOG）。
3. **驗證**：
   * **情境一**：如果 `192.168.1.1` 有流量，它只能匹配 Rule B，您一定會在 OpenSearch 中收到日誌。此時代表該 IP 有流量匹配。
   * **情境二**：如果一段時間內 OpenSearch 都沒有收到日誌，則可確認 `192.168.1.1` 確實無匹配流量，您可以維持修改後的 Rule A，並刪除臨時的 Rule B。
4. **還原（若有流量）**：若確認有流量且需要繼續保留，則將 `192.168.1.1` 加回 Rule A，並移除 Rule B。

#### 方案二：直接在 Rule A 上暫時啟用 Allow Log
若 Rule A 可以隨時變更，直接對 Rule A 進行短時間的診斷是更簡單的做法：
1. **修改 Rule A**：暫時開啟 Rule A 的 Allow Log 功能。
2. **過濾日誌**：在 OpenSearch 中，以 `source.ip: "192.168.1.1"` 作為關鍵字過濾日誌。
3. **關閉日誌**：確認完畢後，將 Rule A 的 Allow Log 功能關閉，以避免持續產生海量日誌。
* **優點**：不需建立額外的 Policy，也不必擔心 iptables 的順序問題。

#### 方案三：利用命名排序規則（若 Controller 支援）
如果您的 `multi-networkpolicy-iptables` 版本被證實是依據 Policy 的 `metadata.name` 字母順序（Alphabetical Order）來決定 iptables 鏈中規則的先後順序：
* **作法**：可以將 Rule B 命名為 `00-log-192-168-1-1`，將 Rule A 命名為 `99-allow-rule-a`。
* **警告**：此方法極度依賴特定版本的實作細節，若未來升級 Kubernetes、Multus 或是換成 `nftables` 後端，排序邏輯可能會改變，因此不適合作為生產環境的標準流程。

---

### 4. Azure Lab 實地驗證與可行性結論（2026-06-24 驗證）

我們在 Azure 3-Node KubeVirt 環境下，針對上述三種驗證方案進行了實地測試，以下是驗證結果與可行性結論：

#### 🔴 核心發現：`multi-networkpolicy-iptables` 控制器規則生成缺陷
在進入 KubeVirt VM Pod 的網路命名空間（Namespace）檢查實際生成的 `iptables` 規則時，我們發現該控制器存在一個關鍵的實作 Bug。在 `MULTI-INGRESS` 鏈中，控制器在跳轉到個別 Policy 鏈後，會無條件插入一條 `-j RETURN` 規則：
```text
-A MULTI-INGRESS -i pod56d8eadccf2 -m comment --comment "policy:99-policy-a" -j MULTI-0-INGRESS
-A MULTI-INGRESS -j RETURN
```
這導致不論封包是否匹配 `MULTI-0-INGRESS` 鏈的規則（即是否符合白名單 IP 範圍），都會觸發這條無條件的 `RETURN` 規則，直接回到 `INPUT` 鏈（預設 `ACCEPT` 透過）。因此，**所有流量皆會被無條件放行，後續的其他 Policy 鏈與最終的 `DROP` 規則形同虛設**。
* **實驗驗證**：在 Worker 節點的橋接介面配置一個完全不在白名單內的測試 IP `192.168.1.50`，對 VM 進行 ping 測試，依然能夠 100% 成功連線，證明策略已失效。

---

#### 📋 方案可行性評估結果

| 方案 | 可行性 | 實地測試與分析結論 |
|:---|:---|:---|
| **方案一：IP 排他法** | **不可行 / 失效** | 受限於上述 `RETURN` 缺陷，即使將 IP 從 Rule A 排除並放到 Rule B，非白名單流量與 Rule B 的流量都會被放行。此外，控制器並不支援 NFLOG / 記錄等機制，無法原生產生測試日誌。 |
| **方案二：啟用 Allow Log** | **不可行** | `MultiNetworkPolicy` API 與該控制器原生**不支援**任何日誌記錄動作（如 `-j NFLOG`）。手動進入 Namespace 修改規則會立即被控制器的 Reconciliation Loop 覆寫還原。 |
| **方案三：命名排序** | **不可行** | 經測試，命名為 `00-policy-b`、`05-policy-c` 與 `99-policy-a` 後，`iptables` 鏈中的比對順序為 `05` $\rightarrow$ `00` $\rightarrow$ `99`（與建立順序或 ResourceVersion 相關），**並不依循字母排序**。且由於 `RETURN` Bug，第一筆 Policy 比對後即會 short-circuit 放行所有流量。 |

#### 💡 最終建議
在 `multi-networkpolicy-iptables` 架構下：
1.  **若可進入 Guest OS 內部**：最穩健且唯一可行的網路安全存取控制（含日誌記錄與 Deny 機制）是**回歸到 VM Guest OS 內部防火牆進行控制（方案 A）**，配合 `cloud-init` 進行自動化配置，此法不受 Kubernetes 控制器 Bug 或 Reconciliation Loop 影響。
2.  **若無法進入 Guest OS 內部（如 Cluster Admin 權限受限）**：由於控制器的 `RETURN` 生成 Bug 與原生對 logging 欄位的缺乏支援，無法直接透過 Apply 多筆 MultiNetworkPolicy 來進行流量稽核與規則收斂。此時必須使用 **全域自訂規則（Custom Rules ConfigMap）** 在鏈的前端攔截並寫入日誌，詳見下文。

---

### 5. Cluster Admin 權限下的替代驗證方案：利用全域自訂規則（Custom Rules ConfigMap）

如果我們作為 **Cluster Admin** 無法進入 VM Guest OS 內部調整防火牆，但又需要透過「暫時啟用日誌」來驗證特定 IP 範圍是否確實有流量通過（例如：評估是否能將舊的 `ruleA: 10.10.1.1~10.10.1.100` 縮減為 `ruleB: 10.10.1.1~10.10.1.10`），我們可以使用 `multi-networkpolicy-iptables` 提供之 **ConfigMap 自訂規則機制**。

#### 🛠️ 運作原理與優勢
1.  **繞過 `RETURN` 缺陷**：控制器會將 ConfigMap 內定義的規則編譯進 `MULTI-INGRESS-COMMON` 鏈。該鏈在 `MULTI-INGRESS` 鏈的最起點即被呼叫，此時還未進入個別 Policy 的 sub-chain，因此完全不受 unconditional `RETURN` 規則的干擾。
2.  **日誌收集相容性**：透過在 ConfigMap 中寫入 `iptables -j LOG` 規則，封包會被記錄到宿主機的 `syslog` / `dmesg` 中。若 fluent-bit 有收集節點日誌，即可自動將其送往 OpenSearch。
3.  **無須存取 Guest OS**：所有變更均在 Kubernetes 控制面（ConfigMap）進行，VM 內部完全無感。

#### 📝 設定步驟

##### Step 1: 修改 kube-system 中的自訂規則 ConfigMap
修改 `kube-system` 命名空間下的 `multi-networkpolicy-custom-v4-rules` ConfigMap。
利用 `iprange` 模組指定需要監控的來源 IP 範圍，並將目標 IP 鎖定在該 VM 的附加網路 IP（如 `10.10.100.100`）：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-networkpolicy-custom-v4-rules
  namespace: kube-system
data:
  custom-v4-rules.txt: |
    # 1. 既有 ICMP 規則 (保留)
    -p icmp --icmp-type redirect -j ACCEPT
    -p icmp --icmp-type fragmentation-needed -j ACCEPT
    
    # 2. 流量稽核日誌規則：針對目標 VM 與預計保留的 IP 範圍進行 LOG 記錄
    -d 10.10.100.100 -m iprange --src-range 10.10.1.1-10.10.1.10 -j LOG --log-prefix "KUBEVIRT-INGRESS-AUDIT: "
```

##### Step 2: 重啟控制器以載入規則
重啟各個 Worker 節點上的 `multi-networkpolicy` 守護行程（DaemonSet），以將新規則同步進 Pod 的 Network Namespace：
```bash
kubectl rollout restart daemonset multi-networkpolicy-ds-amd64 -n kube-system
```

##### Step 3: 進入 Pod Namespace 檢查規則是否生效
在 Worker 節點上執行以下指令，確認 `MULTI-INGRESS-COMMON` 內已成功載入自訂 LOG 規則：
```bash
sudo nsenter -t <virt-launcher-PID> -n iptables -t filter -S MULTI-INGRESS-COMMON
# 預期輸出包含：
# -A MULTI-INGRESS-COMMON -d 10.10.100.100/32 -m iprange --src-range 10.10.1.1-10.10.1.10 -j LOG --log-prefix "KUBEVIRT-INGRESS-AUDIT: "
```

##### Step 4: 流量觀測與策略收斂
1.  **維持舊 RuleA 運作**：此時 `MultiNetworkPolicy` 中的舊 `ruleA`（放行 `10.10.1.1 ~ 100`）依然維持原狀，確保業務流量不中斷。
2.  **檢視 OpenSearch 日誌**：在 OpenSearch Dashboards 中搜尋關鍵字 `KUBEVIRT-INGRESS-AUDIT:`：
    *   **有日誌產生**：代表 `10.10.1.1 ~ 10` 確實有匹配的流量通過。
    *   **無日誌產生**（經過一段觀察期）：代表該範圍可能無流量。
3.  **執行收斂（Shrink）**：
    *   確認新的縮減範圍（`10` 以內）確實涵蓋了主要流量後，大膽地將 `MultiNetworkPolicy` 中的 `ruleA` 編輯為僅放行 `10.10.1.1 ~ 10.10.1.10`（更新 CRD）。
4.  **清理環境**：收斂完成後，將 ConfigMap 中新增的 `LOG` 規則刪除，並再次重啟 DaemonSet，以避免長久下來產生海量日誌影響硬碟與系統效能。



