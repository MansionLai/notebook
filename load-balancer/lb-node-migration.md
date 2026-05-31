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
   - master02/slave02 的 keepalived.conf `vrrp_instance` 內 `unicast_peer` 同時包含 master01/slave01 及 master02/slave02
   - 將 master02/slave02 的 `priority` 設定高於 master01/slave01
   - 其餘 VRRP 設定（如 interface、virtual_ipaddress）與舊節點一致

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
       unicast_peer {
           192.168.50.211   # master01
           192.168.50.212   # slave01
           192.168.50.213   # master02
           192.168.50.214   # slave02
       }
   }
   ```

3. **啟動 master02/slave02 的 Keepalived**
   - 觀察 syslog 或 `ip a`，確認 VIP 是否已經由 master02 接管
   - 可用 `arping` 或 `ping` 驗證 VIP 是否正確浮動到新節點

4. **觀察舊節點行為**
   - master01/slave01 會自動偵測到有更高 priority 的 VRRP 廣播，並切換為 BACKUP 狀態
   - 不需更動舊節點任何設定

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

---

如需詳細設定範例，請參考 `keepalived-config.md`。
