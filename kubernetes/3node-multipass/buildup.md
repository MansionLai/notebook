---
title: Buildup Guide
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 2
---

# K8s 3-Node Cluster Build-up Log (kubeadm)

> 建立日期：2026-04-11  
> 更新日期：2026-05-17 (修正 CRI-O 路徑、靜態 IP 設定、全文件步驟對齊)  
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
kubeadm 安裝分為 7 個步驟：

Step.0: VM 建立與網路設定
  ├── Multipass launch (en0 bridge)
  └── 內部 Netplan 設定靜態 IP (ENS4)

Step.1: 所有節點環境預備（ALL nodes）
  ├── /etc/hosts 設定
  ├── 關閉 swap
  ├── 安裝 conntrack (Ubuntu 24 必備)
  ├── 載入 kernel modules + sysctl
  └── 安裝 CRI-O + kubeadm/kubelet/kubectl

Step.2: Master 初始化與 CNI 安裝
  ├── kubeadm init (advertise 192.168.50.201)
  ├── 設定 kubectl config
  └── 安裝 Cilium (in Kube-proxy replacement mode)

Step.3: Worker 加入叢集
  └── kubeadm join (k8s-infra & k8s-worker)

Step.4: 節點標記與 Taint
  └── Labeling infra/worker & Taint master

Step.5: 基礎設施服務部署 (on Infra Node)
  ├── Ingress Controller / Metrics Server
  └── Prometheus / Grafana / Logging

Step.6: 應用部署與最終驗證 (on Worker Node)
  └── 部署 Simple Web App (Nginx)
```

---

## Step.0 — VM 建立與網路設定

### Step.0.1：啟動 VM
使用 Multipass launch 三台 Ubuntu 24.04，並掛載 `en0` 橋接網卡。

### Step.0.2：設定靜態 IP (符合 Spec)
**原因：** Multipass 在 macOS 上無法直接在 launch 時指定橋接網卡的 IP。為了符合 `.201-203` 的規範，需進 VM 使用 Netplan 修改 `ens4` 網卡。

---

## Step.1 — 所有節點環境預備

> **執行對象：三台 VM**

### Step.1.1：系統基礎設定
確保三台節點能透過 Hostname 互通，並關閉 Swap 以符合 `kubelet` 要求。安裝 `conntrack` 等必要依賴。

### Step.1.2：核心模組與 Sysctl
載入 `overlay` 與 `br_netfilter`，並啟用 `ip_forward` 與橋接流量過濾。

### Step.1.3：安裝 CRI-O 與 K8s 工具
**⚠️ 注意：** 官方 repository 路徑已更新為 `pkgs.k8s.io`。安裝後需啟動並設定開機自啟。

---

## Step.2 — Master 初始化與 CNI 安裝

### Step.2.1：kubeadm init
使用 `--apiserver-advertise-address=192.168.50.201`。
**特別注意：** 初始化時加入了 `--skip-phases=addon/kube-proxy`。

### Step.2.2：安裝 Cilium
**關鍵修正：** 安裝時必須指定 `k8sServiceHost=192.168.50.201`，解決無 kube-proxy 模式下的連線問題。

---

## Step.3 — Worker 加入叢集

### Step.3.1：執行 kubeadm join
使用 Master 產生的 Token 將 `k8s-infra` 與 `k8s-worker` 加入。需確保加上 `--cri-socket` 參數指向 CRI-O。

---

## Step.4 — 節點標記與 Taint

### Step.4.1：Label 與 Taint 設定
標記 `infra` 與 `worker` 角色，並在 Master 加上 `NoSchedule` 污點，確保一般應用不會排程到 Master。

---

## Step.5 — 基礎設施部署

### Step.5.1：安裝 Ingress 與 Metrics Server
安裝 Nginx Ingress Controller 並設定 `nodeSelector` 到 `infra` 節點。

### Step.5.2：安裝 Monitoring & Logging
安裝 Prometheus, Grafana 至 `k8s-infra`。Logging 系統使用 OpenSearch 與 Fluent-bit。

---

## Step.6 — 應用部署與最終驗證

### Step.6.1：部署 Web App (on Worker node)
部署一個具備 NodePort Service 的 Nginx App，驗證其排程至 `k8s-worker`。

---

## 修正記錄 (2026-05-17)
- **步驟對齊**: 統一 `commands.md` 與 `buildup.md` 為 Step.0 至 Step.6。
- **修正 CRI-O URL**: 更新為官方正確 v1.31 路徑。
- **補上 conntrack**: 確保 `kubeadm` 初始化環境完整。
- **實作靜態 IP**: 透過 Netplan 強制符合 Spec IP 要求。
- **Cilium 連線修正**: 補上 `k8sServiceHost` 參數。
- **完整化範疇**: 包含基礎設施服務與 Web App 測試。
