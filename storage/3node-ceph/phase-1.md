---
title: Phase 1 - OS 準備
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 11
permalink: /storage/3node-ceph/phase-1/
---

# Phase 1 — OS 準備

## 目標

完成三台節點的作業系統初始化，包括 hostname、hosts 檔案、網路驗證與磁碟檢查。

---

## Step 1-1：SSH 登入與基礎套件

在所有三台節點執行：

```bash
# 更新套件列表
sudo apt update

# 安裝基礎工具
sudo apt install -y \
  curl \
  wget \
  net-tools \
  vim \
  htop \
  lsof \
  chrony
```

---

## Step 1-2：設定 Hostname

在每台節點分別設定：

**ceph-node-01:**

```bash
sudo hostnamectl set-hostname ceph-node-01
```

**ceph-node-02:**

```bash
sudo hostnamectl set-hostname ceph-node-02
```

**ceph-node-03:**

```bash
sudo hostnamectl set-hostname ceph-node-03
```

驗證：

```bash
hostnamectl
# 應顯示對應的 hostname
```

---

## Step 1-3：設定 /etc/hosts

在所有三台節點執行（編輯 `/etc/hosts`）：

```bash
sudo tee -a /etc/hosts > /dev/null <<EOF

# Ceph Public Network
10.10.10.10  ceph-node-01
10.10.10.11  ceph-node-02
10.10.10.12  ceph-node-03

# Ceph Cluster Network
172.10.10.10  ceph-node-01-cls
172.10.10.11  ceph-node-02-cls
172.10.10.12  ceph-node-03-cls
EOF
```

驗證：

```bash
cat /etc/hosts | grep ceph
```

---

## Step 1-4：驗證雙 NIC 與 IP

在每台節點執行：

```bash
ip addr show
```

**ceph-node-01 預期輸出：**

```
eth0: 10.10.10.10/24
eth1: 172.10.10.10/24
```

**ceph-node-02 預期輸出：**

```
eth0: 10.10.10.11/24
eth1: 172.10.10.11/24
```

**ceph-node-03 預期輸出：**

```
eth0: 10.10.10.12/24
eth1: 172.10.10.12/24
```

---

## Step 1-5：驗證雙網路連通性

從 `ceph-node-01` 測試：

```bash
# 測試 Public Network
ping -c 3 10.10.10.11
ping -c 3 10.10.10.12

# 測試 Cluster Network
ping -c 3 172.10.10.11
ping -c 3 172.10.10.12

# 使用 hostname 測試
ping -c 3 ceph-node-02
ping -c 3 ceph-node-03
ping -c 3 ceph-node-02-cls
ping -c 3 ceph-node-03-cls
```

從 `ceph-node-02` 與 `ceph-node-03` 執行類似測試，確保全部節點互通。

---

## Step 1-6：驗證磁碟配置

在所有三台節點執行：

```bash
lsblk
```

**預期輸出：**

```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   64G  0 disk 
├─sda1   8:1    0   64G  0 part /
sdb      8:16   0   X G  0 disk              # Azure temporary disk
sdc      8:32   0   64G  0 disk              # OSD disk 1
sdd      8:48   0   64G  0 disk              # OSD disk 2
```

> ⚠️ `sdb` 是 Azure temporary disk，不可用於 OSD

檢查 OSD disks 未被格式化或掛載：

```bash
sudo blkid /dev/sdc
sudo blkid /dev/sdd
# 應該沒有輸出（空白磁碟）
```

檢查磁碟狀態：

```bash
sudo fdisk -l | grep -E '(sdc|sdd)'
```

---

## Step 1-7：時間同步設定

Ceph 對時間敏感，確保 chrony 正常運作：

```bash
# 檢查 chrony 狀態
sudo systemctl status chrony

# 驗證時間同步
chronyc tracking

# 檢查時間來源
chronyc sources
```

在所有節點確保時間差異在合理範圍內（<10ms）：

```bash
date
```

---

## Step 1-8：防火牆檢查

Ubuntu 預設可能啟用 ufw，建議在 lab 環境關閉（NSG 已提供保護）：

```bash
# 檢查 ufw 狀態
sudo ufw status

# 如果啟用，建議關閉（lab 環境）
sudo ufw disable
```

> 💡 **生產環境建議：** 在生產環境應保持 ufw 啟用並設定正確規則

---

## 驗證清單

完成此 Phase 後，確認以下項目：

| 項目 | 驗證方式 | 預期結果 |
|------|---------|---------|
| Hostname 設定 | `hostnamectl` | 顯示對應 hostname |
| /etc/hosts 設定 | `cat /etc/hosts` | 包含 3 台節點 IP 與 hostname |
| 雙 NIC 存在 | `ip addr show` | eth0 + eth1 各有正確 IP |
| Public Network 互通 | `ping 10.10.10.x` | 正常回應 |
| Cluster Network 互通 | `ping 172.10.10.x` | 正常回應 |
| Hostname 解析 | `ping ceph-node-0x` | 正常回應 |
| OSD Disks 存在 | `lsblk` | /dev/sdc 與 /dev/sdd 存在 |
| OSD Disks 未格式化 | `sudo blkid /dev/sdc` | 無輸出 |
| 時間同步 | `chronyc tracking` | System time 正確 |

---

## 預期產出

- ✅ 三台節點 hostname 正確設定
- ✅ `/etc/hosts` 包含全部節點
- ✅ 雙網路完全互通（public + cluster）
- ✅ 2 顆 OSD disks 存在且未格式化
- ✅ 時間同步正常
- ✅ 準備好進入 Ceph 安裝階段
