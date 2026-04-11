# K8s 3-Node Cluster Build-up Log (kubeadm)

> 建立日期：2026-04-11  
> 環境：Mac Mini M4 / Multipass / Ubuntu 24.04  
> 方式：kubeadm（官方標準安裝）

## 節點資訊

| Role | Hostname | Bridge IP | vCPU | RAM |
|------|----------|-----------|------|-----|
| Control Plane | k8s-master | 192.168.50.200 | 2 | 4GB |
| Worker (infra) | k8s-infra | 192.168.50.201 | 2 | 4GB |
| Worker | k8s-worker | 192.168.50.202 | 2 | 4GB |

Pod CIDR: `10.244.0.0/16`（Flannel 預設）  
Service CIDR: `10.96.0.0/12`（kubeadm 預設）

---

## 安裝架構總覽

```
kubeadm 安裝分為 3 個 Phase：

Phase 0: 所有節點預備（ALL nodes）
  ├── /etc/hosts 設定
  ├── 關閉 swap
  ├── 載入 kernel modules
  ├── 設定 sysctl
  └── 安裝 containerd + kubeadm/kubelet/kubectl

Phase 1: 初始化 Master
  ├── kubeadm init
  ├── 設定 kubectl config
  └── 安裝 CNI (Flannel)

Phase 2: Worker 加入 Cluster
  ├── kubeadm join (k8s-infra)
  └── kubeadm join (k8s-worker)

Phase 3: 驗證
  └── kubectl get nodes / pods
```

---

## Phase 0 — 所有節點預備

> **執行對象：k8s-master、k8s-infra、k8s-worker（三台都要）**

### Step 0-1：設定 /etc/hosts

**原理：** K8s 節點間通訊使用 hostname，需要能解析彼此的名稱。

```bash
# 在三台 VM 各執行
sudo tee -a /etc/hosts << 'EOF'
192.168.50.200 k8s-master
192.168.50.201 k8s-infra
192.168.50.202 k8s-worker
EOF
```

**驗證：**
```bash
ping -c 1 k8s-master
ping -c 1 k8s-infra
ping -c 1 k8s-worker
```

---

### Step 0-2：關閉 Swap

**原理：** kubelet 預設不允許 swap，因為 swap 會讓記憶體管理不可預期，影響 Pod 的資源保證（QoS）。

```bash
# 關閉當前 swap
sudo swapoff -a

# 永久關閉（移除 /etc/fstab 中的 swap 項目）
sudo sed -i '/\bswap\b/d' /etc/fstab

# 驗證（輸出應為空）
swapon --show
```

---

### Step 0-3：載入 Kernel Modules

**原理：**
- `overlay`：containerd 使用 OverlayFS 作為容器的分層檔案系統
- `br_netfilter`：讓 iptables 可以看到 bridge 流量，K8s 網路規則依賴此模組

```bash
# 設定開機自動載入
sudo tee /etc/modules-load.d/k8s.conf << 'EOF'
overlay
br_netfilter
EOF

# 立即載入
sudo modprobe overlay
sudo modprobe br_netfilter

# 驗證
lsmod | grep -E "overlay|br_netfilter"
```

---

### Step 0-4：設定 sysctl（網路轉發）

**原理：**
- `net.bridge.bridge-nf-call-iptables=1`：bridge 流量走 iptables，CNI 才能設定 Pod 網路規則
- `net.ipv4.ip_forward=1`：允許 IP forwarding，Pod 間跨節點通訊需要

```bash
sudo tee /etc/sysctl.d/k8s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 驗證
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
```

---

### Step 0-5：安裝 containerd

**原理：** containerd 是 K8s 使用的 Container Runtime Interface (CRI)。kubeadm 不包含 runtime，需自行安裝。

