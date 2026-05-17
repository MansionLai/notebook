---
title: Commands
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 3
---

# Mac Mini K8s 三節點建置指令手冊

> 建立日期：2026-04-11  
> 更新日期：2026-05-17 (修正 CRI-O 路徑、靜態 IP 設定、全文件步驟對齊)  
> 環境：macOS 15 · Multipass 1.15+ · Ubuntu 24.04 ARM64 · Kubernetes 1.31

---

## Step.0：VM 建立與網路設定

### Step.0.1：Mac 環境前置
```bash
# 確認 Multipass bridge 網卡設定（橋接 en0）
multipass set local.bridged-network=en0
ifconfig en0 | grep "inet "
```

### Step.0.2：啟動 VM
```bash
multipass launch 24.04 --name k8s-master --cpus 2 --memory 3G --disk 30G --network en0
multipass launch 24.04 --name k8s-infra --cpus 2 --memory 3G --disk 30G --network en0
multipass launch 24.04 --name k8s-worker --cpus 2 --memory 3G --disk 40G --network en0
```

### Step.0.3：設定靜態 IP (Netplan)
針對三台分別執行，修改 IP 為 `.201`, `.202`, `.203`。
```bash
multipass shell k8s-master
# --- 在 VM 內執行 ---
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
exit
```

---

## Step.1：所有節點環境預備 (三台都做)

### Step.1.1：系統基礎設定
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

# 3. 安裝依賴 (conntrack 是 kubeadm 必備)
sudo apt-get update
sudo apt-get install -y conntrack socat ebtables
```

### Step.1.2：核心模組與 Sysctl
```bash
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
```

### Step.1.3：安裝 CRI-O 與 K8s 工具
```bash
# CRI-O (v1.31)
VERSION="v1.31"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$VERSION/deb/Release.key | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$VERSION/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

# K8s (v1.31)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y cri-o kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl enable --now crio kubelet
```

---

## Step.2：Master 初始化與 CNI 安裝

### Step.2.1：kubeadm init
```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.50.201 \
  --pod-network-cidr=172.46.0.0/16 \
  --node-name=k8s-master \
  --cri-socket=unix:///run/crio/crio.sock \
  --skip-phases=addon/kube-proxy

# 設定 kubectl config
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step.2.2：安裝 Cilium
```bash
# 安裝 Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-arm64.tar.gz
sudo tar xzvfC cilium-linux-arm64.tar.gz /usr/local/bin

# Helm 安裝 (關鍵：指定 k8sServiceHost)
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.50.201 \
  --set k8sServicePort=6443 \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=172.46.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24
```

---

## Step.3：Worker 節點加入叢集
在 `k8s-infra` 與 `k8s-worker` 執行：
```bash
sudo kubeadm join 192.168.50.201:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --node-name=<HOSTNAME> \
  --cri-socket=unix:///run/crio/crio.sock
```

---

## Step.4：節點標記與 Taint (Master 執行)
```bash
kubectl label node k8s-infra node-role.kubernetes.io/infra="" node-type=infra
kubectl label node k8s-worker node-role.kubernetes.io/worker="" node-type=worker
kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule --overwrite
```

---

## Step.5：基礎設施服務部署

### Step.5.1：Ingress & Metrics Server
```bash
# Ingress-Nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace \
  --set controller.nodeSelector."node-role\.kubernetes\.io/infra"="" --set controller.service.type=NodePort

# Metrics Server (ARM64 需 insecure-tls)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

### Step.5.2：Monitoring & Logging
```bash
# Prometheus + Grafana
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.nodeSelector."node-role\.kubernetes\.io/infra"="" \
  --set grafana.nodeSelector."node-role\.kubernetes\.io/infra"=""

# OpenSearch + Fluent-bit
# (安裝步驟見 buildup.md，需確保 nodeSelector 到 infra)
```

---

## Step.6：應用測試與最終驗證
```bash
# 部署 Nginx 於 Worker 節點
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      nodeSelector:
        node-type: worker
      containers:
      - name: nginx
        image: nginx:alpine
EOF
```
