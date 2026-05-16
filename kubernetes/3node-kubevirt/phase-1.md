---
title: Phase 1 - OS 基礎 + kubeadm + Cilium
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 11
permalink: /kubernetes/3node-kubevirt/phase-1/
---

# Phase 1 — OS 基礎 + kubeadm + Cilium

> **以下 Step 1-1 ~ 1-7 在三台 VM 各執行一遍**（可開三個 Terminal）

### Step 1-1：/etc/hosts 設定

> **目的：** 讓三台 VM 可以用 hostname 互相溝通，kubeadm init/join 時會用到這些名稱。

```bash
sudo tee -a /etc/hosts <<EOF
10.10.10.11 mansion-kubevirt-master
10.10.10.12 mansion-kubevirt-infra
10.10.10.13 mansion-kubevirt-worker
EOF
```

驗證：
```bash
ping -c 1 mansion-kubevirt-master
```

---

### Step 1-2：關閉 Swap

> **目的：** K8s 要求關閉 swap。原因是 kubelet 依賴 Linux cgroup 來精確控制 Pod 的記憶體使用量，swap 的存在會讓記憶體限制失效，導致 Pod 的 OOM 行為難以預測。
> Azure Ubuntu 24.04 預設沒有 swap，執行後應無任何輸出。

```bash
sudo swapoff -a
sudo sed -i '/\sswap\s/d' /etc/fstab
```

驗證（應無輸出）：
```bash
swapon --show
```

---

### Step 1-3：載入 Kernel Module

> **目的：** K8s 的網路功能依賴兩個 kernel module：
> - `overlay`：容器 filesystem 所使用的 OverlayFS（CRI-O 用來疊加容器 layer）
> - `br_netfilter`：讓 bridge 網路封包也經過 iptables/netfilter，Cilium/kube-proxy 的 Service routing 需要此功能
>
> 寫入 `/etc/modules-load.d/k8s.conf` 確保重開機後自動載入。

```bash
sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

驗證：
```bash
lsmod | grep -E 'overlay|br_netfilter'
```

---

### Step 1-4：設定 sysctl

> **目的：** 開啟三個 kernel 網路參數：
> - `bridge-nf-call-iptables/ip6tables`：確保 bridge 上的封包也過 iptables，讓 K8s Service ClusterIP routing 正常運作
> - `ip_forward`：開啟 IP forwarding，讓 VM 可以轉發 Pod 之間的封包（CNI 必需）
>
> 寫入 `/etc/sysctl.d/k8s.conf` 確保重開機後持久化。

```bash
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

驗證：
```bash
sysctl net.ipv4.ip_forward
# 預期：net.ipv4.ip_forward = 1
```

---

### Step 1-5：安裝 CRI-O

> **目的：** 安裝容器執行環境（Container Runtime）。K8s 不直接管理容器，而是透過 CRI（Container Runtime Interface）標準介面與 runtime 溝通。
> - CRI-O 是專為 K8s 設計的輕量級 CRI，只實作 K8s 需要的功能，比 containerd 更精簡
> - 預設使用 **systemd cgroup**，與 K8s 推薦設定一致，不需額外修改設定檔
> - 版本需與 K8s 版本一致（此處均為 v1.31）

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings

# 加入 CRI-O 官方 repo（版本對應 K8s 1.31）
KUBERNETES_VERSION=v1.31

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/${KUBERNETES_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] \
  https://pkgs.k8s.io/addons:/cri-o:/stable:/${KUBERNETES_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o

sudo systemctl start crio
sudo systemctl enable crio
```

---

### Step 1-6：驗證 CRI-O

> **目的：** 確認 CRI-O 正常運行，且 cgroup driver 為 systemd（與 kubelet 預設一致，不匹配會導致 kubelet 無法啟動）。

```bash
sudo systemctl is-active crio
# 預期：active

sudo crictl info | grep -E 'cgroup|sandbox'
# 預期：看到 cgroupDriver: systemd
```

---

### Step 1-7：安裝 kubeadm / kubelet / kubectl

> **目的：** 安裝 K8s 核心三件套，**三台都需要安裝**：
> - `kubelet`：每台 node 必備的核心 agent，負責接收 API Server 指令、啟動/停止 Pod、監控健康狀態並回報
> - `kubeadm`：叢集初始化工具，master 用 `kubeadm init` 建立叢集，infra/worker 用 `kubeadm join` 加入
> - `kubectl`：與 K8s API Server 溝通的 CLI，master 必須，infra/worker 可選（裝了方便 debug）
>
> `apt-mark hold` 鎖定版本，防止 `apt upgrade` 自動升級破壞叢集相容性。

```bash
sudo apt-get install -y apt-transport-https

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

驗證：
```bash
kubeadm version --output short
kubectl version --client --short 2>/dev/null
# 預期：v1.31.x
```

---

### Step 1-8：初始化 Master（僅 mansion-kubevirt-master）

