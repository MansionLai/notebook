---
title: Phase 3 - Storage + Ingress
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 13
---

# Phase 3 — Storage + Ingress

## 範圍

本頁整合原本的 `Phase 3` 與 `Phase 3.5`，因為兩者都屬於 storage / ingress / traffic entry 相關的基礎設施配置。

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
- `istiod`（控制面） → **infra node**（與監控服務同節點；需加 infra toleration）
- `IngressGateway`（資料面） → **infra node**（與監控服務同節點，路由效率高）
- 外部存取：`http://20.243.24.191` → Azure NAT → `10.10.10.11:80`
- Sidecar injection → 只對有需要的 namespace 啟用（`monitoring`）

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
> istiod 以 Infra 為目標，使用 infra taint / toleration 模型來排程到 infra node。

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
          role: infra
        tolerations:
          - key: "node-role.kubernetes.io/infra"
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

> 確認 istiod 與 IngressGateway 都排到 infra node；Azure 會自動 provision 一個外部 IP 給 LoadBalancer Service。

```bash
kubectl get pods -n istio-system -o wide
# 預期：istiod-* 在 mansion-k8s-infra
#        istio-ingressgateway-* 在 mansion-k8s-infra

kubectl get svc -n istio-system
# 預期：istio-ingressgateway  LoadBalancer  <cluster-ip>  <EXTERNAL-IP>  15021/TCP,80/TCP,443/TCP

istioctl verify-install -f /tmp/istio-operator.yaml
# 預期：✔ Istio is installed and verified successfully
```

---


