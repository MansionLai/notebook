---
title: Buildup Guide
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 2
---

# K8s 3-Node KubeVirt on Azure — Buildup Guide

> 建立日期：2026-04-12  
> 設計文件：`docs/superpowers/specs/2026-04-12-k8s-kubevirt-azure-design.md`  
> 狀態：📋 建置中

---

## 環境概覽

| 節點 | Azure VM | Private IP | 角色 |
|------|----------|------------|------|
| mansion-k8s-master | Standard_D4s_v4 (4C/16G) | 10.10.10.10 | K8s CP + KubeVirt 管理面 |
| mansion-k8s-infra | Standard_D2s_v4 (2C/8G) | 10.10.10.11 | Prometheus + OpenSearch + Fluent Bit |
| mansion-k8s-worker | Standard_D4s_v4 (4C/16G) | 10.10.10.12 | KubeVirt VM workload |

**Pod 網段：** 10.244.0.0/16（Cilium）  
**KubeVirt VM 網段：** 10.10.100.0/24（kubevirt-subnet，Worker eth1）

---

## Phase 0：Azure VM 建立（Portal GUI）

### Step 0-1：建立 Resource Group

1. Portal → **Resource groups** → **Create**
2. Subscription: 選你的訂閱
3. Resource group name: `mansion_resource`
4. Region: 選你最近的地區（例如 East Asia）
5. → **Review + create** → **Create**

---

### Step 0-2：建立 Virtual Network

1. Portal → **Virtual networks** → **Create**
2. Basics:
   - Resource group: `mansion_resource`
   - Name: `mansion-k8s-vnet`
   - Region: 同上
3. **IP addresses** tab：
   - Address space: `10.10.0.0/16`
   - 刪除預設 subnet，新增兩個：

   | Subnet name | Address range |
   |-------------|---------------|
   | `k8s-subnet` | `10.10.10.0/24` |
   | `kubevirt-subnet` | `10.10.100.0/24` |

4. → **Review + create** → **Create**

---

### Step 0-3：建立 Network Security Group

1. Portal → **Network security groups** → **Create**
2. Name: `k8s-nsg`，Resource group: `mansion_resource`
3. 建立後進入 NSG → **Inbound security rules** → 新增以下規則：

| Priority | Name | Port | Protocol | Source | Action |
|----------|------|------|----------|--------|--------|
| 100 | Allow-SSH | 22 | TCP | **Your IP** | Allow |
| 200 | Allow-K8sAPI | 6443 | TCP | **Your IP** | Allow |
| 300 | Allow-NodePort | 30000-32767 | TCP | **Your IP** | Allow |
| 1000 | Allow-Internal | Any | Any | `10.10.0.0/16` | Allow |

> ⚠️ Source 的 **Your IP** 填你家/辦公室的 Public IP（可到 https://myip.is 查詢）

---

### Step 0-4：建立 3 台 VM

每台 VM 重複以下步驟（共 3 次）：

#### Basics Tab

| 欄位 | mansion-k8s-master | mansion-k8s-infra | mansion-k8s-worker |
|------|-----------|-----------|-----------|
| VM name | `mansion-k8s-master` | `mansion-k8s-infra` | `mansion-k8s-worker` |
| Image | Ubuntu Server 24.04 LTS (Gen2) | 同左 | 同左 |
| Size | Standard_D4s_v4 | Standard_D2s_v4 | Standard_D4s_v4 |
| Auth type | SSH public key | 同左 | 同左 |
| Username | `ubuntu` | 同左 | 同左 |
| SSH key | 貼上你的 public key | 同左 | 同左 |

#### Disks Tab
- OS disk type: **Standard SSD (LRS)**（省費用）

#### Networking Tab
| 欄位 | 設定 |
|------|------|
| Virtual network | `mansion-k8s-vnet` |
| Subnet | `k8s-subnet` |
| Public IP | 建立新的（Static，名稱如 `k8s-master-pip`）|
| NIC network security group | **Advanced** → 選 `k8s-nsg` |

**⚠️ 重要：設定 Static Private IP**

建立後：VM → **Networking** → NIC → **IP configurations** → `ipconfig1` → Assignment 改為 **Static**，IP 填入：

