---
title: Phase 3 - Rook-Ceph
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 13
permalink: /kubernetes/3node-kubevirt/phase-3/
---

# Phase 3 — Rook-Ceph

## 範圍

連線我自建的外部 Ceph cluster，透過 Rook-Ceph v1.17 的 External Cluster 模式建立 `StorageClass` 與 `VolumeSnapshotClass`，讓 K8s workload 可以直接使用外部 Ceph 提供的 RBD 儲存。

---

## Phase 3-1：安裝 Rook-Ceph Operator

> 在 **mansion-kubevirt-master** 執行

### Step 3-1-1：部署 Rook-Ceph CRD 與 Operator

> 💡 **理解這三個檔案的角色（大樓維修比喻）：**
> - **`crds.yaml`**：大樓的新規則手冊（定義了什麼叫 CephCluster）。
> - **`common.yaml`**：成立「電梯維修部」(Namespace)、製作「員工工號」(ServiceAccount)、並發給他們「萬能鑰匙和維修授權書」(RBAC)。
> - **`operator.yaml`**：真正聘請進來的「維修技師」(Operator Pod)。

```bash
ROOK_VERSION=v1.17.0

# 部署 CRD
kubectl apply -f \
  https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/crds.yaml

# 部署 common（namespace、RBAC、SA）
kubectl apply -f \
  https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/common.yaml

# 部署 Operator
kubectl apply -f \
  https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/operator.yaml
```

### Step 3-1-2：驗證 Operator 就緒

```bash
kubectl get pods -n rook-ceph -l app=rook-ceph-operator
# 預期：rook-ceph-operator-* 1/1 Running
```

---

## Phase 3-2：建立 External Cluster 設定

> 以下步驟需要你的外部 Ceph cluster admin 金鑰與 monitor 位址

### Step 3-2-1：準備 external cluster 輸入

```bash
# 替換為你的 Ceph cluster 資訊
# 注意：這裡要用 rook 需要的 mon data 格式（monID=ip:port），不是單純逗號分隔 endpoint
CEPH_MON_DATA="a=<mon1_ip>:6789,b=<mon2_ip>:6789,c=<mon3_ip>:6789"
CEPH_CLUSTER_FSID="<fsid>"     # ceph fsid
CEPH_ADMIN_KEY="<admin_key>"   # ceph auth get-key client.admin
```

### Step 3-2-2：建立 ceph-external-cluster namespace 與 secret

> 💡 **為什麼需要這麼多個 Secret？（功能分離與最小權限原則）**
> 雖然在 Lab 中我們都填入 `client.admin` 的金鑰，但 Rook 設計了不同的「門禁卡」位置，讓生產環境可以針對不同組件設定不同權限：
> - **ConfigMap (`mon-endpoints`)**：外部叢集的「通訊錄」，告訴 Rook 去哪裡找 Monitor。
> - **Secret (`mon`)**：外部叢集的「身分證」，包含 FSID 與基礎連線資訊。
> - **Secret (`operator-creds`)**：Operator 的「管理員權限」，用來查詢叢集狀態與建立資源。
> - **Secret (`csi-rbd-*`)**：CSI 驅動的「作業權限」，專門用來建立 (Provisioner) 與掛載 (Node) 磁碟。

```bash
kubectl create namespace ceph-external-cluster

# 1. 外部叢集通訊錄 (Address Book)
# maxMonId: 告訴 Rook 最後一個 Mon 的編號 (a=0, b=1, c=2)，供程式邏輯追蹤用。
kubectl create configmap rook-ceph-mon-endpoints \
  --from-literal=data="${CEPH_MON_DATA}" \
  --from-literal=maxMonId="2" \
  --from-literal=mapping="{}" \
  -n ceph-external-cluster

# 2. 叢集基礎資訊與連線 Secret
kubectl create secret generic rook-ceph-mon \
  --type="kubernetes.io/rook" \
  --from-literal=cluster-name=ceph-external-cluster \
  --from-literal=fsid="${CEPH_CLUSTER_FSID}" \
  --from-literal=admin-secret=admin-secret \
  --from-literal=mon-secret=mon-secret \
  --from-literal=ceph-username=client.admin \
  --from-literal=ceph-secret="${CEPH_ADMIN_KEY}" \
  -n ceph-external-cluster

# 3. Operator 管理員憑證 (Admin Identity)
kubectl create secret generic rook-ceph-operator-creds \
  --type="kubernetes.io/rook" \
  --from-literal=userID=client.admin \
  --from-literal=userKey="${CEPH_ADMIN_KEY}" \
  -n ceph-external-cluster

# 4. CSI 儲存驅動憑證 (Worker Identities)
# 分為 Node (掛載) 與 Provisioner (建立/刪除)，分開是為了未來能做精細權限控管。
kubectl create secret generic rook-csi-rbd-node \
  --type="kubernetes.io/rook" \
  --from-literal=userID=client.admin \
  --from-literal=userKey="${CEPH_ADMIN_KEY}" \
  -n ceph-external-cluster

kubectl create secret generic rook-csi-rbd-provisioner \
  --type="kubernetes.io/rook" \
  --from-literal=userID=client.admin \
  --from-literal=userKey="${CEPH_ADMIN_KEY}" \
  -n ceph-external-cluster
```

