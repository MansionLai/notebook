---
title: Phase 2 - Ceph 安裝
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 12
permalink: /storage/3node-ceph/phase-2/
---

# Phase 2 — Ceph 安裝

## 目標

在三台節點安裝 Ceph v19.2.2 (Reef)，並準備好 cephadm bootstrap。

---

## Step 2-1：安裝 Docker

Ceph 使用容器化部署，需要 Docker 或 Podman。本文使用 Docker。

在所有三台節點執行：

```bash
# 安裝 Docker
sudo apt install -y docker.io

# 啟動 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 驗證 Docker
sudo docker --version
sudo docker ps
```

將當前使用者加入 docker 群組（可選）：

```bash
sudo usermod -aG docker ubuntu
# 需重新登入生效
```

---

## Step 2-2：安裝 Cephadm

在所有三台節點執行：

```bash
# 下載 cephadm
curl --silent --remote-name --location https://download.ceph.com/rpm-19.2.2/el9/noarch/cephadm

# 設定執行權限
chmod +x cephadm

# 移動到系統路徑
sudo mv cephadm /usr/local/bin/

# 驗證 cephadm
cephadm version
```

**預期輸出：**

```
ceph version 19.2.2 (...)
```

---

## Step 2-3：安裝 Ceph CLI（可選，bootstrap 後自動安裝）

在 `ceph-node-01` 執行（或所有節點）：

```bash
# 使用 cephadm 安裝 ceph-common
sudo cephadm install ceph-common
```

驗證：

```bash
ceph --version
```

**預期輸出：**

```
ceph version 19.2.2 (...)
```

---

## Step 2-4：準備 SSH Key（用於 cephadm 管理）

在 `ceph-node-01` 生成 SSH key（如果尚未存在）：

```bash
# 生成 SSH key
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# 將 public key 複製到所有節點
ssh-copy-id ubuntu@ceph-node-01
ssh-copy-id ubuntu@ceph-node-02
ssh-copy-id ubuntu@ceph-node-03
```

驗證無密碼 SSH：

```bash
ssh ubuntu@ceph-node-02 "hostname"
ssh ubuntu@ceph-node-03 "hostname"
# 應該可以直接登入並回傳 hostname
```

---

## Step 2-5：檢查 Ceph 相關 Ports

確保 NSG 允許以下 ports（應該在 Phase 0 已設定）：

| Port | 用途 |
|------|------|
| 6789 | Ceph MON (legacy) |
| 3300 | Ceph MON v2 protocol |
| 6800-7300 | Ceph OSD |
| 8443 | Ceph Dashboard (HTTPS) |

從 `ceph-node-01` 測試 ports 連通性：

```bash
# 測試 MON port
nc -zv 10.10.10.11 3300
nc -zv 10.10.10.12 3300

# 如果 nc 不存在，安裝：
sudo apt install -y netcat-openbsd
```

---

## Step 2-6：禁用 Swap（Ceph 建議）

在所有三台節點執行：

```bash
# 關閉 swap
sudo swapoff -a

# 永久禁用（編輯 /etc/fstab）
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 驗證
free -h
# Swap 應顯示 0
```

---

## Step 2-7：設定 Kernel 參數（可選，提升效能）

在所有三台節點執行：

```bash
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Ceph OSD performance tuning
kernel.pid_max = 4194303
fs.file-max = 26234859
vm.zone_reclaim_mode = 0
vm.swappiness = 0
vm.min_free_kbytes = 4194304
EOF

# 套用設定
sudo sysctl -p
```

---

## 驗證清單

完成此 Phase 後，確認以下項目：

| 項目 | 驗證方式 | 預期結果 |
|------|---------|---------|
| Docker 安裝 | `sudo docker --version` | Docker 版本顯示 |
| Docker 運行 | `sudo systemctl status docker` | active (running) |
| cephadm 安裝 | `cephadm version` | ceph version 19.2.2 |
| ceph CLI 安裝 | `cephadm shell -- ceph --version` | ceph version 19.2.2 |
| SSH key 設定 | `ssh ubuntu@ceph-node-02 hostname` | 無密碼登入成功 |
| Swap 禁用 | `free -h` | Swap: 0B |

---

## 預期產出

- ✅ Docker 已安裝並運行於三台節點
- ✅ cephadm 19.2.2 已安裝於三台節點
- ✅ ceph CLI 已安裝於 ceph-node-01
- ✅ SSH key 已設定，ceph-node-01 可無密碼登入所有節點
- ✅ Swap 已禁用
- ✅ 準備好進行 Ceph cluster bootstrap
