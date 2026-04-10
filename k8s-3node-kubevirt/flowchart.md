# K8s 三節點 + KubeVirt 架設流程

> 分類：flowchart

## 架設流程圖

```mermaid
flowchart TD
    A([開始]) --> B[申請 3 台 Azure VM\nMaster · Infra · Worker]
    B --> C[三台 VM 安裝基礎套件\ncontainerd · kubeadm · kubelet · kubectl]
    C --> D[Master: kubeadm init\n初始化 Control Plane]
    D --> E[安裝 CNI Plugin\nFlannel / Calico]
    E --> F[Infra & Worker: kubeadm join\n加入 Cluster]
    F --> G[設定 Node 角色\nlabel + taint]
    G --> H1[Infra: 安裝 CoreDNS\nIngress / Metrics / 監控]
    G --> H2[Worker: 確認 /dev/kvm 可用]
    H1 --> I[驗證 Cluster 健康\nkubectl get nodes]
    H2 --> I
    I --> J[安裝 KubeVirt Operator\n到 Worker Node]
    J --> K[等待 KubeVirt Ready\nkubectl get kubevirt -n kubevirt]
    K --> L[套用 VirtualMachine YAML\nUbuntu 24.04]
    L --> M[透過 virtctl 進入 VM\nvirtctl console ubuntu24]
    M --> N([完成 ✅])
```

---

## 流程說明

| 步驟 | 動作 | 執行節點 |
|------|------|---------|
| 1 | 申請 Azure VM（Master/Infra/Worker） | — |
| 2 | 安裝 containerd + kubeadm + kubelet + kubectl | 全部 |
| 3 | `kubeadm init` 初始化 Control Plane | Master |
| 4 | 安裝 CNI Plugin（Flannel） | Master |
| 5 | `kubeadm join` 加入 Cluster | Infra, Worker |
| 6 | 設定 Node label + taint | Master (kubectl) |
| 7 | 部署 CoreDNS / Ingress / Prometheus | Infra |
| 8 | 確認 `/dev/kvm` 可用（Nested Virt） | Worker |
| 9 | 驗證 `kubectl get nodes` 全部 Ready | Master (kubectl) |
| 10 | 安裝 KubeVirt Operator + CR | Master (kubectl) |
| 11 | 等待 KubeVirt Available | Master (kubectl) |
| 12 | 套用 Ubuntu 24.04 VirtualMachine YAML | Master (kubectl) |
| 13 | `virtctl console ubuntu24` 進入 VM | Master (virtctl) |

---

## 參考資料

- [kubeadm 安裝指南](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [KubeVirt 安裝指南](https://kubevirt.io/user-guide/operations/installation/)
- [Flannel 安裝](https://github.com/flannel-io/flannel)