| 節點 | Private IP |
|------|-----------|
| mansion-k8s-master | `10.10.10.10` |
| mansion-k8s-infra | `10.10.10.11` |
| mansion-k8s-worker | `10.10.10.12` |

---

### Step 0-5：Worker 加第二張 NIC

1. **先停止 k8s-worker**（Worker 必須停機才能加 NIC）
2. Portal → k8s-worker → **Networking** → **Attach network interface** → **Create and attach network interface**
3. 設定：
   - Name: `k8s-worker-nic2`
   - Subnet: `kubevirt-subnet`（10.10.100.0/24）
   - Private IP assignment: **Static** → `10.10.100.12`（Worker eth1 IP）
4. 建立後 → 啟動 Worker

---

### Step 0-6：Worker eth1 啟用 IP Forwarding

1. Portal → k8s-worker → **Networking** → 點選第二張 NIC（`k8s-worker-nic2`）
2. → **IP configurations** → 頂部有 **IP forwarding** 選項 → 設為 **Enabled**
3. 儲存

---

### Step 0-7：驗證 VM 建立完成

SSH 進入三台 VM：

```bash
# 從 Portal 取得各 VM 的 Public IP
ssh ubuntu@<MASTER_PUBLIC_IP>
ssh ubuntu@<INFRA_PUBLIC_IP>
ssh ubuntu@<WORKER_PUBLIC_IP>
```

在每台 VM 確認 Private IP 與介面：

```bash
ip addr show
# master 應看到 eth0: 10.10.10.10
# infra  應看到 eth0: 10.10.10.11
# worker 應看到 eth0: 10.10.10.12 + eth1: 10.10.100.1
```

三台互 ping（確認 NSG 允許內部流量）：

```bash
# 在 master 上
ping -c 3 10.10.10.11  # infra
ping -c 3 10.10.10.12  # worker
```

---

## Phase 1：OS 基礎 + kubeadm + Cilium

> **以下 Step 1-1 ~ 1-7 在三台 VM 各執行一遍**（可開三個 Terminal）

### Step 1-1：/etc/hosts 設定

> **目的：** 讓三台 VM 可以用 hostname 互相溝通，kubeadm init/join 時會用到這些名稱。

```bash
sudo tee -a /etc/hosts <<EOF
10.10.10.10 k8s-master
10.10.10.11 k8s-infra
10.10.10.12 k8s-worker
EOF
```

驗證：
```bash
ping -c 1 k8s-master
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
> - 版本需與 K8s 版本一致（此處均為 v1.32）

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings

# 加入 CRI-O 官方 repo（版本對應 K8s 1.32）
KUBERNETES_VERSION=v1.32

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

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

驗證：
```bash
kubeadm version --output short
kubectl version --client --short 2>/dev/null
# 預期：v1.32.x
```

---

### Step 1-8：初始化 Master（僅 k8s-master）

> **目的：** 建立 K8s control plane。`kubeadm init` 會：
> 1. 產生 TLS 憑證（CA、API Server、etcd 等）
> 2. 啟動 etcd、kube-apiserver、kube-controller-manager、kube-scheduler（以 static pod 方式跑在 `/etc/kubernetes/manifests/`）
> 3. 產生 `admin.conf`（kubectl 的認證設定）
> 4. 輸出 `kubeadm join` 指令（含 token 和 CA hash，供 worker/infra 使用）
>
> `--pod-network-cidr=10.244.0.0/16` 是給 Cilium 使用的 Pod IP 段（不與 VM subnet 衝突）。

```bash
sudo kubeadm init \
  --apiserver-advertise-address=10.10.10.10 \
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

### Step 1-9：安裝 Cilium（在 k8s-master）

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
# 預期：k8s-master  Ready  control-plane
```

---

### Step 1-10：Worker / Infra 加入叢集

> **目的：** 讓 infra 和 worker node 加入叢集。`kubeadm join` 會：
> 1. 用 token 向 master API Server 認證
> 2. 用 CA hash 驗證 master 憑證（防止中間人攻擊）
> 3. 下載叢集設定、取得 Node 憑證
> 4. 啟動 kubelet，開始接受 Pod 排程

在 **k8s-infra** 和 **k8s-worker** 各執行 Step 1-8 記錄的 join 指令：

```bash
sudo kubeadm join 10.10.10.10:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