```bash
# 安裝 containerd
sudo apt-get update
sudo apt-get install -y containerd

# 產生預設設定
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# 啟用 SystemdCgroup（必須！kubelet 和 containerd 要用同一個 cgroup driver）
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 啟動
sudo systemctl restart containerd
sudo systemctl enable containerd

# 驗證
sudo systemctl status containerd | grep Active
```

---

### Step 0-6：安裝 kubeadm / kubelet / kubectl

**原理：**
- `kubelet`：每個節點上的 agent，負責管理 Pod 生命週期
- `kubeadm`：初始化/加入 cluster 的工具（安裝後不再常用）
- `kubectl`：CLI 控制 cluster（通常只裝在 master）

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# 驗證
kubeadm version
kubelet --version
kubectl version --client
```

---

## Phase 1 — 初始化 Master

> **執行對象：k8s-master 只**

### Step 1-1：kubeadm init

**原理：** kubeadm init 會：
1. 產生 CA 憑證（/etc/kubernetes/pki/）
2. 建立 etcd（儲存 cluster 所有狀態）
3. 啟動 kube-apiserver / kube-controller-manager / kube-scheduler（Static Pod）
4. 產生 admin.conf（kubectl 的 kubeconfig）

```bash
sudo kubeadm init \
  --apiserver-advertise-address=192.168.50.200 \
  --pod-network-cidr=10.244.0.0/16 \
  --node-ip=192.168.50.200

# ⚠️ 執行完後複製最後出現的 kubeadm join ... 指令備用
```

### Step 1-2：設定 kubectl

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 驗證（節點會是 NotReady，等裝 CNI 才會 Ready）
kubectl get nodes
```

### Step 1-3：安裝 CNI（Flannel）

**原理：** CNI (Container Network Interface) 負責 Pod 間的網路通訊。Flannel 使用 VXLAN 建立 overlay 網路，讓不同節點的 Pod 可以互相通訊。

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 等待 flannel pods 啟動（約 30 秒）
kubectl get pods -n kube-flannel -w
```

---

## Phase 2 — Worker 加入

> **執行對象：k8s-infra 和 k8s-worker**

### Step 2-1：kubeadm join

**原理：** worker 節點透過 token 驗證身份，向 master 的 kube-apiserver 提交 CSR，取得憑證後加入 cluster。

```bash
# 在 k8s-infra 和 k8s-worker 各執行（指令從 kubeadm init 輸出中複製）
sudo kubeadm join 192.168.50.200:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --node-ip=192.168.50.201   # infra 用 .201，worker 用 .202
```

---

## Phase 3 — 驗證

> **執行對象：k8s-master**

```bash
# 確認三節點都是 Ready
kubectl get nodes -o wide

# 確認系統 Pod 全部 Running
kubectl get pods -A

# 測試 Pod 網路
kubectl run test-nginx --image=nginx --restart=Never
kubectl get pod test-nginx -o wide
kubectl delete pod test-nginx
```

---

## 建置記錄

| 步驟 | 狀態 | 時間 | 備註 |
|------|------|------|------|
| Phase 0 - /etc/hosts | ⬜ | | |
| Phase 0 - Swap off | ⬜ | | |
| Phase 0 - Kernel modules | ⬜ | | |
| Phase 0 - sysctl | ⬜ | | |
| Phase 0 - containerd | ⬜ | | |
| Phase 0 - kubeadm/kubelet/kubectl | ⬜ | | |
| Phase 1 - kubeadm init | ⬜ | | |
| Phase 1 - kubectl config | ⬜ | | |
| Phase 1 - Flannel CNI | ⬜ | | |
| Phase 2 - infra join | ⬜ | | |
| Phase 2 - worker join | ⬜ | | |
| Phase 3 - 驗證 | ⬜ | | |


---

## 實際建置結果（2026-04-11）

### kubeadm init 輸出重點

```
[certs] apiserver serving cert is signed for IPs [10.96.0.1 192.168.50.200]
[mark-control-plane] adding taints [node-role.kubernetes.io/control-plane:NoSchedule]
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy
Your Kubernetes control-plane has initialized successfully!
```

### Join Token（已使用）

```bash
kubeadm join 192.168.50.200:6443 --token kgqbt8.0p8z398hsbvlupqs \
  --discovery-token-ca-cert-hash sha256:d9a5d9e219ea5dcea5a01a9d75b386b9ac80ea7827458310b3c30488630cf5dd
