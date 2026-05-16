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

```bash
ROOK_VERSION=v1.17.0

# 部署 CRD
kubectl apply -f \
  https://raw.githubusercontent.com/rook/rook/${ROOK_VERSION}/deploy/examples/crds.yaml

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
CEPH_MON_ENDPOINTS="<mon1_ip>:6789,<mon2_ip>:6789,<mon3_ip>:6789"
CEPH_CLUSTER_ID="<fsid>"       # ceph fsid
CEPH_ADMIN_KEY="<admin_key>"   # ceph auth get-key client.admin
```

### Step 3-2-2：建立 rook-ceph namespace 與 secret

```bash
kubectl create namespace rook-ceph

kubectl create secret generic rook-ceph-mon \
  --from-literal=ceph-username=client.admin \
  --from-literal=ceph-secret="${CEPH_ADMIN_KEY}" \
  -n rook-ceph
```

### Step 3-2-3：部署 CephCluster（External 模式）

```yaml
# /tmp/ceph-external-cluster.yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph-external
  namespace: rook-ceph
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
kubectl get cephcluster -n rook-ceph
# 預期：rook-ceph-external  Connected  ...  True

kubectl get pods -n rook-ceph
# 預期：rook-ceph-operator Running；無 OSD/MON pods（外部模式不部署本地 OSD）
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
  clusterID: rook-ceph
  pool: kubernetes              # 替換為你的 RBD pool 名稱
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
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

```yaml
# /tmp/ceph-rbd-snapclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ceph-rbd-snapclass
driver: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
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
