---
title: Commands
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 21
permalink: /storage/3node-ceph/commands/
---

# Ceph 3-Node Commands Reference

這份文件整理所有 Ceph 3-node 建置與管理指令，依功能分類。適合快速查詢與複製使用。

---

## Azure Phase 0（Azure MCP + Bicep）

本節以 Azure MCP + Bicep 為主，建議以 Bicep 檔案進行資源生命週期管理，統一命名採用 mansion_ 前綴。

### Bicep 檔案與參數準備

請直接使用 `storage/3node-ceph/iac/` 內的：

- `main.bicep`
- `main.bicepparam`
- `README.md`

部署前請至少覆寫：

- `allowedSourceCidr`
- `adminPublicKey`
- `location`（若不是預設 region）

### What-If 預覽

> **前置步驟：請先建立目標 Resource Group**

```bash
az group create --name mansion_ceph_resource --location <your-location>
```

```bash
az deployment group what-if \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0-preview \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 套用 Deployment

```bash
az deployment group create \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 查詢 Deployment Outputs

```bash
az deployment group show \
  --resource-group mansion_ceph_resource \
  --name mansion-ceph-phase0 \
  --query properties.outputs
```

### 查詢 VM / NIC / Disk 狀態

```bash
# 查詢所有 VM 狀態
az vm list -d -g mansion_ceph_resource -o table

# 查詢所有 NIC
az network nic list -g mansion_ceph_resource -o table

# 查詢所有 Disk
az disk list -g mansion_ceph_resource -o table
```

### 整批刪除 Resource Group

```bash
az group delete --name mansion_ceph_resource --yes --no-wait
```

> 💡 建議所有資源命名皆以 mansion_ 為前綴，便於 lab 管理與辨識。

---

---

## OS 與網路準備

### 基礎套件安裝

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
  chrony \
  netcat-openbsd
```

### Hostname 設定

```bash
# 在 ceph-node-01
sudo hostnamectl set-hostname ceph-node-01

# 在 ceph-node-02
sudo hostnamectl set-hostname ceph-node-02

# 在 ceph-node-03
sudo hostnamectl set-hostname ceph-node-03

# 驗證 hostname
hostnamectl
```

### /etc/hosts 設定

```bash
# 在所有節點執行
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

# 驗證
cat /etc/hosts | grep ceph
```

### 網路驗證

```bash
# 檢查雙 NIC
ip addr show

# 測試 Public Network 連通性
ping -c 3 10.10.10.11
ping -c 3 10.10.10.12

# 測試 Cluster Network 連通性
ping -c 3 172.10.10.11
ping -c 3 172.10.10.12

# 使用 hostname 測試
ping -c 3 ceph-node-02
ping -c 3 ceph-node-03
ping -c 3 ceph-node-02-cls
ping -c 3 ceph-node-03-cls
```

### 時間同步

```bash
# 檢查 chrony 狀態
sudo systemctl status chrony

# 驗證時間同步
chronyc tracking

# 檢查時間來源
chronyc sources

# 檢查當前時間
date
```

### 防火牆設定

```bash
# 檢查 ufw 狀態
sudo ufw status

# Lab 環境建議關閉（NSG 已提供保護）
sudo ufw disable
```

---

## 磁碟檢查

### 列出磁碟

```bash
# 列出所有 block devices
lsblk

# 詳細磁碟資訊
sudo fdisk -l

# 檢查特定磁碟未被格式化
sudo blkid /dev/sdc
sudo blkid /dev/sdd
# 應該沒有輸出（空白磁碟）
```

### 檢查磁碟狀態

```bash
# 檢查 OSD disks
sudo fdisk -l | grep -E '(sdc|sdd)'

# 檢查磁碟 SMART 資訊（需安裝 smartmontools）
sudo apt install -y smartmontools
sudo smartctl -a /dev/sdc
sudo smartctl -a /dev/sdd
```

---

## Ceph 安裝

### Docker 安裝

```bash
# 安裝 Docker
sudo apt install -y docker.io

# 啟動 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 驗證 Docker
sudo docker --version
sudo docker ps

