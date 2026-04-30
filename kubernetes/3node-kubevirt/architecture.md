---
title: Architecture
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 1
---

# K8s 三節點架構：Master / Infra / Worker + KubeVirt（Option A）

> 分類：architecture  
> 架構決策：目前主方案採用 Option A — Master 只承載 K8s Control Plane，Infra 承載基礎設施服務與 KubeVirt 管理面

## 概述

使用三台 x86 VM 在 Azure 上架設 Kubernetes Cluster。本文目前主採用 **Option A** 架構：Master 只承載 K8s 控制面，Infra 同時承載基礎設施服務與 KubeVirt 管理面，Worker 專責執行 virt-handler、virt-launcher 與 VM workload。

---

## 架構圖

```mermaid
graph TB
    subgraph Azure["Azure Cloud"]
        subgraph Master["Master Node (Standard_D2s_v5 · 2C/8G)"]
            API[kube-apiserver]
            ETCD[(etcd)]
            SCH[kube-scheduler]
            CM[kube-controller-manager]
            API <--> ETCD
            API <--> SCH
            API <--> CM
        end

        subgraph Infra["Infra Node (Standard_D4s_v5 · 4C/16G)"]
            DNS[CoreDNS]
            ING[Ingress Controller]
            MS[Metrics Server]
            PROM[Prometheus]
            GRAF[Grafana]
            FLUE[Fluentd / Loki]
            VO[virt-operator]
            VA[virt-api]
            VC[virt-controller]
            VO --> VA
            VO --> VC
        end

        subgraph Worker["Worker Node (Standard_D4s_v5 · 4C/16G · Nested Virt)"]
            VH[virt-handler\nDaemonSet]
            VL[virt-launcher]
            UB[Ubuntu 24.04 VM\nQEMU/KVM]
            KVM["/dev/kvm"]
            VH --> VL --> UB
            UB --> KVM
        end

        Infra  -- "kubelet registers" --> API
        Worker -- "kubelet registers" --> API
        ING    -- "routes traffic" --> Worker
        VC     -- "schedules VMI" --> Worker
        VA     -- "talks to" --> API
    end

    User((User))   -- HTTPS --> ING
    Admin((Admin)) -- kubectl --> API
    Admin          -- virtctl --> VA
```

---

## 元件分配表

### Master Node — K8s 控制面

| 類別 | 元件 | 功能 | CPU 消耗 |
|------|------|------|---------|
| K8s CP | `kube-apiserver` | Cluster 唯一 API 入口 | 0.1–0.5 vCPU |
| K8s CP | `etcd` | 儲存全部 Cluster 狀態 | 0.1–0.3 vCPU |
| K8s CP | `kube-scheduler` | 決定 Pod 排程到哪個 Node | <0.05 vCPU |
| K8s CP | `kube-controller-manager` | 維護期望狀態（RS/Node/SA） | 0.05–0.2 vCPU |
| | `kubelet` | 管理 Master 上的 Pod | — |
| | **合計** | | **~0.4–1.2 vCPU** |

> ⚠️ etcd 對延遲敏感，Master 需使用 **D-series（非 Burstable B-series）**，確保穩定 CPU

### Infra Node — Cluster 基礎設施服務 + KubeVirt 管理面

| 元件 | 功能 | CPU 消耗 | 備註 |
|------|------|---------|------|
| `CoreDNS` | Cluster 內部 DNS | <0.05 vCPU | 所有 Pod 依賴 |
| `Ingress Controller` | 管理外部流量進入 | 0.1–0.5 vCPU | nginx / traefik |
| `Metrics Server` | 提供 HPA/VPA metrics | <0.05 vCPU | 輕量但關鍵 |
| `Prometheus` | Cluster 監控 | **0.5–1.5 vCPU** | 資源消耗大，需獨立 |
| `Grafana` | 監控視覺化儀表板 | 0.1–0.3 vCPU | 搭配 Prometheus |
| `Fluentd / Loki` | Log 收集與彙整 | 0.2–0.5 vCPU | I/O 密集型 |
| `virt-operator` | 管理 KubeVirt 自身生命週期 | <0.05 vCPU | 平時極輕量 |
| `virt-api` | 處理 VM/VMI API 請求 | 0.1–0.3 vCPU | 與 K8s API 協作 |
| `virt-controller` | 管理 VM 狀態機 | 0.1–0.3 vCPU | 負責 VMI 排程 |
| **合計** | | **~1.3–3.6 vCPU** | Prometheus + KubeVirt 管理面 |

> 💡 virt-operator 平時幾乎不消耗資源，只在安裝/升級 KubeVirt 時才活躍

### Worker Node — virt-handler + VM Workload

| 元件 | 功能 | CPU 需求 | 備註 |
|------|------|---------|------|
| `virt-handler` | Node-level KVM agent（DaemonSet） | ~0.2 vCPU | 直接存取 /dev/kvm |
| `virt-launcher` | 包裝 QEMU 行程（per-VM Pod） | — | 每個 VM 一個 |
| `Ubuntu 24.04 VM` | 目標 Guest VM | **2 vCPU** | 直接佔用 Host CPU |
| K8s overhead | kubelet | ~0.1 vCPU | 固定消耗 |
| KVM overhead | Nested virt 損耗 | ~5–10% | — |
| **合計** | | **≥4 vCPU** | 建議 6–8 |

> ⚠️ Worker 必須選支援 **Nested Virtualization** 的 Azure VM（Dv3/Dv4/Dv5 系列）

---

