---
title: Buildup Guide
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 2
---

# K8s 3-Node Cluster Build-up Log (kubeadm)

> 建立日期：2026-04-11  
> 更新日期：2026-05-17 (修正 CRI-O 路徑、靜態 IP 設定、補足 web-app)  
> 環境：Mac Mini M4 / Multipass / Ubuntu 24.04  
> 方式：kubeadm（官方標準安裝）  
> 網路：Multipass 橋接 **en0**（192.168.50.x/24）  

## 節點資訊 (符合 spec.md)

| Role | Hostname | Bridge IP (Static) | vCPU | RAM | Disk |
|------|----------|-------------------|------|-----|------|
| Control Plane | k8s-master | 192.168.50.201 | 2 | 3GB | 30GB |
| Worker (infra) | k8s-infra | 192.168.50.202 | 2 | 3GB | 30GB |
| Worker | k8s-worker | 192.168.50.203 | 2 | 3GB | 40GB |

Pod CIDR: `172.46.0.0/16`（Cilium 配置）  
Service CIDR: `10.96.0.0/12`（kubeadm 預設）

---

## 安裝架構總覽

```
kubeadm 安裝分為 6 個步驟：

Step.0: VM 建立與網路設定
  ├── Multipass launch (en0 bridge)
  └── 內部 Netplan 設定靜態 IP (ENS4)

Step.1: 所有節點預備（ALL nodes）
  ├── /etc/hosts 設定
  ├── 關閉 swap
  ├── 安裝 conntrack (Ubuntu 24 必備)
  ├── 載入 kernel modules + sysctl
  └── 安裝 CRI-O + kubeadm/kubelet/kubectl

Step.2: 初始化 Master
  ├── kubeadm init (advertise 192.168.50.201)
  ├── 設定 kubectl config
  └── 安裝 CNI (Cilium in Kube-proxy replacement mode)

Step.3: Worker 加入 Cluster
  └── kubeadm join (k8s-infra & k8s-worker)

Step.4: 基礎設施服務部署 (on Infra Node)
  ├── Ingress Controller / Metrics Server
  └── Prometheus / Grafana / Logging

Step.5: 驗證與應用部署 (on Worker Node)
  └── 部署 Simple Web App (Nginx)
```

---

## Step.0 — VM 建立與網路設定

### Step.0.1：啟動 VM
```bash
multipass launch 24.04 --name k8s-master --cpus 2 --memory 3G --disk 30G --network en0
```

### Step.0.2：設定靜態 IP (符合 Spec)
**原因：** Multipass 在 macOS 上無法直接在 launch 時指定橋接網卡的 IP。為了符合 `.201-203` 的規範，需進 VM 使用 Netplan 修改。

```bash
# 以 k8s-master 為例
sudo tee /etc/netplan/60-bridge-static.yaml <<EOF
network:
  version: 2
  ethernets:
    ens4:
      dhcp4: no
      addresses: [192.168.50.201/24]
      routes: [{to: default, via: 192.168.50.1}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
EOF
sudo netplan apply
```

---

## Step.1 — 所有節點預備

> **執行對象：三台 VM**

### Step.1.1：設定 /etc/hosts
```bash
sudo tee -a /etc/hosts << 'EOF'
192.168.50.201 k8s-master
192.168.50.202 k8s-infra
192.168.50.203 k8s-worker
EOF
```

### Step.1.2：安裝依賴與環境設定
```bash
# 關閉 Swap
sudo swapoff -a && sudo sed -i '/\bswap\b/d' /etc/fstab

# 安裝 conntrack (重要：Ubuntu 24.04 預設未安裝，kubeadm 會噴錯)
sudo apt-get update && sudo apt-get install -y conntrack socat ebtables

# 核心模組與 Sysctl
sudo modprobe overlay && sudo modprobe br_netfilter
sudo sysctl --system
```

### Step.1.3：安裝 CRI-O
**⚠️ 注意：** 官方 repository 路徑已更新。
```bash
VERSION="v1.31"
# ... (安裝步驟見 commands.md)
```

---

## Step.2 — 初始化 Master (Cilium)

### Step.2.1：kubeadm init
```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.50.201 \
  --pod-network-cidr=172.46.0.0/16 \
  --node-name=k8s-master \
  --cri-socket=unix:///run/crio/crio.sock \
  --skip-phases=addon/kube-proxy
```

### Step.2.2：安裝 Cilium
**重點：** 因為跳過了 kube-proxy，Cilium 安裝時必須指定 `k8sServiceHost=192.168.50.201`。

---

## Step.4 — 基礎設施部署

### Step.4.1：安裝 Prometheus/Grafana (on Infra node)
透過 `nodeSelector` 確保相關 Pod 運行在 `k8s-infra`。

### Step.4.2：安裝 Logging (OpenSearch + Fluent-bit)
OpenSearch 運行於 `k8s-infra`，Fluent-bit 運行於所有節點。

---

## Step.5 — 驗證與應用部署

### Step.5.1：部署 Web App (on Worker node)
部署一個具備 NodePort Service 的 Nginx App，驗證其排程至 `k8s-worker`。

---

## 修正記錄 (2026-05-17)
- **修正 CRI-O URL**: 原路徑 403 錯誤，更新為 `pkgs.k8s.io` 正確 v1.31 路徑。
- **補上 conntrack**: Ubuntu 24.04 必裝依賴。
- **實作靜態 IP**: 透過 Netplan 強制將橋接網卡改為 .201/.202/.203。
- **Cilium 連線修正**: 補上 `k8sServiceHost` 參數。
- **完整化範疇**: 補上 Prometheus/Grafana/Logging 與 Web App 測試，符合 spec.md。
- **說辭對齊**: 統一使用 `Step.xxx` 命名規範。
