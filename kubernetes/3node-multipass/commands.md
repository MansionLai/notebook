---
title: Commands
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 3
---

# Mac Mini K8s 三節點建置指令手冊

> 建立日期：2026-04-11  
> 更新日期：2026-05-17 (修正 CRI-O 路徑與靜態 IP 設定)  
> 環境：macOS 15 · Multipass 1.15+ · Ubuntu 24.04 ARM64 · Kubernetes 1.31

---

## Step 0：Mac 前置（只做一次）

```bash
# 確認 Multipass bridge 網卡設定（橋接 en0）
multipass set local.bridged-network=en0

# 確認 en0 目前 IP（應在 192.168.50.x/24）
ifconfig en0 | grep "inet "
```

---

## Step 1：建立三台 VM 並設定靜態 IP

```bash
# 1. 啟動 VM
multipass launch 24.04 --name k8s-master --cpus 2 --memory 3G --disk 30G --network en0
multipass launch 24.04 --name k8s-infra --cpus 2 --memory 3G --disk 30G --network en0
multipass launch 24.04 --name k8s-worker --cpus 2 --memory 3G --disk 40G --network en0

# 2. 設定靜態 IP (Netplan)
# ⚠️ Multipass 在 macOS 橋接時預設使用 DHCP，需手動改為靜態以符合 spec 要求。
# 請針對三台分別執行 (以下以 k8s-master 192.168.50.201 為例)
multipass shell k8s-master

# --- 在 VM 內執行 ---
sudo tee /etc/netplan/60-bridge-static.yaml <<EOF
network:
  version: 2
  ethernets:
    ens4:
      dhcp4: no
      addresses: [192.168.50.201/24]
      routes:
        - to: default
          via: 192.168.50.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF
sudo netplan apply
exit
# ------------------

# 其他節點 IP 分別為 .202 (infra) 和 .203 (worker)
```

---

## Step 2：所有節點前置設定（三台都執行）

```bash
# 1. 設定 /etc/hosts
sudo tee -a /etc/hosts <<EOF
192.168.50.201 k8s-master
192.168.50.202 k8s-infra
192.168.50.203 k8s-worker
EOF

# 2. 關閉 swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. 安裝必要依賴 (conntrack 是 kubeadm 必備，Ubuntu 24.04 預設未裝)
sudo apt-get update
sudo apt-get install -y conntrack socat ebtables

# 4. 載入必要核心模組
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 5. 設定網路 sysctl
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 6. 安裝 cri-o (修正 v1.31 ARM64 正確路徑)
VERSION="v1.31"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$VERSION/deb/Release.key | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o
sudo systemctl daemon-reload
sudo systemctl enable --now crio

# 7. 安裝 kubeadm / kubelet / kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now kubelet
```

---

## Step 3：Master 初始化（只在 k8s-master 執行）

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.50.201 \
  --pod-network-cidr=172.46.0.0/16 \
  --node-name=k8s-master \
  --cri-socket=unix:///run/crio/crio.sock \
  --skip-phases=addon/kube-proxy

# 設定 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## Step 4：Infra + Worker 加入 Cluster

```bash
# 使用 Step 3 產生的 token
sudo kubeadm join 192.168.50.201:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --node-name=k8s-infra \
  --cri-socket=unix:///run/crio/crio.sock
```

---

## Step 5：安裝 CNI（Cilium）

```bash
# 安裝 Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-arm64.tar.gz
sudo tar xzvfC cilium-linux-arm64.tar.gz /usr/local/bin
rm cilium-linux-arm64.tar.gz

# 安裝 Cilium (需指定 k8sServiceHost，否則在無 kube-proxy 模式下會連不到 API Server)
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=172.46.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.50.201 \
  --set k8sServicePort=6443

cilium status --wait
```

---
(其餘 Label 與 Infra 服務安裝部分保持不變...)
