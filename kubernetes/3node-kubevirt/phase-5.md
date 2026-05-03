---
title: Phase 5 - KubeVirt 平台層
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 15
---

# Phase 5 — KubeVirt 平台層


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

KubeVirt 管理面（virt-api/virt-controller）排程到 Infra node：

```bash
cat > /tmp/kubevirt-cr.yaml <<'EOF'
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  certificateRotateStrategy: {}
  # 整合 Prometheus 監控：virt-operator 自動建立 ServiceMonitor + PrometheusRules
  monitorNamespace: monitoring
  monitorAccount: kube-prometheus-stack-prometheus
  configuration:
    developerConfiguration:
      featureGates:
        - DataVolumes
        - LiveMigration
        - Sidecar
  customizeComponents:
    patches:
      # virt-api：排到 Infra
      - resourceType: Deployment
        resourceName: virt-api
        patch: '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/infra","operator":"Exists","effect":"NoSchedule"}]},{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"kubevirt-management":"true"}}]'
        type: json
      # virt-controller：排到 Infra
      - resourceType: Deployment
        resourceName: virt-controller
        patch: '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/infra","operator":"Exists","effect":"NoSchedule"}]},{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"kubevirt-management":"true"}}]'
        type: json
      # virt-handler：只部署在 worker node（DaemonSet）
      - resourceType: DaemonSet
        resourceName: virt-handler
        patch: '[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"kubevirt-workload":"true"}}]'
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
# virt-operator-*    Running  k8s-infra
# virt-api-*         Running  k8s-infra
# virt-controller-*  Running  k8s-infra
# virt-handler-*     Running  k8s-worker（DaemonSet + nodeSelector kubevirt-workload=true）
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
kubectl create namespace vmnetwork

cat > /tmp/vmnet-100-nad.yaml <<'EOF'
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: vmnet-100
  namespace: vmnetwork
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
kubectl get network-attachment-definitions -n vmnetwork
# 預期：vmnet-100
```

---

### Step 5-8：安裝 multus-networkpolicy

> **注意：** GitHub raw URL 可能 404（路徑已改變），改用本機 clone 後 scp 到 master。

```bash
# 在 Mac 本機 clone（若尚未有）
git clone https://github.com/k8snetworkplumbingwg/multus-networkpolicy /tmp/multus-networkpolicy

# scp deploy.yml 到 master
scp -i ~/.ssh/id_ed25519 /tmp/multus-networkpolicy/deploy.yml \
  ubuntu@<master-ip>:/tmp/multus-networkpolicy-deploy.yml

# 在 k8s-master 執行
kubectl apply -f /tmp/multus-networkpolicy-deploy.yml
```

驗證：
```bash
kubectl get pods -n kube-system | grep multi-networkpolicy
# 預期：multi-networkpolicy-ds-amd64-* Running（三台 node 各一個）
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
# virt-api       → k8s-infra（2 replicas）
# virt-controller → k8s-infra（2 replicas）
# virt-handler   → 只在 k8s-worker（DaemonSet + nodeSelector kubevirt-workload=true）
# virt-operator  → k8s-infra（2 replicas）

# NAD 確認
kubectl get network-attachment-definitions -n vmnetwork
# 預期：vmnet-100

# multus-networkpolicy DaemonSet
kubectl get ds multi-networkpolicy-ds-amd64 -n kube-system
# 預期：DESIRED=3 CURRENT=3 READY=3

# virtctl 版本
virtctl version --client
```

---

## 踩坑記錄

| 問題 | 原因 | 解法 |
|------|------|------|
| `kubeadm init` 失敗 — sandbox image 不一致 | CRI-O 預設已對應正確 pause image，通常不會出現此問題 | 若出現，檢查 `/etc/crio/crio.conf` 的 `pause_image` |
| CoreDNS Pending | 未安裝 CNI | 先裝 Cilium，CoreDNS 才會 Running |
| virt-api/controller 一直排程到 worker | Infra 節點未標記或無 toleration | 在 KubeVirt CR 的 customizeComponents 加 toleration + nodeSelector (kubevirt-management=true) |
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
virt-api-xxx                      1/1     Running   k8s-infra
virt-controller-xxx               1/1     Running   k8s-infra
virt-handler-xxx (worker)         1/1     Running   k8s-worker
virt-operator-xxx                 1/1     Running   k8s-infra
```

---
