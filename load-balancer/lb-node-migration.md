---
title: 節點線上遷移與 VIP 轉移
parent: Load Balancer
nav_order: 98
---

# Load Balancer Node Online Migration

> 本文件說明如何在不更動現有 master01/slave01 設定下，將 VIP 線上轉移到全新 master02/slave02 節點，並最終下線舊節點。

## 節點規劃

| 角色      | 主機名      | IP              |
|-----------|-------------|-----------------|
| Master01  | lb-master01 | 192.168.50.211  |
| Slave01   | lb-slave01  | 192.168.50.212  |
| Master02  | lb-master02 | 192.168.50.213  |
| Slave02   | lb-slave02  | 192.168.50.214  |
| VIP       | --          | 192.168.50.250  |

## 遷移目標
- 不更動 master01/slave01 設定
- VIP 線上平滑轉移到 master02/slave02
- 最終下線 master01/slave01

## 建議步驟

1. **在 master02/slave02 完成 HAProxy 與 backend service 配置**
   - 確認新節點可正常代理流量

2. **設定 Keepalived（單向 Peer 自動搶佔）**
   - **優點**：不需更動任何 master01/slave01 的現有設定。
   - master02/slave02 的 `vrrp_instance` 內 `unicast_peer` 列表包含 **舊節點主機** 及 **新節點配對**。
   - 將 master02/slave02 的 `priority` 設定高於 master01/slave01。
   - **關鍵：不設定 `nopreempt`**。這會讓新節點一啟動就主動發送 VRRP 宣告，強制舊節點讓出 VIP。

   **範例 keepalived.conf（以 master02 為例）：**

   ```conf
   vrrp_instance VI_1 {
       state BACKUP
       interface <bridge-iface>
       virtual_router_id 51
       priority 110                # 高於舊節點 (100)
       advert_int 1
       # 不設定 nopreempt，實現自動搶佔
       authentication {
           auth_type PASS
           auth_pass LB2024secret
       }
       virtual_ipaddress {
           192.168.50.250/24
       }
       unicast_src_ip 192.168.50.213   # master02 IP
       unicast_peer {
           192.168.50.211   # master01 (搶佔對象)
           192.168.50.212   # slave01 (搶佔對象)
           192.168.50.214   # slave02 (新節點配對)
       }
   }
   ```

3. **啟動 master02/slave02 的 Keepalived**
   - 啟動後，master02 會立即向 `unicast_peer` 列表發送 priority 110 的宣告。
   - 舊 Master (master01) 接收到更高 priority 的封包後，會**自動轉換為 BACKUP 狀態**並釋放 VIP。
   - 此過程完全自動化，不需手動干預舊節點。

4. **觀察 VIP 轉移**
   - 確認 VIP 是否已經由 master02 接管 (`ip a`)。
   - 觀察 `lb-master01` 日誌，應看到 `Master received advert from ... with higher priority` 訊息。

5. **驗證與清理**
   - 確認 VIP 流量已經由 master02/slave02 處理
   - 可逐步將流量導向新節點，觀察應用層健康狀態

6. **下線舊節點**
   - 確認新節點穩定後，關閉 master01/slave01 的 keepalived 或直接關機
   - VIP 會持續由 master02/slave02 維護

7. **最終 peer 清理**
   - 確認 master01/slave01 已下線後，建議將 master02/slave02 的 keepalived.conf 內 `unicast_peer` 列表只保留 master02/slave02：

   ```conf
   unicast_peer {
       192.168.50.213   # master02
       192.168.50.214   # slave02
   }
   ```
   - 重新啟動 keepalived 以套用設定

## 原理說明
- VRRP 協定會根據 priority 決定誰是 MASTER
- 舊節點雖不知新節點存在，但收到更高 priority 的 VRRP 廣播會自動降級
- 只要 peer 設定正確，VIP 可無縫轉移

## 注意事項
- 新舊節點 VRRP group、virtual_router_id、auth 必須一致
- 建議先在測試環境驗證流程
- 若有自動化監控，記得調整監控目標

## 實測流程與紀錄

### 實驗設計
- 於 client 端持續執行：
  ```bash
  while true; do date +%T; curl -s --max-time 1 http://192.168.50.250/health || echo "FAIL"; sleep 1; done
  ```
- 依文件步驟進行 VIP 遷移，並於每步驟記錄 VIP 位置與 client 連線狀態

### 測試紀錄
| 時間        | 操作步驟                | VIP 位置         | client 連線狀態 | 備註           |
|-------------|-------------------------|------------------|----------------|----------------|
| 15:20:00    | 建立 master01/slave01   | master01         | OK             | 初始環境       |
| 15:25:00    | 啟動 master02 (高優先)  | master02         | < 1s 抖動      | **自動搶佔成功** |
| 15:25:05    | 驗證 master01 狀態      | master02         | OK             | M1 自動轉 BACKUP |
| 15:30:00    | 最終服務驗證            | master02         | OK             | 無縫連線       |

- 觀察結果：在 Unicast 模式下，新節點啟動後舊節點能正確接收高優先級封包並自動讓權，Client 端幾乎無感（僅毫秒級切換）。

如需詳細設定範例，請參考 `keepalived-config.md`。
