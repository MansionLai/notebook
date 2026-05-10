---
title: Phase 4 - RBD Pool 建立
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 14
permalink: /storage/3node-ceph/phase-4/
---

# Phase 4 — RBD Pool 建立

## 目標

建立 RBD block storage pool (`rbdpool`)，設定 replication 參數，並驗證 pool 可用性。

---

## Step 4-1：建立 RBD Pool

在 `ceph-node-01` 執行：

```bash
# 建立 pool，設定 pg_num 與 pgp_num
sudo ceph osd pool create rbdpool 128 128
```

**預期輸出：**

```
pool 'rbdpool' created
```

**參數說明：**

- `rbdpool`: pool 名稱
- `128`: pg_num (Placement Group 數量)
- `128`: pgp_num (Placement Group for placement 數量)

> 💡 **PG 數量計算：** 對於 6 顆 OSD、size=3 的 pool，128 PG 是合理起點（每 OSD 約分配 64 PG）

---

## Step 4-2：設定 Pool 參數

```bash
# 設定 replication size（每個 object 複製 3 份）
sudo ceph osd pool set rbdpool size 3

# 設定 min_size（至少 1 份可用即可寫入）
sudo ceph osd pool set rbdpool min_size 1
```

**參數說明：**

- `size 3`: 每個 object 在 cluster 中複製 3 份
- `min_size 1`: 當可用 OSD 少於 3 時，只要至少有 1 份可用即可繼續寫入（降級模式）

> ⚠️ **生產環境建議：** `min_size` 建議設為 2，避免單一副本時資料遺失風險

驗證設定：

```bash
sudo ceph osd pool get rbdpool size
sudo ceph osd pool get rbdpool min_size
sudo ceph osd pool get rbdpool pg_num
sudo ceph osd pool get rbdpool pgp_num
```

---

## Step 4-3：啟用 RBD 應用

```bash
# 啟用 rbd 應用標記
sudo ceph osd pool application enable rbdpool rbd
```

**預期輸出：**

```
enabled application 'rbd' on pool 'rbdpool'
```

初始化 RBD pool：

```bash
# 初始化 RBD pool
sudo rbd pool init rbdpool
```

---

## Step 4-4：建立測試 RBD Image

```bash
# 建立 10 GiB 測試 image
sudo rbd create --size 10G rbdpool/test-image

# 列出 images
sudo rbd ls rbdpool
```

**預期輸出：**

```
test-image
```

查看 image 詳細資訊：

```bash
sudo rbd info rbdpool/test-image
```

**預期輸出：**

```
rbd image 'test-image':
    size 10 GiB in 2560 objects
    order 22 (4 MiB objects)
    snapshot_count: 0
    id: <IMAGE_ID>
    block_name_prefix: rbd_data.<IMAGE_ID>
    format: 2
    features: layering, exclusive-lock, object-map, fast-diff, deep-flatten
    op_features: 
    flags: 
    create_timestamp: ...
    access_timestamp: ...
    modify_timestamp: ...
```

---

## Step 4-5：驗證 Pool 狀態

檢查 pool 列表：

```bash
sudo ceph osd pool ls detail
```

**預期輸出：**

```
pool 1 'rbdpool' replicated size 3 min_size 1 crush_rule 0 object_hash rjenkins pg_num 128 pgp_num 128 autoscale_mode on last_change ... flags hashpspool,selfmanaged_snaps stripe_width 0 application rbd
```

檢查 pool 使用量：

```bash
sudo ceph df
```

**預期輸出：**

```
--- RAW STORAGE ---
CLASS     SIZE    AVAIL     USED  RAW USED  %RAW USED
hdd      360 GiB  360 GiB  1.0 GiB   1.0 GiB       0.28
TOTAL    360 GiB  360 GiB  1.0 GiB   1.0 GiB       0.28

--- POOLS ---
POOL       ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
rbdpool     1  128      0 B        1      0 B      0    114 GiB
```

