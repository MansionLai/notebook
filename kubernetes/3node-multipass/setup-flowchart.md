---
title: Setup Flowchart
parent: 3-Node Multipass (Mac)
grand_parent: Kubernetes
nav_order: 4
---

# Mac Mini K8s 三節點建置流程

> 建立日期：2026-04-11  
> 更新日期：2026-05-17 (修正靜態 IP、CNI 參數與全文件步驟對齊)  
> 分類：flowchart  
> 前置條件：已安裝 Multipass 1.15+、Mac 連接至 192.168.50.x/24 網段

## 總覽流程圖

```mermaid
flowchart TD
    A([開始]) --> B[Step.0\n建立 VM 與靜態 IP 設定]
    B --> C[Step.1\n所有節點環境預備]
    C --> D[Step.2\nMaster 初始化與 Cilium 安裝]
    D --> E[Step.3\nWorker 加入叢集]
    E --> F[Step.4\n節點標記與 Taint]
    F --> G[Step.5\n基礎設施服務部署]
    G --> H[Step.6\n應用部署與最終驗證]
    H --> I([Cluster Ready ✅])
```

---

## Step.0：建立 Multipass VM 與網路設定

```mermaid
flowchart TD
    S([開始]) --> V1[multipass launch --network en0]
    V1 --> V2[進入 VM 修改 Netplan\n設定靜態 IP 192.168.50.201-203]
    V2 --> CHK{三台 VM 都能\n互相 Ping 通靜態 IP?}
    CHK -- Yes --> OK([Step.0 完成])
    CHK -- No --> FIX[檢查 Netplan 設定與 en0 網路]
    FIX --> V2
```

---

## Step.1：所有節點環境預備

```mermaid
flowchart TD
    S([進入每台 VM]) --> HOSTS[設定 /etc/hosts\n寫入三台靜態 IP]
    HOSTS --> SW[關閉 swap]
    SW --> CON[安裝 conntrack socat\nUbuntu 24.04 必裝]
    CON --> MOD[載入核心模組 + sysctl\noverlay + br_netfilter]
    MOD --> CRI[安裝 CRI-O v1.31]
    CRI --> K8S[安裝 kubeadm/kubelet/kubectl]
    K8S --> DONE([Step.1 完成])
```

---

## Step.2：Master 初始化與 Cilium 安裝

```mermaid
flowchart TD
    S([進入 k8s-master]) --> INIT["kubeadm init\n--apiserver-advertise-address=192.168.50.201\n--skip-phases=addon/kube-proxy"]
    INIT --> CILIUM["安裝 Cilium CLI 與 Helm\n指定 k8sServiceHost=192.168.50.201"]
    CILIUM --> DONE([Step.2 完成])
```

---

## Step.3：Worker 加入叢集

```mermaid
flowchart LR
    S([取得 join command]) --> J1["在 k8s-infra 執行\nkubeadm join ..."]
    J1 --> J2["在 k8s-worker 執行\nkubeadm join ..."]
    J2 --> CHK{"kubectl get nodes\n顯示 3 個節點?"}
    CHK -- Yes --> DONE([Step.3 完成])
```

---

## Step.5：基礎設施服務部署

```mermaid
flowchart TD
    S([在 Master 執行]) --> H1[部署 ingress-nginx]
    H1 --> H2[部署 metrics-server]
    H2 --> H3[部署 kube-prometheus-stack\non Infra Node]
    H3 --> H4[部署 OpenSearch + Fluent-bit]
    H4 --> DONE([Step.5 完成])
```

---

## Step.6：應用部署與驗證

```mermaid
flowchart TD
    S([驗證]) --> APP[部署 Simple Web App\non Worker Node]
    APP --> CHK{透過 NodePort\n存取網頁正常?}
    CHK -- Yes --> DONE([🎉 Cluster 完整建置完成])
    CHK -- No --> DBG[檢查 Service 與 Pod 狀態]
```

---

## 驗證 Checklist

- [ ] 所有節點狀態為 **Ready** (`kubectl get nodes`)
- [ ] Cilium 狀態為 **OK** (`cilium status`)
- [ ] 所有系統 Pod 狀態為 **Running**
- [ ] 可從 Mac Mini 存取 Web App NodePort
- [ ] Grafana 儀表板可正常開啟