---

### Step 1-11：設定 Node Roles（在 k8s-master）

> **目的：** 為 node 加上 label，讓之後部署的工作負載可以用 `nodeSelector` 或 `affinity` 指定跑在哪台 node。
> K8s 預設只有 `control-plane` label，其他角色需手動設定。

```bash
kubectl label node k8s-infra  node-role.kubernetes.io/infra=
kubectl label node k8s-worker node-role.kubernetes.io/worker=
kubectl label node k8s-infra  role=infra
kubectl label node k8s-worker role=worker
kubectl label node k8s-master role=master
```

驗證：
```bash
kubectl get nodes
# 預期：
# k8s-infra    Ready  infra
# k8s-master   Ready  control-plane
# k8s-worker   Ready  worker
```

---

### Step 1-12：設定 Mac 本機 kubectl

> **目的：** 讓 Mac 本機的 `kubectl` 可以直接管理 Azure 上的叢集，不用每次都 SSH 進去。
> 將 master 的 `admin.conf` 複製到本機，並把 server address 改為 Public IP（因為本機無法直接連 10.10.10.10）。

```bash
# 在 k8s-master 查看 admin.conf
cat ~/.kube/config
```

在 Mac 本機：
```bash
# 複製 config（替換 server IP 為 master 的 Public IP）
scp ubuntu@<MASTER_PUBLIC_IP>:~/.kube/config ~/.kube/config-kubevirt

# 修改 server 為 Public IP
sed -i '' 's|10.10.10.10|<MASTER_PUBLIC_IP>|g' ~/.kube/config-kubevirt

# 合併到 kubeconfig 或直接使用
export KUBECONFIG=~/.kube/config:~/.kube/config-kubevirt
kubectl config rename-context kubernetes-admin@kubernetes k8s-kubevirt
kubectl config use-context k8s-kubevirt
kubectl get nodes
```

---

## Phase 2：Multus CNI

> 在 **k8s-master** 執行

### Step 2-1：安裝 Multus Thick Plugin（multus namespace）

> **目的：** 安裝 Multus CNI，讓 Pod 可以附加多張網路介面（Multi-Network）。
> Multus 作為「meta CNI」，攔截 CNI 呼叫後依 NetworkAttachmentDefinition（NAD）設定，依序呼叫其他 CNI plugin（如 macvlan、ipvlan）。
>
> **設計決策：** 部署在獨立的 `multus` namespace 而非 `kube-system`，讓資源更易管理與隔離。
> 注意：Multus DaemonSet 仍需要 **ClusterRole**（cluster-wide 權限）才能讀取 NAD CRD；CNI binary 和設定檔依 CNI 規範寫到每台 node 的 `/opt/cni/bin/` 和 `/etc/cni/net.d/`，這部分與 namespace 無關。

```bash
# 建立獨立 namespace
kubectl create namespace multus

# 下載官方 thick plugin manifest，替換 namespace 後套用
curl -sL https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml | \
  sed 's/namespace: kube-system/namespace: multus/g' | \
  kubectl apply -f -
```

### Step 2-2：驗證

> **目的：** 確認 Multus DaemonSet 在三台 node 上都成功啟動，且 CNI 設定檔已寫入各 node。

```bash
kubectl get pods -n multus -l app=multus
# 預期：3 個 pod Running（每台 node 一個）
```

```bash
kubectl get daemonset -n multus multus
# 預期：DESIRED=3, READY=3
```

```bash
# 確認 CNI 設定檔已寫入（在任一 node 執行）
ls /etc/cni/net.d/
# 預期：看到 00-multus.conf
```

---

## Phase 3：local-path-provisioner

> 在 **k8s-master** 執行

**目的：** local-path-provisioner 是 Rancher 提供的輕量 StorageClass，直接使用每個 node 本地磁碟（`/opt/local-path-provisioner`），不需要外部 storage backend。後續 Prometheus、OpenSearch 的 PersistentVolumeClaim 都依賴此 StorageClass。

### Step 3-1：安裝