# 將使用者加入 docker 群組（可選，需重新登入）
sudo usermod -aG docker ubuntu
```

### Cephadm 安裝

```bash
# 下載 cephadm v19.2.2
curl --silent --remote-name --location https://download.ceph.com/rpm-19.2.2/el9/noarch/cephadm

# 設定執行權限
chmod +x cephadm

# 移動到系統路徑
sudo mv cephadm /usr/local/bin/

# 驗證 cephadm 版本
cephadm version
```

### Ceph CLI 安裝

```bash
# 使用 cephadm 安裝 ceph-common（在 ceph-node-01 或所有節點）
sudo cephadm install ceph-common

# 驗證 ceph CLI
ceph --version
```

### SSH Key 準備

```bash
# 在 ceph-node-01 生成 SSH key
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# 將 public key 複製到所有節點
ssh-copy-id ubuntu@ceph-node-01
ssh-copy-id ubuntu@ceph-node-02
ssh-copy-id ubuntu@ceph-node-03

# 驗證無密碼 SSH
ssh ubuntu@ceph-node-02 "hostname"
ssh ubuntu@ceph-node-03 "hostname"
```

### Swap 禁用

```bash
# 關閉 swap
sudo swapoff -a

# 永久禁用（編輯 /etc/fstab）
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 驗證（Swap 應顯示 0）
free -h
```

### Kernel 參數調整

```bash
# 設定 Ceph OSD 效能參數
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

## Cephadm Bootstrap

### Bootstrap 第一台節點

```bash
# 在 ceph-node-01 執行 bootstrap（記得替換 <YOUR_PASSWORD>）
sudo cephadm bootstrap \
  --mon-ip 10.10.10.10 \
  --cluster-network 172.10.10.0/24 \
  --initial-dashboard-user admin \
  --initial-dashboard-password <YOUR_PASSWORD> \
  --allow-fqdn-hostname \
  --skip-monitoring-stack

# 驗證 bootstrap 成功
sudo ceph -s
```

### 網路設定

```bash
# 確認網路設定
sudo ceph config get mon public_network
sudo ceph config get mon cluster_network

# 設定 public_network（如需修改）
sudo ceph config set mon public_network 10.10.10.0/24

# 設定 cluster_network
sudo ceph config set global cluster_network 172.10.10.0/24
```

---

## 加入節點

### 加入其他節點到 Cluster

```bash
# 在 ceph-node-01 執行

# 加入 ceph-node-02
sudo ceph orch host add ceph-node-02 10.10.10.11

# 加入 ceph-node-03
sudo ceph orch host add ceph-node-03 10.10.10.12

# 驗證節點加入
sudo ceph orch host ls
```

---

## MON 與 MGR 部署

### MON 部署

```bash
# 設定 MON 部署到 3 個節點
sudo ceph orch apply mon --placement="3 ceph-node-01 ceph-node-02 ceph-node-03"

# 監控 MON 部署（約 1-2 分鐘）
sudo ceph orch ps --daemon-type mon

# 驗證 MON quorum
sudo ceph mon stat
sudo ceph mon dump
```

### MGR 部署

```bash
# 設定 MGR 部署到 3 個節點（active + standby）
sudo ceph orch apply mgr --placement="3 ceph-node-01 ceph-node-02 ceph-node-03"

# 驗證 MGR 狀態
sudo ceph orch ps --daemon-type mgr

# 檢查 MGR
sudo ceph -s
```

---

## OSD 加入

### 列出可用磁碟

```bash
# 列出可用磁碟
sudo ceph orch device ls

# 應看到 /dev/sdc 與 /dev/sdd 在三台節點上都可用
```

### 方法 1：手動逐一加入 OSD

```bash
# ceph-node-01
sudo ceph orch daemon add osd ceph-node-01:/dev/sdc
sudo ceph orch daemon add osd ceph-node-01:/dev/sdd

# ceph-node-02
sudo ceph orch daemon add osd ceph-node-02:/dev/sdc
sudo ceph orch daemon add osd ceph-node-02:/dev/sdd

# ceph-node-03
sudo ceph orch daemon add osd ceph-node-03:/dev/sdc
sudo ceph orch daemon add osd ceph-node-03:/dev/sdd
```

### 方法 2：自動加入所有可用磁碟