## Option B（保留參考）

> 備註：此方案保留作為 Lab / 對照參考；目前主方案為 **Option A**。

Option B 的核心想法是：**Master 同時承載 K8s Control Plane 與 KubeVirt 管理面**。這樣可以讓所有管理元件集中在同一台機器，概念上較為一致，適合 Lab 環境。代價是 Master 需要更多資源，且單點故障影響範圍更大。

| 節點 | Option B 的角色 |
|------|-----------------|
| Master | `kube-apiserver`、`etcd`、`kube-scheduler`、`kube-controller-manager`、`virt-operator`、`virt-api`、`virt-controller` |
| Infra | `CoreDNS`、`Ingress Controller`、`Metrics Server`、`Prometheus`、`Grafana`、`Fluentd/Loki` |
| Worker | `virt-handler`、`virt-launcher`、`Ubuntu 24.04 VM`、`/dev/kvm` |

### Option B 簡圖

```mermaid
graph TB
    subgraph Azure["Azure Cloud"]
        subgraph MasterB["Master Node"]
            direction TB
            subgraph K8sCP["K8s Control Plane"]
                APIB[kube-apiserver]
                ETCDB[(etcd)]
                SCHB[kube-scheduler]
                CMB[kube-controller-manager]
                APIB <--> ETCDB
                APIB <--> SCHB
                APIB <--> CMB
            end
            subgraph KVCtrl["KubeVirt Management Plane"]
                VOB[virt-operator]
                VAB[virt-api]
                VCB[virt-controller]
                VOB -- manages --> VAB
                VOB -- manages --> VCB
            end
            VAB -- registers with --> APIB
            VCB -- watches --> APIB
        end

        subgraph InfraB["Infra Node"]
            DNSB[CoreDNS]
            INGB[Ingress Controller]
            PROMB[Prometheus]
            GRAFB[Grafana]
            LOGB[Fluentd / Loki]
        end

        subgraph WorkerB["Worker Node"]
            VHB[virt-handler]
            VLB[virt-launcher]
            VBB[Ubuntu 24.04 VM]
            KVMB["/dev/kvm"]
            VHB --> VLB --> VBB
            VBB --> KVMB
        end

        InfraB  -- "kubelet registers" --> APIB
        WorkerB -- "kubelet registers" --> APIB
        INGB    -- "routes traffic" --> WorkerB
        VCB     -- "schedules VMI" --> WorkerB
    end

    UserB((User))   -- HTTPS   --> INGB
    AdminB((Admin)) -- kubectl --> APIB
    AdminB          -- virtctl --> VAB
```

### Option B 的特點

1. Option B 讓 `virt-api` / `virt-controller` 與 K8s Control Plane 放在一起，整體概念更一致，對 Lab 環境更容易理解。
2. 代價是 Master 需要較多資源（Standard_D4s_v5 4C/16G），且單點故障會同時失去 K8s CP 與 KubeVirt 管理面。
3. 適合 Lab / 中低 VM 密度環境；高 VM 密度生產環境建議採用 **Option A**。

---

## Azure VM 規格建議（Option A）

### Lab / Dev 環境

| 節點 | 推薦 VM | vCPU | RAM | 月費(約) | 說明 |
|------|---------|------|-----|---------|------|
| Master | **Standard_D2s_v5** | 2 | 8GB | ~$70 USD | K8s Control Plane only |
| Infra | **Standard_D4s_v5** | 4 | 16GB | ~$140 USD | 基礎設施服務 + KubeVirt 管理面 |
| Worker | **Standard_D4s_v5** | 4 | 16GB | ~$140 USD | Nested Virt + Ubuntu VM |
| **合計** | | **10 vCPU** | **40GB** | **~$350/月** | |

### Production / 穩定環境

| 節點 | 推薦 VM | vCPU | RAM | 月費(約) | 說明 |
|------|---------|------|-----|---------|------|
| Master | **Standard_D2s_v5** | 2 | 8GB | ~$70 USD | K8s CP 穩定配置 |
| Infra | **Standard_D4s_v5** | 4 | 16GB | ~$140 USD | Prometheus + Loki + KubeVirt 管理面 |
| Worker | **Standard_D8s_v5** | 8 | 32GB | ~$280 USD | 可跑多個 KubeVirt VM |
| **合計** | | **14 vCPU** | **56GB** | **~$490/月** | |

---

## 架構決策說明（Option A vs B）

| | Option A（採用）| Option B（參考）|
|-|----------------|-----------------|
| KubeVirt 管理面 | **Infra Node** | Master Node |
| 概念一致性 | 管理面分散兩處 | 管理面集中 |
| etcd 鄰居風險 | ✅ 低（Master 單純） | 中（需 D4s_v5） |
| 適合情境 | ✅ 高 VM 密度生產 | Lab / 中低密度 |
| Master 掛掉影響 | ✅ 只失去 K8s CP | K8s CP + KubeVirt 管理面 |
| 資源彈性 | ✅ Infra 可獨立擴充 | Master 需更大規格 |

---

## 參考資料

- [Kubernetes 官方文件](https://kubernetes.io/docs/)
- [KubeVirt 官方文件](https://kubevirt.io/user-guide/)
- [KubeVirt Architecture](https://kubevirt.io/user-guide/architecture/)
- [Azure Dv5 Series](https://learn.microsoft.com/en-us/azure/virtual-machines/dv5-dsv5-series)
- [etcd Hardware Recommendations](https://etcd.io/docs/v3.5/op-guide/hardware/)
