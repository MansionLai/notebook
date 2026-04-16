---
title: Commands
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 3
---

# K8s 三節點 + KubeVirt 常用指令

> 分類：commands

## 初始化 Cluster

### 安裝基礎套件（全部節點）

```bash
# 安裝 containerd
sudo apt-get update && sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# 安裝 kubeadm / kubelet / kubectl
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Master: 初始化 Control Plane

```bash
# 初始化（替換 <MASTER_IP>）
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=<MASTER_IP>

# 設定 kubectl
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安裝 Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Infra & Worker: 加入 Cluster

```bash
# 使用 kubeadm init 輸出的 join 指令
sudo kubeadm join <MASTER_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>

# 若 token 已過期（24hr），重新產生
kubeadm token create --print-join-command
```

---

## 設定 Node 角色（Option B）

```bash
# Master: 移除 NoSchedule taint，允許 KubeVirt 管理面元件排程
# （kubeadm init 預設會加 control-plane taint，需先移除才能排 KubeVirt mgmt pods）
kubectl taint nodes master node-role.kubernetes.io/control-plane:NoSchedule-

# 加上自訂 label 供 KubeVirt 管理面元件 nodeSelector 使用
kubectl label nodes master kubevirt-management=true

# 標記並 taint Infra 節點（只跑基礎設施 Pod）
kubectl label nodes infra node-role.kubernetes.io/infra=
kubectl taint nodes infra node-role.kubernetes.io/infra=:NoSchedule

# 標記 Worker 節點（只跑 virt-handler + VM workload）
kubectl label nodes worker node-role.kubernetes.io/worker=
kubectl label nodes worker kubevirt-workload=true

# 驗證節點狀態
kubectl get nodes -o wide
kubectl get nodes --show-labels
```

### KubeVirt 管理面元件 — NodeSelector / Toleration（Option B）

> 安裝 KubeVirt 後，透過 `KubeVirt` CR 的 `infra` 欄位指定管理面元件位置

```yaml
# kubevirt-cr-optionb.yaml
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  # 讓 virt-operator / virt-api / virt-controller 排到 Master
  infra:
    nodePlacement:
      nodeSelector:
        kubevirt-management: "true"
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
  # 讓 virt-handler DaemonSet 只跑在 Worker
  workloads:
    nodePlacement:
      nodeSelector:
        kubevirt-workload: "true"
```

```bash
kubectl apply -f kubevirt-cr-optionb.yaml

# 確認管理面元件在 Master
kubectl get pods -n kubevirt -o wide | grep -E 'virt-operator|virt-api|virt-controller'

# 確認 virt-handler 在 Worker
kubectl get pods -n kubevirt -o wide | grep virt-handler
```

---

## 安裝 KubeVirt

```bash
# 取得最新版本
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest \
  | grep tag_name | cut -d '"' -f4)
echo "Installing KubeVirt $VERSION"

# 安裝 Operator 和 CR
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml

# 等待就緒
kubectl wait --for=condition=Available kubevirt/kubevirt \
  -n kubevirt --timeout=5m

# 驗證
kubectl get kubevirt -n kubevirt
kubectl get pods -n kubevirt
```

### 安裝 virtctl

```bash
export VERSION=$(kubectl get kubevirt -n kubevirt -o jsonpath='{.status.observedKubeVirtVersion}')
curl -Lo virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64
chmod +x virtctl
sudo mv virtctl /usr/local/bin/
```

---

## 建立 Ubuntu 24.04 VM

### VirtualMachine YAML

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ubuntu24
spec:
  running: true
  template:
    spec:
      domain:
        cpu:
          cores: 2
        memory:
          guest: 4Gi
        devices:
          disks:
          - name: containerdisk
            disk:
              bus: virtio
          - name: cloudinitdisk
            disk:
              bus: virtio
      volumes:
      - name: containerdisk
        containerDisk:
          image: quay.io/containerdisks/ubuntu:24.04
      - name: cloudinitdisk
        cloudInitNoCloud:
          userData: |
            #cloud-config
            password: ubuntu
            chpasswd: { expire: False }
            ssh_pwauth: True
```

### 套用與操作

```bash
# 建立 VM
kubectl apply -f ubuntu24-vm.yaml

# 查看 VM 狀態
kubectl get vm ubuntu24
kubectl get vmi ubuntu24

# 進入 VM console
virtctl console ubuntu24

# 開/關 VM
virtctl start ubuntu24
virtctl stop ubuntu24

# SSH（需先設定 Service 或 port-forward）
virtctl ssh ubuntu24
```

---

## 常用診斷指令

```bash
# 查看全部節點
kubectl get nodes -o wide

# 查看所有 namespace 的 Pod
kubectl get pods -A

# 查看 KubeVirt 狀態
kubectl get kubevirt -n kubevirt -o yaml

# 查看 VM 事件
kubectl describe vm ubuntu24
kubectl describe vmi ubuntu24

# 查看節點資源使用
kubectl top nodes

# 查看 etcd 健康（在 Master 執行）
kubectl exec -n kube-system etcd-master -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

---

## 參考資料

- [kubeadm 指令參考](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [KubeVirt virtctl](https://kubevirt.io/user-guide/operations/virtctl_client_tool/)
- [containerdisks 映像清單](https://quay.io/organization/containerdisks)