```bash
# 自動將所有可用磁碟加入為 OSD
sudo ceph orch apply osd --all-available-devices

# 監控 OSD 建立進度（約 2-5 分鐘）
watch sudo ceph -s
```

### OSD 驗證

```bash
# 檢查 OSD tree
sudo ceph osd tree

# 檢查 OSD 統計
sudo ceph osd stat

# 檢查 OSD 磁碟使用量
sudo ceph osd df
```

---

## RBD Pool 建立與設定

### 建立 Pool

```bash
# 建立 rbdpool（128 PG）
sudo ceph osd pool create rbdpool 128 128
```

### 設定 Pool 參數

```bash
# 設定 replication size（每個 object 複製 3 份）
sudo ceph osd pool set rbdpool size 3

# 設定 min_size（至少 1 份可用即可寫入）
sudo ceph osd pool set rbdpool min_size 1

# 驗證設定
sudo ceph osd pool get rbdpool size
sudo ceph osd pool get rbdpool min_size
sudo ceph osd pool get rbdpool pg_num
sudo ceph osd pool get rbdpool pgp_num
```

### 啟用 RBD 應用

```bash
# 啟用 rbd 應用標記
sudo ceph osd pool application enable rbdpool rbd

# 初始化 RBD pool
sudo rbd pool init rbdpool
```

---

## RBD Image 測試

### 建立測試 Image

```bash
# 建立 10 GiB 測試 image
sudo rbd create --size 10G rbdpool/test-image

# 列出 images
sudo rbd ls rbdpool

# 查看 image 詳細資訊
sudo rbd info rbdpool/test-image
```

### Map 與掛載測試

```bash
# Map image 到本地
sudo rbd map rbdpool/test-image

# 檢查 mapped devices
sudo rbd showmapped

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

### 清理測試

```bash
# 卸載
sudo umount /mnt/rbd-test

# Unmap
sudo rbd unmap /dev/rbd0

# 驗證（應該沒有輸出）
sudo rbd showmapped

# 刪除測試 image（可選）
sudo rbd rm rbdpool/test-image
```

---

## Cluster 健康檢查

### 整體狀態

```bash
# 顯示 cluster 狀態
sudo ceph -s

# 顯示詳細健康資訊
sudo ceph health detail

# 檢查 cluster 版本
sudo ceph versions
```

### MON 檢查

```bash
# MON 統計
sudo ceph mon stat

# MON 詳細資訊
sudo ceph mon dump

# 檢查 MON quorum
sudo ceph quorum_status --format json-pretty
```

### OSD 檢查

```bash
# OSD 統計
sudo ceph osd stat

# OSD tree（顯示 CRUSH hierarchy）
sudo ceph osd tree

# OSD 磁碟使用量
sudo ceph osd df

# OSD 效能統計
sudo ceph osd perf

# 檢查特定 OSD
sudo ceph osd metadata osd.0
```

### Pool 檢查

```bash
# 列出所有 pools
sudo ceph osd pool ls detail

# 檢查 pool 使用量
sudo ceph df

# Pool 統計
sudo ceph osd pool stats

# Pool 特定參數查詢
sudo ceph osd pool get rbdpool all
```

### PG 檢查

```bash
# PG 統計
sudo ceph pg stat

# PG dump（詳細資訊）
sudo ceph pg dump

# 檢查特定 PG
sudo ceph pg <pg_id> query

# 檢查 stuck PGs（如果有）
sudo ceph pg dump_stuck
```

### 容量檢查

```bash
# 整體容量使用
sudo ceph df

# 詳細容量統計
sudo ceph df detail

# 各 OSD 容量使用
sudo ceph osd df tree
```

### 效能檢查

```bash
# 整體效能統計
sudo ceph status

# OSD 效能
sudo ceph osd perf

# Pool IO 統計
sudo ceph osd pool stats
```

### Dashboard 存取

```bash
# 取得 Dashboard URL
sudo ceph mgr services

# 重設 Dashboard password
sudo ceph dashboard ac-user-set-password admin <NEW_PASSWORD>
```

---

## 常用維護指令

### Cluster 管理

```bash
# 顯示所有執行中的 daemon
sudo ceph orch ps