> **目的：** 建立 K8s control plane。`kubeadm init` 會：
> 1. 產生 TLS 憑證（CA、API Server、etcd 等）
> 2. 啟動 etcd、kube-apiserver、kube-controller-manager、kube-scheduler（以 static pod 方式跑在 `/etc/kubernetes/manifests/`）
> 3. 產生 `admin.conf`（kubectl 的認證設定）
> 4. 輸出 `kubeadm join` 指令（含 token 和 CA hash，供 worker/infra 使用）
>
> `--pod-network-cidr=10.244.0.0/16` 是給 Cilium 使用的 Pod IP 段（不與 VM subnet 衝突）。

```bash
sudo kubeadm init \
  --apiserver-advertise-address=10.10.10.11 \
  --pod-network-cidr=10.244.0.0/16
```

> ⏱ 需約 3-5 分鐘，等待完成

成功後設定 kubectl：

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**⚠️ 記錄 join 指令**（輸出最後的 `kubeadm join ...`，之後用）

---

### Step 1-9：安裝 Cilium（在 mansion-kubevirt-master）

> **目的：** 安裝 CNI（Container Network Interface）網路插件。Cilium 基於 eBPF 技術，提供高效能 Pod 網路、NetworkPolicy、以及可選的 kube-proxy 替代模式。
> 在安裝 CNI 之前，所有 Node 會維持 `NotReady` 狀態，因為 kubelet 無法設定 Pod 網路。
> `--set kubeProxyReplacement=false` 保留傳統 kube-proxy，待叢集穩定後再考慮啟用 eBPF 替代模式。

```bash
# 安裝 Cilium CLI
CILIUM_VER=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --remote-name \
  https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VER}/cilium-linux-amd64.tar.gz
sudo tar xzf cilium-linux-amd64.tar.gz -C /usr/local/bin
rm cilium-linux-amd64.tar.gz

# 安裝 Cilium
cilium install \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=false

cilium status --wait
```

> ⏱ 需約 2-3 分鐘

驗證：
```bash
kubectl get nodes
# 預期：mansion-kubevirt-master  Ready  control-plane
```

---

### Step 1-10：Worker / Infra 加入叢集

> **目的：** 讓 infra 和 worker node 加入叢集。`kubeadm join` 會：
> 1. 用 token 向 master API Server 認證
> 2. 用 CA hash 驗證 master 憑證（防止中間人攻擊）
> 3. 下載叢集設定、取得 Node 憑證
> 4. 啟動 kubelet，開始接受 Pod 排程

在 **mansion-kubevirt-infra** 和 **mansion-kubevirt-worker** 各執行 Step 1-8 記錄的 join 指令：

```bash
sudo kubeadm join 10.10.10.11:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

### Step 1-11：設定 Node Roles（在 mansion-kubevirt-master）

> **目的：** 為 node 加上 label，讓之後部署的工作負載可以用 `nodeSelector` 或 `affinity` 指定跑在哪台 node。
> K8s 預設只有 `control-plane` label，其他角色需手動設定。

```bash
kubectl label node mansion-kubevirt-infra  node-role.kubernetes.io/infra=
kubectl label node mansion-kubevirt-worker node-role.kubernetes.io/worker=
kubectl label node mansion-kubevirt-infra  role=infra
kubectl label node mansion-kubevirt-worker role=worker
kubectl label node mansion-kubevirt-master role=master

# KubeVirt placement labels
kubectl label node mansion-kubevirt-infra  kubevirt-management=true
kubectl label node mansion-kubevirt-worker kubevirt-workload=true

# Taint infra node to prevent general workload
kubectl taint node mansion-kubevirt-infra node-role.kubernetes.io/infra=:NoSchedule
```

驗證：
```bash
kubectl get nodes
# 預期：
# mansion-kubevirt-infra    Ready  infra
# mansion-kubevirt-master   Ready  control-plane
# mansion-kubevirt-worker   Ready  worker
```

---

### Step 1-12：設定 Mac 本機 kubectl

> **目的：** 讓 Mac 本機的 `kubectl` 可以直接管理 Azure 上的叢集，不用每次都 SSH 進去。
> 將 master 的 `admin.conf` 複製到本機，並把 server address 改為 Public IP（因為本機無法直接連 10.10.10.11）。

```bash
# 在 mansion-kubevirt-master 查看 admin.conf
cat ~/.kube/config
```

在 Mac 本機：
```bash
# 複製 config（替換 server IP 為 master 的 Public IP）
scp ubuntu@<MASTER_PUBLIC_IP>:~/.kube/config ~/.kube/config-kubevirt

# 修改 server 為 Public IP
sed -i '' 's|10.10.10.11|<MASTER_PUBLIC_IP>|g' ~/.kube/config-kubevirt

# 合併到 kubeconfig 或直接使用
export KUBECONFIG=~/.kube/config:~/.kube/config-kubevirt
kubectl config rename-context kubernetes-admin@kubernetes k8s-kubevirt
kubectl config use-context k8s-kubevirt
kubectl get nodes
```

---