> 套用官方 YAML，會建立 `local-path-storage` namespace、ServiceAccount、ClusterRole、ConfigMap 及 Deployment。

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Step 3-2：設為預設 StorageClass

> K8s 叢集預設沒有任何 StorageClass，PVC 若沒有指定 `storageClassName` 會卡在 Pending。將 `local-path` 設為 default 可讓未指定的 PVC 自動使用本地儲存。

```bash
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Step 3-3：驗證

> 確認 StorageClass 出現且有 `(default)` 標記；Deployment 在 `local-path-storage` namespace Ready。

```bash
kubectl get sc
# 預期：local-path (default)

kubectl get pods -n local-path-storage
# 預期：local-path-provisioner-xxx   1/1   Running
```

---

## Phase 3.5：MetalLB + Istio（Service Mesh + Ingress Gateway）

> 在 **k8s-master** 執行

**目的：** 安裝 Istio 作為 Ingress Gateway，統一管理 Grafana、Prometheus、OpenSearch Dashboards 等服務的外部連線。由於本叢集是自建 K8s（非 AKS），使用 **MetalLB** 賦予 LoadBalancer Service 一個真實 IP，再透過 Azure NAT 從外部連入。

**部署策略：**
- `MetalLB` → 使用 infra 節點的 Private IP（`10.10.10.11`）作為 LB pool，不需 ARP 宣告（Azure 已知此 IP → infra NIC）
- `istiod`（控制面） → **master node**（4C/16G，資源充足；需加 control-plane toleration）
- `IngressGateway`（資料面） → **infra node**（與監控服務同節點，路由效率高）
- 外部存取：`http://20.243.24.191` → Azure NAT → `10.10.10.11:80`
- Sidecar injection → 只對有需要的 namespace 啟用（`monitoring`、`logging`）

### Step 3.5-0：安裝 MetalLB

> Azure 自建 K8s 不支援 cloud-controller，`LoadBalancer` type Service 預設 EXTERNAL-IP 永遠 Pending。
> MetalLB 負責將指定 IP pool 中的地址指派給 LoadBalancer Service。
> 使用 infra 節點現有 Private IP（`10.10.10.11/32`），Azure 已路由此 IP 到 infra NIC，不需額外 Portal 操作。

```bash
# 安裝 MetalLB（官方 manifest）
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# 等待 MetalLB controller 與 speaker 就緒
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# 設定 IP pool：使用 infra 節點的現有 Private IP
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: azure-infra-pool
  namespace: metallb-system
spec:
  addresses:
    - 10.10.10.11/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: azure-infra-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - azure-infra-pool
EOF
```

驗證：

```bash
kubectl get pods -n metallb-system
# 預期：controller-* 1/1 Running，speaker-* 1/1 Running（3 pods）

kubectl get IPAddressPool -n metallb-system
# 預期：azure-infra-pool   True
```

> 完成後，`istio-ingressgateway` Service 的 EXTERNAL-IP 應自動從 `<pending>` 變為 `10.10.10.11`。

### Step 3.5-1：下載 istioctl

> `istioctl` 是 Istio 的命令列安裝與管理工具。這裡固定安裝 1.22.3（LTS 穩定版）。

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.3 sh -
cd istio-1.22.3
export PATH=$PWD/bin:$PATH
istioctl version
```

### Step 3.5-2：建立 IstioOperator 設定檔

> 使用 `minimal` profile（只含 istiod + IngressGateway，不裝 EgressGateway 省資源）。
> istiod 需要加上 master 的 `control-plane:NoSchedule` toleration 才能排程到 master；infra 無 taint，只需 nodeSelector。

```bash
cat > /tmp/istio-operator.yaml <<'EOF'
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
spec:
  profile: minimal
  components:
    pilot:
      k8s:
        nodeSelector:
          role: master
        tolerations:
          - key: "node-role.kubernetes.io/control-plane"
            operator: "Exists"
            effect: "NoSchedule"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          nodeSelector:
            role: infra
          service:
            type: LoadBalancer
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
  values:
    global:
      proxy:
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
EOF
```

### Step 3.5-3：安裝 Istio

> `istioctl install` 讀取 IstioOperator 設定，建立 `istio-system` namespace 並部署 istiod 及 IngressGateway。

```bash
istioctl install -f /tmp/istio-operator.yaml -y
```

### Step 3.5-4：驗證

> 確認 istiod 排到 master node、IngressGateway 排到 infra node；Azure 會自動 provision 一個外部 IP 給 LoadBalancer Service。

```bash
kubectl get pods -n istio-system -o wide
# 預期：istiod-* 在 mansion-k8s-master
#        istio-ingressgateway-* 在 mansion-k8s-infra

