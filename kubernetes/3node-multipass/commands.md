# Mac Mini K8s 三節點建置指令手冊

> 建立日期：2026-04-11  
> 分類：commands  
> 環境：macOS 15 · Multipass 1.15 · Ubuntu 24.04 ARM64 · Kubernetes 1.32

---

## Step 0：Mac 前置（只做一次）

```bash
# 確認 Multipass bridge 網卡設定（橋接 en0）
multipass set local.bridged-network=en0

# 確認 en0 目前 IP（應在 192.168.50.x/24）
ifconfig en0 | grep "inet "
```

---

## Step 1：建立三台 VM

```bash
# Master Node（K8s Control Plane）
# ⚠️ kubeadm 強制要求 ≥ 2 CPU，不可再減
multipass launch ubuntu:24.04 \
  --name k8s-master \
  --cpus 2 \
  --memory 2.5G \
  --disk 30G \
  --network en0

# Infra Node（基礎設施服務）
multipass launch ubuntu:24.04 \
  --name k8s-infra \
  --cpus 2 \
  --memory 2.5G \
  --disk 30G \
  --network en0

# Worker Node（App Workload）
multipass launch ubuntu:24.04 \
  --name k8s-worker \
  --cpus 2 \
  --memory 2G \
  --disk 40G \
  --network en0

# 確認 VM 狀態與 IP
multipass list
```

> ⚠️ 每台 VM 會有兩個網卡：`ens3`（Multipass NAT）和 `ens4`（bridge en0）。  
> K8s 廣播 IP 要指定 `ens4` 的 192.168.50.x 地址。

---

## Step 2：所有節點前置設定（三台都執行）

```bash
# 進入 VM（以 k8s-master 為例，其他兩台同樣操作）
multipass shell k8s-master
```

```bash
# ── 在 VM 內部執行 ──────────────────────────────────────

# 關閉 swap（K8s 要求）
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 載入必要核心模組
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 設定網路 sysctl
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# 安裝 containerd
sudo apt-get update && sudo apt-get install -y containerd

# 設定 containerd（啟用 SystemdCgroup）
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# 安裝 kubeadm / kubelet / kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl

# 鎖定版本，防止自動升級
sudo apt-mark hold kubeadm kubelet kubectl

# 啟動 kubelet
sudo systemctl enable --now kubelet
```

---

## Step 3：Master 初始化（只在 k8s-master 執行）

```bash
# 進入 master
multipass shell k8s-master
```

```bash
# ── 在 k8s-master 內部 ────────────────────────────────

# 確認 bridge 網卡 IP（記下此 IP，後續 join command 會用到）
ip addr show ens4 | grep "inet "

# 初始化 Cluster（替換 <MASTER_IP> 為上面取得的 192.168.50.x）
sudo kubeadm init \
  --apiserver-advertise-address=<MASTER_IP> \
  --pod-network-cidr=172.46.0.0/16 \
  --node-name=k8s-master \
  --skip-phases=addon/kube-proxy

# 設定 kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 取得 join command（儲存起來，Step 4 用）
kubeadm token create --print-join-command
```

---

## Step 4：Infra + Worker 加入 Cluster

```bash
# 進入 k8s-infra 執行 join（使用 Step 3 取得的 join command）
multipass shell k8s-infra
```

```bash
# ── 在 k8s-infra / k8s-worker 內部 ───────────────────
# 貼上 Step 3 的 join command，加上 --node-name 參數
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --node-name=k8s-infra   # k8s-worker 改成 k8s-worker
```

```bash
# 回到 Mac，確認三台節點都出現（狀態 NotReady 是正常的，等 CNI）
multipass shell k8s-master
kubectl get nodes
```

---

## Step 5：安裝 CNI（Cilium）

```bash
# ── 在 k8s-master 執行 ────────────────────────────────

# 安裝 Cilium CLI（ARM64）
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-arm64.tar.gz
sudo tar xzvfC cilium-linux-arm64.tar.gz /usr/local/bin
rm cilium-linux-arm64.tar.gz

# 透過 Helm 安裝 Cilium（使用自訂 Pod CIDR）
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=172.46.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24

# 等待 Cilium Pod 全部 Running
cilium status --wait

# 確認所有節點 Ready
kubectl get nodes
```

---

## Step 6：節點 Label 與 Taint

```bash
# ── 在 k8s-master 執行 ────────────────────────────────

# 標記 Infra 節點
kubectl label node k8s-infra node-role.kubernetes.io/infra=""
kubectl label node k8s-infra node-type=infra

# 標記 Worker 節點
kubectl label node k8s-worker node-role.kubernetes.io/worker=""
kubectl label node k8s-worker node-type=worker

# Master 加 Taint（防止一般 workload 排到 Master）
kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane:NoSchedule

# 確認 Label
kubectl get nodes --show-labels
```

---

## Step 7：安裝 Helm 與基礎設施服務

```bash
# 安裝 Helm（在 Mac 執行）
brew install helm

# 複製 kubeconfig 到 Mac（在 Mac 執行）
multipass transfer k8s-master:/home/ubuntu/.kube/config ~/.kube/config-macmini
export KUBECONFIG=~/.kube/config-macmini
```

```bash
# ── Ingress Controller（nginx）────────────────────────
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.nodeSelector."node-type"=infra \
  --set controller.service.type=NodePort

# ── Metrics Server ────────────────────────────────────
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# ARM64 需加啟動參數
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# ── kube-prometheus-stack（Prometheus + Grafana）──────
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.nodeSelector."node-type"=infra \
  --set grafana.nodeSelector."node-type"=infra
```

---

## 常用管理指令

```bash
# ── Multipass VM 管理（在 Mac 執行）──────────────────
multipass list                        # 查看所有 VM 狀態
multipass shell k8s-master            # 進入 Master
multipass stop k8s-master             # 停止 VM（省資源）
multipass start k8s-master k8s-infra k8s-worker  # 啟動全部
multipass suspend k8s-master          # 休眠 VM（保留狀態）
multipass delete k8s-master && multipass purge  # 刪除 VM

# ── kubectl 常用 ──────────────────────────────────────
kubectl get nodes -o wide             # 查看節點 + IP
kubectl get pods -A                   # 查看所有 namespace 的 Pod
kubectl get pods -n monitoring        # 查看監控 Pod
kubectl top nodes                     # 資源使用（需 metrics-server）
kubectl top pods -A                   # 所有 Pod 資源使用

# ── Grafana 存取（Port Forward）──────────────────────
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# 瀏覽器開 http://localhost:3000（預設帳密 admin / prom-operator）

# ── Token 過期後重新 Join ──────────────────────────────
kubeadm token create --print-join-command  # 在 Master 執行
```

---

## 疑難排解

```bash
# 節點 NotReady
kubectl describe node k8s-worker      # 查看 Condition 和 Events

# Pod Pending
kubectl describe pod <pod-name> -n <ns>  # 查看排程失敗原因

# containerd 問題
sudo systemctl status containerd
sudo journalctl -u containerd -n 50

# kubeadm 重置（重來）
sudo kubeadm reset
sudo rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
sudo iptables -F && sudo iptables -t nat -F
```

---

## 參考資料

- [Multipass CLI Reference](https://multipass.run/docs/multipass-cli-client)
- [kubeadm init 參數](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/)
- [Cilium 安裝指南](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
- [Cilium Helm Reference](https://docs.cilium.io/en/stable/helm-reference/)
- [kube-prometheus-stack Helm Values](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