# 顯示所有 services
sudo ceph orch ls

# 重啟特定 service
sudo ceph orch restart <service_name>

# 停止特定 daemon
sudo ceph orch daemon stop <daemon_name>

# 啟動特定 daemon
sudo ceph orch daemon start <daemon_name>
```

### OSD 維護

```bash
# 標記 OSD out（停止服務但不移除）
sudo ceph osd out osd.<id>

# 標記 OSD in
sudo ceph osd in osd.<id>

# 移除 OSD
sudo ceph osd rm osd.<id>

# 移除 OSD from CRUSH map
sudo ceph osd crush rm osd.<id>

# Purge OSD（完全移除）
sudo ceph orch osd rm osd.<id> --replace --zap
```

### Pool 維護

```bash
# 刪除 pool（需先設定 mon_allow_pool_delete=true）
sudo ceph config set mon mon_allow_pool_delete true
sudo ceph osd pool delete <pool_name> <pool_name> --yes-i-really-really-mean-it

# 調整 PG 數量
sudo ceph osd pool set <pool_name> pg_num <value>
sudo ceph osd pool set <pool_name> pgp_num <value>

# Rename pool
sudo ceph osd pool rename <old_name> <new_name>
```

### 監控與日誌

```bash
# 持續監控 cluster 狀態
watch -n 2 sudo ceph -s

# 檢查 ceph 日誌
sudo ceph log last 50

# 檢查特定 daemon 日誌
sudo journalctl -u ceph-<daemon_id>.service

# 檢查 MON 日誌
sudo ceph-mon --debug-ms 1 --log-to-stderr
```

---

## 疑難排解

### Cluster Health Warning

```bash
# 顯示詳細健康警告
sudo ceph health detail

# 強制清除健康警告（不建議）
sudo ceph health mute <warning_code>

# Unmute 健康警告
sudo ceph health unmute <warning_code>
```

### PG 狀態異常

```bash
# 檢查 stuck PGs
sudo ceph pg dump_stuck

# 強制 backfill 特定 PG
sudo ceph pg <pg_id> force-backfill

# 強制 recovery 特定 PG
sudo ceph pg <pg_id> force-recovery

# Deep scrub 特定 PG
sudo ceph pg deep-scrub <pg_id>
```

### OSD 故障處理

```bash
# 檢查 down OSD
sudo ceph osd tree | grep down

# 重啟 OSD daemon
sudo ceph orch daemon restart osd.<id>

# 檢查 OSD 日誌
sudo journalctl -u ceph-osd@<id>.service

# 移除並重新加入 OSD
sudo ceph orch osd rm osd.<id> --replace --zap
sudo ceph orch daemon add osd <host>:/dev/<device>
```

### MON 故障處理

```bash
# 檢查 MON quorum
sudo ceph quorum_status

# 重啟 MON daemon
sudo ceph orch daemon restart mon.<host>

# 移除 MON
sudo ceph orch daemon rm mon.<host> --force

# 重新加入 MON
sudo ceph orch apply mon --placement="<host_list>"
```

---

## 參考資訊

### 版本資訊

- Ceph Version: **19.2.2 (Reef)**
- OS: **Ubuntu 22.04 LTS**
- Azure VM Size: **Standard_D4s_v4 (4C/16G)**

### 網路架構

- **Public Network:** 10.10.10.0/24 (MON, MGR, Client 存取)
- **Cluster Network:** 172.10.10.0/24 (OSD replication)

### 儲存架構

- **Total OSDs:** 6 (每節點 2 顆)
- **Replication Size:** 3
- **Min Size:** 1
- **Pool:** rbdpool (128 PG)

### 相關文件

- [Phase 0 - Azure 資源建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-0/)
- [Phase 1 - OS 準備](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-1/)
- [Phase 2 - Ceph 安裝](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-2/)
- [Phase 3 - Cluster 建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-3/)
- [Phase 4 - RBD Pool 建立](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-4/)
- [Architecture](https://mansionlai.github.io/notebook/storage/3node-ceph/architecture/)
- [Flowchart](https://mansionlai.github.io/notebook/storage/3node-ceph/flowchart/)
