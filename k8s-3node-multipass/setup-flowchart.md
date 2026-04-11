# Mac Mini K8s 三節點建置流程

> 建立日期：2026-04-11  
> 分類：flowchart  
> 前置條件：已安裝 Multipass 1.15+、Mac 連接至 192.168.50.x/24 網段

## 概述

從零開始，在 Mac Mini M4 上用 Multipass 建立三台 Ubuntu 24.04 VM，完成 K8s 三節點 Cluster 的完整建置流程，涵蓋 VM 建立、K8s 初始化、CNI 安裝、節點標記與基礎設施部署。

---

## 總覽流程圖

```mermaid
flowchart TD
    A([開始]) --> B[Phase 1\n建立 Multipass VM]
    B --> C[Phase 2\n所有節點安裝前置套件]
    C --> D[Phase 3\nMaster 初始化 kubeadm]
    D --> E[Phase 4\nInfra + Worker 加入 Cluster]
    E --> F[Phase 5\n安裝 CNI - Flannel]
    F --> G[Phase 6\n標記節點 Label]
    G --> H[Phase 7\n部署基礎設施服務]
    H --> I([Cluster Ready ✅])
```

---

## Phase 1：建立 Multipass VM

```mermaid
flowchart LR
    S([開始]) --> V1
    V1["multipass launch ubuntu:24.04\n--name k8s-master\n--cpus 4 --memory 6G\n--disk 30G --network en0"]
    V2["multipass launch ubuntu:24.04\n--name k8s-infra\n--cpus 2 --memory 4G\n--disk 30G --network en0"]
    V3["multipass launch ubuntu:24.04\n--name k8s-worker\n--cpus 4 --memory 8G\n--disk 40G --network en0"]
    V1 --> V2 --> V3
    V3 --> CHK{3台 VM\n都有 192.168.50.x IP?}
    CHK -- Yes --> OK([Phase 1 完成])
    CHK -- No --> FIX[檢查 Multipass bridge 設定\nmultipass set local.bridged-network=en0]
    FIX --> V1
```

---

## Phase 2：所有節點安裝前置套件

> 三台 VM 都需執行，可平行操作

```mermaid
flowchart TD
    START([進入每台 VM\nmultipass shell k8s-xxx]) --> SW[關閉 swap\nswapoff -a]
    SW --> MOD[載入核心模組\noverlay + br_netfilter]
    MOD --> SYSCTL[設定 sysctl\n啟用 ip_forward + bridge iptables]
    SYSCTL --> CTR[安裝 containerd\napt install containerd]
    CTR --> CTR2[設定 containerd\nSystemdCgroup = true]
    CTR2 --> K8S[安裝 K8s 套件\nkubeadm + kubelet + kubectl]
    K8S --> HOLD[apt-mark hold\n防止自動升級]
    HOLD --> DONE([此節點前置完成])
```

---

## Phase 3：Master 初始化

```mermaid
flowchart TD
    S([進入 k8s-master]) --> IP[確認 Master IP\nhostname -I]
    IP --> INIT["kubeadm init\n--apiserver-advertise-address=192.168.50.x\n--pod-network-cidr=10.244.0.0/16"]
    INIT --> CHK{init 成功?}
    CHK -- No --> LOG[查看錯誤\nkubeadm reset 後重試]
    LOG --> INIT
    CHK -- Yes --> KUBE[設定 kubectl\nmkdir ~/.kube\ncp /etc/kubernetes/admin.conf ~/.kube/config]
    KUBE --> SAVE["記錄 join command\nkubeadm token create --print-join-command"]
    SAVE --> DONE([Phase 3 完成])
```

---

## Phase 4：Infra + Worker 加入 Cluster

```mermaid
flowchart LR
    S([取得 join command]) --> J1
    J1["在 k8s-infra 執行\nkubeadm join 192.168.50.x:6443\n--token xxx --discovery-token-ca-cert-hash sha256:xxx"]
    J2["在 k8s-worker 執行\nkubeadm join 192.168.50.x:6443\n--token xxx --discovery-token-ca-cert-hash sha256:xxx"]
    J1 --> J2
    J2 --> CHK{"kubectl get nodes\n顯示 3 個 NotReady?"}
    CHK -- Yes --> DONE([Phase 4 完成\n等待 CNI 安裝])
    CHK -- No --> DBG[kubectl describe node\n查看錯誤]
```

---

## Phase 5：安裝 CNI（Flannel）

```mermaid
flowchart TD
    S([在 Master 執行]) --> APPLY["kubectl apply -f\nhttps://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"]
    APPLY --> WAIT[等待 flannel Pod Running\nkubectl get pods -n kube-flannel]
    WAIT --> CHK{"kubectl get nodes\n全部 Ready?"}
    CHK -- Yes --> DONE([Phase 5 完成 ✅])
    CHK -- No --> LOG[kubectl logs -n kube-flannel\n查看 flannel 錯誤]
    LOG --> DBG[確認 pod-network-cidr\n是否為 10.244.0.0/16]
```

---

## Phase 6：節點標記

```mermaid
flowchart LR
    S([Master 執行]) --> L1["kubectl label node k8s-infra\nnode-role.kubernetes.io/infra=''"]
    L1 --> L2["kubectl label node k8s-worker\nnode-role.kubernetes.io/worker=''"]
    L2 --> T1["kubectl taint node k8s-master\nnode-role.kubernetes.io/control-plane:NoSchedule"]
    T1 --> DONE([Phase 6 完成\n確保 workload 不排到 Master])
```

---

## Phase 7：部署基礎設施服務

```mermaid
flowchart TD
    S([安裝 Helm]) --> H1[helm repo add ingress-nginx]
    H1 --> H2["helm install ingress-nginx\ningress-nginx/ingress-nginx\n--set nodeSelector.node-role=infra"]
    H2 --> H3[kubectl apply -f metrics-server.yaml]
    H3 --> H4[helm repo add prometheus-community]
    H4 --> H5["helm install kube-prometheus-stack\n--set grafana.nodeSelector.node-role=infra\n--set prometheus.nodeSelector.node-role=infra"]
    H5 --> CHK{所有 Pod Running?}
    CHK -- Yes --> DONE([🎉 Cluster 完整建置完成])
    CHK -- No --> LOG[kubectl get pods -A\n找出失敗的 Pod]
```

---

## 驗證 Checklist

```bash
# 確認所有節點 Ready
kubectl get nodes -o wide

# 確認核心 Pod 正常
kubectl get pods -n kube-system

# 確認 Infra 服務
kubectl get pods -n ingress-nginx
kubectl get pods -n monitoring

# 測試 DNS
kubectl run test --image=busybox --restart=Never -- nslookup kubernetes.default

# 測試 Ingress
curl -H "Host: test.local" http://192.168.50.x
```

---

## 參考資料

- [Multipass Bridge Networking](https://multipass.run/docs/create-an-instance#heading--bridged)
- [kubeadm 安裝指南](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Flannel CNI](https://github.com/flannel-io/flannel)
- [ingress-nginx Helm](https://kubernetes.github.io/ingress-nginx/deploy/#quick-start)