檢查 PG 狀態：

```bash
sudo ceph pg stat
```

**預期輸出：**

```
128 pgs: 128 active+clean; 0 B data, 1.0 GiB used, 360 GiB / 360 GiB avail
```

---

## Step 4-6：測試 Image Map 與 Unmap（可選）

```bash
# Map image 到本地
sudo rbd map rbdpool/test-image

# 檢查 mapped devices
sudo rbd showmapped
```

**預期輸出：**

```
id  pool     namespace  image       snap  device   
0   rbdpool             test-image  -     /dev/rbd0
```

格式化與掛載（可選測試）：

```bash
# 格式化為 ext4
sudo mkfs.ext4 /dev/rbd0

# 建立掛載點
sudo mkdir -p /mnt/rbd-test

# 掛載
sudo mount /dev/rbd0 /mnt/rbd-test

# 寫入測試檔案
echo "Hello Ceph RBD" | sudo tee /mnt/rbd-test/test.txt

# 驗證
cat /mnt/rbd-test/test.txt
```

清理：

```bash
# 卸載
sudo umount /mnt/rbd-test

# Unmap
sudo rbd unmap /dev/rbd0

# 驗證
sudo rbd showmapped
# 應該沒有輸出
```

---

## Step 4-7：驗證 Replication

建立第二個測試 image 並檢查資料分布：

```bash
# 建立另一個 image
sudo rbd create --size 5G rbdpool/test-image-2

# 列出所有 images
sudo rbd ls rbdpool
```

檢查 objects 分布：

```bash
# 檢查 pool 統計
sudo ceph osd pool stats rbdpool
```

檢查 PG 分布：

```bash
# 檢查 PG 在 OSD 上的分布
sudo ceph pg dump pgs | grep rbdpool | head -20
```

---

## 驗證清單

完成此 Phase 後，確認以下項目：

| 項目 | 驗證方式 | 預期結果 |
|------|---------|---------|
| Pool 建立 | `sudo ceph osd pool ls` | rbdpool 存在 |
| Size 設定 | `sudo ceph osd pool get rbdpool size` | size: 3 |
| Min_size 設定 | `sudo ceph osd pool get rbdpool min_size` | min_size: 1 |
| PG 數量 | `sudo ceph osd pool get rbdpool pg_num` | pg_num: 128 |
| RBD 應用啟用 | `sudo ceph osd pool ls detail` | application rbd |
| Test image 建立 | `sudo rbd ls rbdpool` | test-image 存在 |
| Pool 狀態 | `sudo ceph df` | rbdpool 顯示 |
| PG 狀態 | `sudo ceph pg stat` | 128 active+clean |

---

## 參數總覽

| 參數 | 設定值 | 說明 |
|------|--------|------|
| Pool Name | `rbdpool` | RBD block storage pool |
| `size` | 3 | 每個 object 複製 3 份 |
| `min_size` | 1 | 至少 1 份可用即可寫入（降級模式） |
| `pg_num` | 128 | Placement Group 數量 |
| `pgp_num` | 128 | PG for placement 數量 |
| Application | `rbd` | 啟用 RBD 應用 |

---

## 預期產出

- ✅ `rbdpool` 建立成功
- ✅ Pool 參數設定正確（size=3, min_size=1, pg_num=128）
- ✅ RBD 應用已啟用
- ✅ 測試 image 可建立與列出
- ✅ Pool 狀態正常（128 PG active+clean）
- ✅ RBD image 可 map/unmap（可選驗證）
- ✅ Ceph 3-node cluster 完全可用

---

## 下一步

至此，Ceph 3-node cluster 與 RBD pool 已完全建立並可用。後續可考慮：

- 整合 Kubernetes CSI driver
- 設定 CephFS（如需共享檔案系統）
- 啟用 Ceph Dashboard 監控
- 調整 PG autoscaling
- 設定 CRUSH rules
- 效能測試與調校