> `rook-ceph` namespace 繼續保留給 operator；External Cluster CR 與對應 secret 放在 `ceph-external-cluster`。

### Step 3-2-3：部署 CephCluster（External 模式）

```yaml
# /tmp/ceph-external-cluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph-external
  namespace: ceph-external-cluster
spec:
  external:
    enable: true
  crashCollector:
    disable: true
  healthCheck:
    daemonHealth:
      mon:
        interval: 45s
```

```bash
kubectl apply -f /tmp/ceph-external-cluster.yaml
```

### Step 3-2-4：驗證 External Cluster 連線

```bash
kubectl get cephcluster -n ceph-external-cluster
# 預期：rook-ceph-external  Connected  ...  True

# operator 仍在 rook-ceph
kubectl get pods -n rook-ceph -l app=rook-ceph-operator
# 預期：rook-ceph-operator Running

# 確認 external cluster 依賴資源已存在
kubectl get configmap rook-ceph-mon-endpoints -n ceph-external-cluster
kubectl get secret rook-ceph-mon rook-ceph-operator-creds rook-csi-rbd-node rook-csi-rbd-provisioner \
  -n ceph-external-cluster
```

---

## Phase 3-3：建立 StorageClass（RBD）

> 使用 Ceph RBD 作為 ReadWriteOnce 的 Block storage

### Step 3-3-1：建立 RBD StorageClass

```yaml
# /tmp/ceph-rbd-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: ceph-external-cluster
  pool: k8s_rbd_pool            # 替換為你的 RBD pool 名稱
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: ceph-external-cluster
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: ceph-external-cluster
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: ceph-external-cluster
reclaimPolicy: Delete
allowVolumeExpansion: true
```

```bash
kubectl apply -f /tmp/ceph-rbd-sc.yaml
kubectl get sc
# 預期：ceph-rbd (default)
```

---

## Phase 3-4：建立 VolumeSnapshotClass

### Step 3-4-0：安裝 Snapshot CRD 與 Controller（若尚未安裝）

```bash
# 安裝 VolumeSnapshot CRDs
kubectl apply -k "github.com/kubernetes-csi/external-snapshotter/client/config/crd?ref=v6.3.3"

# 安裝 snapshot-controller
kubectl apply -k "github.com/kubernetes-csi/external-snapshotter/deploy/kubernetes/snapshot-controller?ref=v6.3.3"

# 驗證
kubectl get crd | grep volumesnapshot
kubectl -n kube-system get deploy snapshot-controller
```

### Step 3-4-1：建立 VolumeSnapshotClass

> 若出現 `no matches for kind "VolumeSnapshotClass"`，表示前一步 CRD 尚未安裝完成或尚未就緒。

```yaml
# /tmp/ceph-rbd-snapclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ceph-rbd-snapclass
driver: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: ceph-external-cluster
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: ceph-external-cluster
deletionPolicy: Delete
```

```bash
kubectl apply -f /tmp/ceph-rbd-snapclass.yaml
kubectl get volumesnapshotclass
# 預期：ceph-rbd-snapclass   rook-ceph.rbd.csi.ceph.com
```

---

## Phase 3-5：端對端驗證

```yaml
# /tmp/test-rbd-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-rbd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-rbd
```

```bash
kubectl apply -f /tmp/test-rbd-pvc.yaml
kubectl get pvc test-rbd-pvc
# 預期：STATUS = Bound

# 清除測試資源
kubectl delete pvc test-rbd-pvc
```

---

## 踩坑記錄（Phase 3）

| 問題 | 原因 | 解法 |
|------|------|------|
| `csi-rbdplugin-provisioner` / `csi-cephfsplugin-provisioner` 有 1 個 Pod 長期 Pending | provisioner 需要 2 副本且有 anti-affinity；但 cluster 只有 worker 可排程（master/infra 有 taint） | 為兩個 provisioner deployment 增加 toleration（control-plane/infra），讓第二副本可排到 infra 或 master |
| monitoring PVC 掛載失敗：`driver name rook-ceph.rbd.csi.ceph.com not found` | `csi-rbdplugin` 沒有在掛載目標節點（特別是 infra）運行 | patch `csi-rbdplugin` DaemonSet toleration，確保在 infra/control-plane/worker 都有 rbd node plugin |
