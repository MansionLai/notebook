---
title: Phase 2 - Multus CNI
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 12
permalink: /kubernetes/3node-kubevirt/phase-2/
---

# Phase 2 — Multus CNI

> 在 **mansion-kubevirt-master** 執行

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

