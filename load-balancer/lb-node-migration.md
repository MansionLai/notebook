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

2. **設定 Keepalived（多 peer 範例）**
   - master02/slave02 的 keepalived.conf `vrrp_instance` 內 `unicast_peer` 同時包含 master01/slave01 及 master02/slave02 (即：**遷移期間列表應包含所有 4 個節點**)
   - 將 master02/slave02 的 `priority` 設定高於 master01/slave01
   - 其餘 VRRP 設定（如 interface、virtual_ipaddress）與舊節點一致
   - **關鍵提示**：確認新舊節點的 `virtual_router_id` 必須完全一致（範例為 51），否則無法正確競爭 VIP。

   **範例 keepalived.conf（以 master02/slave02 為例）：**

   ```conf
   vrrp_instance VI_1 {
       state BACKUP
       interface <bridge-iface>
       virtual_router_id 51
       priority 110                # 高於舊節點
       advert_int 1
       nopreempt
       authentication {
           auth_type PASS
           auth_pass LB2024secret
       }
       virtual_ipaddress {
           192.168.50.250/24
       }
       unicast_src_ip 192.168.50.213   # 本機 IP (以 master02 為例)
       unicast_peer {
           192.168.50.211   # master01
           192.168.50.212   # slave01
           192.168.50.214   # slave02
       }
   }
   ```

3. **啟動 master02/slave02 的 Keepalived**
   - 啟動後，由於設定了 `nopreempt`，master02 雖然 priority 較高，但不會主動搶佔 master01 的 VIP。
   - **手動切換方式 A (建議)**：停止 master01 的 keepalived (`sudo systemctl stop keepalived`)，VIP 會立刻漂移到 master02。
   - **手動切換方式 B**：在 master02 設定中暫時移除 `nopreempt` 並重啟，它會主動奪取 VIP，隨後再加回 `nopreempt` 以維持穩定。

4. **觀察 VIP 轉移**
   - 確認 VIP 是否已經由 master02 接管 (`ip a`)。
   - 舊節點 master01 如果還沒關閉，會因為收到更高 priority 的廣播而維持在 BACKUP 狀態。

5. **驗證服務流量**
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

parent: Load Balancer
nav_order: 98
---

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
| 12:00:00    | 遷移前 baseline         | master01         | OK             |                |
| 12:01:00    | 啟動 master02 keepalived| master02         | 1~2 秒 FAIL    | VIP 轉移瞬斷   |
| 12:01:02    | VIP 穩定於 master02     | master02         | OK             |                |
| 12:02:00    | 關閉 master01 keepalived| master02         | OK             | 無影響         |
| 12:03:00    | peer 只留新節點         | master02/slave02 | OK             | 無影響         |

- 觀察結果：VIP 轉移時 client 連線約有 1~2 秒斷線，之後恢復正常。
- 若應用有 session/長連線，建議加強重試/容錯。

如需詳細設定範例，請參考 `keepalived-config.md`。