```

> ⚠️ Token 有效期 24 小時。過期後用 `kubeadm token create --print-join-command` 重新產生。

### 最終驗證結果

```
$ kubectl get nodes -o wide
NAME         STATUS   ROLES           AGE     VERSION    INTERNAL-IP
k8s-infra    Ready    <none>          87s     v1.32.13   192.168.50.201
k8s-master   Ready    control-plane   9m53s   v1.32.13   192.168.50.200
k8s-worker   Ready    <none>          78s     v1.32.13   192.168.50.202

$ kubectl get pods -A
kube-flannel   kube-flannel-ds-*   1/1   Running  (3 pods, 每節點一個)
kube-system    coredns-*           1/1   Running  (2 pods)
kube-system    etcd-k8s-master     1/1   Running
kube-system    kube-apiserver      1/1   Running
kube-system    kube-controller-*   1/1   Running
kube-system    kube-proxy-*        1/1   Running  (3 pods, 每節點一個)
kube-system    kube-scheduler      1/1   Running
```

### 建置記錄（已完成）

| 步驟 | 狀態 | 備註 |
|------|------|------|
| Phase 0 - /etc/hosts | ✅ | 三台互 ping 正常 |
| Phase 0 - Swap off | ✅ | swapon --show 空白 |
| Phase 0 - Kernel modules | ✅ | overlay + br_netfilter |
| Phase 0 - sysctl | ✅ | ip_forward=1, br_netfilter=1 |
| Phase 0 - containerd | ✅ | SystemdCgroup=true |
| Phase 0 - kubeadm/kubelet/kubectl | ✅ | v1.32.13, apt-mark hold |
| Phase 1 - kubeadm init | ✅ | --apiserver-advertise-address=192.168.50.200 |
| Phase 1 - kubectl config | ✅ | admin.conf → ~/.kube/config |
| Phase 1 - Flannel CNI | ✅ | CoreDNS Pending→Running 自動恢復 |
| Phase 2 - infra join | ✅ | 65s 後 Ready |
| Phase 2 - worker join | ✅ | 56s 後 Ready |
| Phase 3 - 驗證 | ✅ | 三節點全 Ready，13 pods Running |

### 踩到的坑

1. **`--node-ip` 不是 kubeadm 參數**：是 kubelet 參數，不能傳給 `kubeadm init`，移除即可
2. **CoreDNS Pending 是正常現象**：裝 Flannel 前 node NotReady，裝完自動恢復
3. **cloud-init heredoc 問題**：YAML block scalar 內不能用 `<< EOF`（yaml-cpp 誤判），改用 `printf` 解決


### Node Role 設定

```bash
# ROLES 欄位來自 node-role.kubernetes.io/<role> label
kubectl label node k8s-infra  node-role.kubernetes.io/infra=
kubectl label node k8s-worker node-role.kubernetes.io/worker=
```

結果：
```
NAME         STATUS   ROLES           AGE   VERSION
k8s-infra    Ready    infra           4m    v1.32.13
k8s-master   Ready    control-plane   12m   v1.32.13
k8s-worker   Ready    worker          3m    v1.32.13
```

### Phase 3 Pod 測試

```bash
kubectl run test-nginx --image=nginx --restart=Never
kubectl get pod test-nginx -o wide
# NAME         READY   STATUS    IP           NODE
# test-nginx   1/1     Running   10.244.1.2   k8s-infra
kubectl delete pod test-nginx --grace-period=0
```

✅ Pod 成功排程到 k8s-infra，IP 從 Flannel 的 10.244.1.0/24 分配