kubectl get svc -n istio-system
# 預期：istio-ingressgateway  LoadBalancer  <cluster-ip>  <EXTERNAL-IP>  15021/TCP,80/TCP,443/TCP

istioctl verify-install -f /tmp/istio-operator.yaml
# 預期：✔ Istio is installed and verified successfully
```

### Step 3.5-5：啟用 Sidecar Injection（monitoring / logging namespace）

> Sidecar injection 讓 Istio 自動為 Pod 注入 Envoy proxy，實現 mTLS 和流量觀測。
> 只對需要的 namespace 開啟，避免影響 kube-system 等系統元件。

```bash
# 安裝 Phase 4a/4b 前先執行，讓新建立的 namespace 自動注入
kubectl label namespace monitoring istio-injection=enabled
kubectl label namespace logging istio-injection=enabled
```

---

## Phase 4a：Prometheus Stack（kube-prometheus-stack）

> 在 **k8s-master** 執行

### Step 4a-1：新增 Helm repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 4a-2：建立 values 檔

```bash
cat > /tmp/prometheus-values.yaml <<'EOF'
prometheus:
  prometheusSpec:
    nodeSelector:
      role: infra
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    resources:
      requests:
        memory: 512Mi
        cpu: 200m
      limits:
        memory: 1Gi
        cpu: 500m

alertmanager:
  alertmanagerSpec:
    nodeSelector:
      role: infra

grafana:
  nodeSelector:
    role: infra
  resources:
    requests:
      memory: 128Mi
    limits:
      memory: 256Mi

prometheusOperator:
  nodeSelector:
    role: infra

kube-state-metrics:
  nodeSelector:
    role: infra

prometheus-node-exporter:
  # DaemonSet，部署到所有 node
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
EOF
```

### Step 4a-3：安裝

```bash
kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f /tmp/prometheus-values.yaml
```

### Step 4a-4：驗證

```bash
kubectl get pods -n monitoring
# 預期：prometheus-*, alertmanager-*, grafana-* 在 k8s-infra
#        node-exporter-* 在三台 node 各一個

kubectl get pods -n monitoring -o wide | grep node-exporter
# 預期：3 pods，分別在 master/infra/worker
```

---

## Phase 4b：OpenSearch + OpenSearch Dashboards

> 在 **k8s-master** 執行

### Step 4b-1：新增 Helm repo

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update
```

### Step 4b-2：建立 OpenSearch values

```bash
cat > /tmp/opensearch-values.yaml <<'EOF'
singleNode: true

nodeSelector:
  role: infra

resources:
  requests:
    memory: 512Mi
    cpu: 200m
  limits:
    memory: 1Gi
    cpu: 500m

opensearchJavaOpts: "-Xmx512m -Xms512m"

persistence:
  enabled: true
  storageClass: local-path
  size: 10Gi

config:
  opensearch.yml: |
    cluster.name: k8s-lab
    network.host: 0.0.0.0
    discovery.type: single-node

tolerations:
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"
EOF
```

### Step 4b-3：安裝 OpenSearch

```bash
helm install opensearch opensearch/opensearch \
  -n monitoring \
  -f /tmp/opensearch-values.yaml
```

### Step 4b-4：建立 OpenSearch Dashboards values

```bash
cat > /tmp/opensearch-dashboards-values.yaml <<'EOF'
nodeSelector:
  role: infra

resources:
  requests:
    memory: 256Mi
  limits:
    memory: 512Mi

opensearchHosts: "https://opensearch-cluster-master:9200"

tolerations:
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"
EOF
```

### Step 4b-5：安裝 OpenSearch Dashboards

```bash
helm install opensearch-dashboards opensearch/opensearch-dashboards \
  -n monitoring \
  -f /tmp/opensearch-dashboards-values.yaml
```

