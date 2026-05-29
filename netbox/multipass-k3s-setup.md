---
title: Multipass + K3s 基礎設施搭建
parent: Netbox
nav_order: 2
---

# Multipass + K3s 基礎設施搭建指南

## 概述

本指南帶你在 Mac-mini 上使用 Multipass 創建 3 個 Ubuntu VM，組成 K3s Kubernetes 叢集（1 control plane + 2 worker nodes）。

## 前置要求

- **macOS** (Monterey 或更新版本)
- **Multipass** 已安裝 ([下載](https://multipass.run/))
- **Helm 3** 已安裝在本地 Mac
- **kubectl** 已安裝在本地 Mac
- Mac-mini 至少 16GB RAM (建議 32GB)
- 至少 50GB 可用磁盤空間（對應 3-node 最小化配置：20G + 15G + 15G）

## 第 1 步：創建 3 個 Ubuntu VM

> **注意：** Multipass 既有 VM 的磁碟容量一般無法原地縮小。若要降低 `--disk`，通常需要刪除並用較小的 `--disk` 參數重建 VM。
>
> **相容性警告（最小化規格）：** 本頁的 VM 最小化 sizing 僅適用於同時採用部署文件中的「精簡版 NetBox Helm 資源限制與 PVC 容量設定」。若直接沿用預設（較重）Helm 資源/PVC 參數，可能超出上述 VM 容量並導致部署失敗或節點資源不足。

### 步驟 1.1：創建 Control Plane VM

```bash
multipass launch --name k3s-control --cpus 2 --memory 4G --disk 20G

multipass list
```

### 步驟 1.2：創建 Worker Node 1 和 2

```bash
multipass launch --name k3s-worker-1 --cpus 1 --memory 2G --disk 15G

multipass launch --name k3s-worker-2 --cpus 1 --memory 2G --disk 15G
```

### 步驟 1.3：驗證所有 VM 運行

```bash
multipass list
```

預期輸出：
```
Name              State    IPv4             Image
k3s-control       Running  192.168.64.xxx   Ubuntu 22.04 LTS
k3s-worker-1      Running  192.168.64.yyy   Ubuntu 22.04 LTS
k3s-worker-2      Running  192.168.64.zzz   Ubuntu 22.04 LTS
```

## 第 2 步：在 Control Plane 上安裝 K3s

### 步驟 2.1：登錄 Control Plane VM

```bash
multipass shell k3s-control
```

### 步驟 2.2：安裝 K3s

```bash
# 在 k3s-control VM 內執行
curl -sfL https://get.k3s.io | sh -

# 驗證 K3s 安裝
sudo k3s kubectl get nodes

# 預期輸出：
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-control   Ready    control-plane,master   10s   v1.xx.x
```

### 步驟 2.3：獲取 Token

```bash
# 在 k3s-control VM 內執行
sudo cat /var/lib/rancher/k3s/server/node-token

# 保存輸出，後續步驟會用到
# 例如：K10aaa...bbb...ccc...ddd

exit
```

### 步驟 2.4：在本地 Mac 設置 kubeconfig

```bash
# 在 Mac 本地執行
mkdir -p ~/.kube

multipass copy-files k3s-control:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config.yaml

# 編輯 kubeconfig，將 127.0.0.1 改為實際 IP
nano ~/.kube/k3s-config.yaml

# 找到並修改：
# server: https://127.0.0.1:6443
# 改為：
# server: https://192.168.64.10:6443

# 設置環境變數
export KUBECONFIG=~/.kube/k3s-config.yaml

# 驗證連接
kubectl get nodes
```

## 第 3 步：Worker 節點加入叢集

### 步驟 3.1：在 Worker 1 上安裝 K3s Agent

```bash
multipass shell k3s-worker-1

# 在 worker 1 VM 內執行
# 使用之前保存的 token 和 control plane IP
K3S_TOKEN="K10aaa...bbb...ccc...ddd"
K3S_URL="https://192.168.64.10:6443"

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

exit
```

### 步驟 3.2：在 Worker 2 上安裝 K3s Agent

```bash
multipass shell k3s-worker-2

K3S_TOKEN="K10aaa...bbb...ccc...ddd"
K3S_URL="https://192.168.64.10:6443"

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

exit
```

### 步驟 3.3：驗證叢集完整性

```bash
# 在 Mac 本地執行
kubectl get nodes -o wide

# 預期輸出：
# NAME           STATUS   ROLES                  AGE    VERSION
# k3s-control    Ready    control-plane,master   10m    v1.xx.x
# k3s-worker-1   Ready    <none>                 2m     v1.xx.x
# k3s-worker-2   Ready    <none>                 2m     v1.xx.x
```

## 第 4 步：驗證叢集功能

### 步驟 4.1：檢查系統 Pod

```bash
kubectl get pods -A

# 預期輸出：
# NAMESPACE     NAME                                    READY   STATUS    RESTARTS   AGE
# kube-system   local-path-provisioner-xxx              1/1     Running   0          5m
# kube-system   coredns-xxx                             1/1     Running   0          5m
# kube-system   metrics-server-xxx                      1/1     Running   0          5m
```

### 步驟 4.2：測試簡單 Deployment

```bash
kubectl create deployment test-nginx --image=nginx
kubectl get pods
kubectl delete deployment test-nginx
```

## K3s 叢集拓撲圖

```
┌─────────────────────────────────────────────────────────┐
│                    Mac-mini Network                      │
│                   (Multipass 虛擬網絡)                   │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │              K3s Kubernetes Cluster              │   │
│  │                                                   │   │
│  │  ┌────────────────┐  ┌──────────┐ ┌──────────┐  │   │
│  │  │  Control Plane │  │  Worker1 │ │  Worker2 │  │   │
│  │  │  (Master Node) │  │          │ │          │  │   │
│  │  │                │  │          │ │          │  │   │
│  │  │ • API Server   │  │ • Kubelet│ │ •Kubelet │  │   │
│  │  │ • etcd         │  │ • kube-  │ │ • kube-  │  │   │
│  │  │ • Controller   │  │   proxy  │ │   proxy  │  │   │
│  │  │ • Scheduler    │  │          │ │          │  │   │
│  │  │                │  │          │ │          │  │   │
│  │  └────────────────┘  └──────────┘ └──────────┘  │   │
│  │         │                │              │        │   │
│  │  192.168.64.10    192.168.64.11   192.168.64.12 │   │
│  │                                                   │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │  Container Network (10.42.0.0/16)         │  │   │
│  │  │  • Pod CIDR: 10.42.0.0/16                 │  │   │
│  │  │  • Service CIDR: 10.43.0.0/16             │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## 常用命令參考

```bash
# 查看節點信息
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node <node-name>

# 查看所有 pod
kubectl get pods -A
kubectl get pods -n kube-system

# 查看叢集信息
kubectl cluster-info

# 代理訪問
kubectl port-forward svc/service-name 8080:80 -n namespace
```

## 故障排查

### Worker 節點無法加入

```bash
# 檢查 worker 日誌
multipass shell k3s-worker-1
sudo journalctl -u k3s-agent -f

# 常見原因：
# 1. Token 不正確
# 2. Control plane IP 錯誤
# 3. 網絡不通
```

## 下一步

K3s 叢集搭建完成後，參考 [helm-chart-guide.md](./helm-chart-guide.md) 安裝 Netbox Helm chart。