### Step 4b-6：驗證

```bash
kubectl get pods -n monitoring -o wide | grep opensearch
# 預期：opensearch-* 和 opensearch-dashboards-* 都在 k8s-infra
```

---

## Phase 4c：Fluent Bit

> 在 **k8s-master** 執行

### Step 4c-1：新增 Helm repo

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

### Step 4c-2：取得 OpenSearch admin 密碼

```bash
# OpenSearch 預設 admin 密碼在 secret 裡
kubectl get secret -n monitoring opensearch-cluster-master -o jsonpath='{.data.username}' | base64 -d
kubectl get secret -n monitoring opensearch-cluster-master -o jsonpath='{.data.password}' | base64 -d
```

> 若 secret 不存在，預設帳號：`admin` 密碼：`admin`

### Step 4c-3：建立 Fluent Bit values

```bash
cat > /tmp/fluent-bit-values.yaml <<'EOF'
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        multiline.parser  docker, cri
        Tag               kube.*
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

  outputs: |
    [OUTPUT]
        Name            opensearch
        Match           kube.*
        Host            opensearch-cluster-master.monitoring.svc.cluster.local
        Port            9200
        HTTP_User       admin
        HTTP_Passwd     admin
        Logstash_Format On
        Logstash_Prefix k8s-logs
        Replace_Dots    On
        Retry_Limit     False
        tls             On
        tls.verify      Off
EOF
```

### Step 4c-4：安裝

```bash
helm install fluent-bit fluent/fluent-bit \
  -n monitoring \
  -f /tmp/fluent-bit-values.yaml
```

### Step 4c-5：驗證

```bash
kubectl get pods -n monitoring -o wide | grep fluent
# 預期：fluent-bit-* 在三台 node 各一個（DaemonSet）

kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=20
# 預期：看到 OpenSearch output 成功的 log（無 Connection refused）
```

---

## Phase 5：KubeVirt + Multus NAD + multus-networkpolicy

### Step 5-1：確認 Worker 支援 Nested Virtualization

在 **k8s-worker** 執行：

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
# 預期：> 0（Azure Dv5 支援 nested virt）

ls /dev/kvm
# 預期：/dev/kvm
```

---

### Step 5-2：安裝 KubeVirt Operator（在 k8s-master）

```bash
KUBEVIRT_VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest \
  | grep '"tag_name"' | cut -d '"' -f 4)
echo "KubeVirt version: $KUBEVIRT_VERSION"

kubectl apply -f \
  https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml
```

驗證 operator 啟動：
```bash
kubectl get pods -n kubevirt -l kubevirt.io=virt-operator
# 預期：virt-operator Running（可能需要 1-2 分鐘）
```

---

### Step 5-3：建立 KubeVirt CR

KubeVirt 管理面（virt-api/virt-controller）需要 toleration 才能排程到 master：

```bash
cat > /tmp/kubevirt-cr.yaml <<'EOF'
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  certificateRotateStrategy: {}
  configuration:
    developerConfiguration:
      featureGates:
        - DataVolumes
        - LiveMigration
        - Sidecar
  customizeComponents:
    patches:
      # virt-api：加 toleration 到 master
      - resourceType: Deployment
        resourceName: virt-api
        patch: '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]},{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":""}}]'
        type: json
      # virt-controller：加 toleration 到 master
      - resourceType: Deployment
        resourceName: virt-controller
        patch: '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]},{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":""}}]'
        type: json
EOF

kubectl apply -f /tmp/kubevirt-cr.yaml
```

---

### Step 5-4：等待 KubeVirt 就緒

```bash
kubectl wait kv kubevirt -n kubevirt \
  --for=condition=Available \
  --timeout=10m

kubectl get pods -n kubevirt -o wide
# 預期：
# virt-operator-*    Running  k8s-master
# virt-api-*         Running  k8s-master
# virt-controller-*  Running  k8s-master
# virt-handler-*     Running  (每台 node 各一個，DaemonSet)
```

---

### Step 5-5：安裝 virtctl

在 **k8s-master** 執行：

```bash
KUBEVIRT_VERSION=$(kubectl get kubevirt -n kubevirt kubevirt \
  -o jsonpath='{.status.observedKubeVirtVersion}')

curl -L -o /tmp/virtctl \
  https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/virtctl-${KUBEVIRT_VERSION}-linux-amd64
sudo install /tmp/virtctl /usr/local/bin/virtctl
```

驗證：
```bash
virtctl version
```

---

### Step 5-6：Worker 設定 vmbr0 Bridge（在 k8s-worker）

#### 臨時設定（立即生效）

```bash
sudo ip link add vmbr0 type bridge
sudo ip link set eth1 master vmbr0
sudo ip link set vmbr0 up
sudo ip link set eth1 up
ip link show vmbr0
```

#### 永久設定（netplan，開機持久化）

```bash
# 查看 eth1 的 MAC address
ip link show eth1

sudo tee /etc/netplan/60-kubevirt-bridge.yaml << 'EOF'
network:
  version: 2
  ethernets:
    eth1:
      dhcp4: false
      dhcp6: false
  bridges:
    vmbr0:
      interfaces: [eth1]
      dhcp4: false
      dhcp6: false
      parameters:
        stp: false
        forward-delay: 0
EOF

sudo netplan apply
ip link show vmbr0
# 預期：vmbr0: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

---

### Step 5-7：建立 NetworkAttachmentDefinition（在 k8s-master）

```bash
kubectl create namespace vmworkloads

cat > /tmp/vmnet-100-nad.yaml <<'EOF'
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: vmnet-100
  namespace: vmworkloads
spec:
  config: '{
    "cniVersion": "0.3.1",
    "name": "vmnet-100",
    "type": "bridge",
    "bridge": "vmbr0"
  }'
EOF

kubectl apply -f /tmp/vmnet-100-nad.yaml
```

驗證：
```bash
kubectl get network-attachment-definitions -n vmworkloads
# 預期：vmnet-100
```

---

### Step 5-8：安裝 multus-networkpolicy

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-networkpolicy/master/deployments/multus-networkpolicy-ds.yml
```

驗證：
```bash
kubectl get pods -n kube-system -l app=multus-networkpolicy
# 預期：DaemonSet Running（3 pods）
```

---

### Step 5-9：最終驗證

```bash
# KubeVirt 完整狀態
kubectl get kubevirt -n kubevirt
# 預期：PHASE = Deployed

# 所有 KubeVirt pods
kubectl get pods -n kubevirt -o wide
# 預期：
# virt-api       → k8s-master
# virt-controller → k8s-master
# virt-handler   → 三台 node

# NAD 確認
kubectl get net-attach-def -A

# 確認 CRD 已安裝
kubectl get crd | grep kubevirt.io
```

---

## 踩坑記錄

| 問題 | 原因 | 解法 |
|------|------|------|
| `kubeadm init` 失敗 — sandbox image 不一致 | CRI-O 預設已對應正確 pause image，通常不會出現此問題 | 若出現，檢查 `/etc/crio/crio.conf` 的 `pause_image` |
| CoreDNS Pending | 未安裝 CNI | 先裝 Cilium，CoreDNS 才會 Running |
| virt-api/controller 一直排程到 worker | master 有 NoSchedule taint | 在 KubeVirt CR 的 customizeComponents 加 toleration + nodeSelector |
| Worker bridge 模式流量被丟棄 | Azure NIC MAC filtering | Portal → NIC (eth1) → Enable IP Forwarding |

---

## 實際結果

```
kubectl get nodes
NAME         STATUS   ROLES           AGE   VERSION
k8s-infra    Ready    infra           -     v1.32.x
k8s-master   Ready    control-plane   -     v1.32.x
k8s-worker   Ready    worker          -     v1.32.x

kubectl get pods -n kubevirt -o wide
NAME                              READY   STATUS    NODE
virt-api-xxx                      1/1     Running   k8s-master
virt-controller-xxx               1/1     Running   k8s-master
virt-handler-xxx (master)         1/1     Running   k8s-master
virt-handler-xxx (infra)          1/1     Running   k8s-infra
virt-handler-xxx (worker)         1/1     Running   k8s-worker
virt-operator-xxx                 1/1     Running   k8s-master
```
