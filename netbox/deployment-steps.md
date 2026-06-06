---
title: 完整部署步驟
parent: Netbox
nav_order: 4
---

# 完整部署步驟

## 概述

本文檔提供在 Azure VM K3s 叢集上逐步部署 NetBox 的完整指南，包括所有前置準備和驗證步驟。

## 前置準備

- Azure VM K3s 叢集已運行
- kubectl 已配置
- Helm 3 已安裝
- 資源群組 `mansion_k3s_netbox` 已建立
- 至少 30GB 可用儲存空間

## 第 1 步：添加 Helm Repository

```bash
# 添加官方 NetBox Helm repo
helm repo add netbox https://charts.netbox.oss.netboxlabs.com/

# 更新 repo
helm repo update

# 驗證
helm repo list
```

## 第 2 步：創建命名空間

```bash
# 創建專用命名空間
kubectl create namespace netbox

# 驗證
kubectl get namespace netbox
```

## 第 3 步：準備 Values 配置文件

```bash
# 拉取官方 chart 以查看默認值
helm pull netbox/netbox --untar

# 創建自訂 values 文件
cat > netbox-values.yaml << 'EOF'
# NetBox 副本數
replicaCount: 1

# Netbox 容器資源
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# PostgreSQL 配置
postgresql:
  enabled: true
  architecture: standalone
  primary:
    persistence:
      enabled: true
      size: 5Gi
      storageClassName: local-path # Azure VM local-path 存儲類
  auth:
    username: netbox
    password: netbox
    database: netbox

# Redis 配置
redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: false

# 注意：
# 這份 values 只會設定 PostgreSQL / Redis 的 credentials，
# 不包含 NetBox GUI 的 admin 初始密碼。
# admin 帳號必須在部署後使用 `python manage.py createsuperuser`
# 或 `python manage.py changepassword <username>` 來建立/重設。

# 如果你要在 Helm deploy 時自動設定固定的 admin 密碼，
# 需要額外加一個 post-install / post-upgrade Job（或 Helm hook）：
# 1. 將 admin 帳密放進 Kubernetes Secret
# 2. 讓 Job 讀取 Secret 後執行 createsuperuser / changepassword
# 3. 讓 Job 保持 idempotent，避免重複部署失敗

# ⚠️ 配置安全提醒
# redis.auth.enabled: false 僅適用於隔離測試環境。
# 若部署在共享或多租戶叢集，必須改為 enabled: true，並以 Kubernetes Secret 管理密碼。

# Service 配置
service:
  type: ClusterIP
  port: 80
  targetPort: 8001
EOF

cat netbox-values.yaml
```

## 第 4 步：驗證配置（Dry Run）

```bash
# 模擬部署以驗證配置
helm install netbox netbox/ \
  -n netbox \
  -f netbox-values.yaml \
  --dry-run --debug

# 如果沒有錯誤，輸出會顯示會被創建的所有資源
```

## 第 5 步：執行實際部署

```bash
# 部署 NetBox 及其依賴
helm install netbox netbox/ \
  -n netbox \
  -f netbox-values.yaml

# 等待 2-3 分鐘讓 pod 啟動
sleep 180
```

## 第 6 步：驗證部署

### 步驟 6.1：查看所有 Pod 狀態

```bash
# 查看 netbox namespace 中的所有 pod
kubectl get pods -n netbox

# 預期輸出：
# NAME                          READY   STATUS    RESTARTS   AGE
# netbox-xxx                    1/1     Running   0          2m
# netbox-worker-xxx             1/1     Running   0          2m
# postgresql-0                  1/1     Running   0          3m
# redis-master-0                1/1     Running   0          3m
```

### 步驟 6.2：詳細檢查 Pod 詳情

```bash
# 查看某個 pod 詳情
kubectl describe pod netbox-xxx -n netbox

# 查看 pod 日誌
kubectl logs netbox-xxx -n netbox

# 監控日誌輸出
kubectl logs -f netbox-xxx -n netbox
```

### 步驟 6.3：檢查 PostgreSQL 連接

```bash
# 進入 PostgreSQL pod
kubectl exec -it postgresql-0 -n netbox -- bash

# 在 pod 內連接數據庫
psql -U netbox -d netbox

# 驗證數據庫
\l  # 列出所有數據庫
\dt  # 列出所有表

# 退出
exit
```

### 步驟 6.4：檢查 Redis 連接

```bash
# 進入 Redis master pod
kubectl exec -it redis-master-0 -n netbox -- redis-cli

# 檢查 Redis 狀態
INFO server
DBSIZE  # 查看存儲的 key 數量

# 退出
exit
```

## 第 7 步：配置外部訪問

### 選項 1：使用 Port Forward（快速測試）

```bash
# 轉發本地端口到 Netbox Service
kubectl port-forward svc/netbox 8080:80 -n netbox

# 在瀏覽器中打開
# http://localhost:8080
```

### 選項 2：使用 NodePort（持久訪問）

編輯 service 類型：

```bash
kubectl edit svc netbox -n netbox

# 將 type: ClusterIP 改為 type: NodePort

# 查看分配的端口
kubectl get svc netbox -n netbox

# 預期輸出會顯示 PORT (例如 80:31234/TCP)
# 訪問：http://<cp-public-ip>:31234
```

### 選項 3：直接對外開 port-forward

如果要從瀏覽器直接打 `http://<cp-public-ip>:8080`，請先在 Azure NSG 放行 `8080`，然後用：

```bash
kubectl port-forward --address 0.0.0.0 svc/netbox 8080:80 -n netbox
```

## 第 8 步：初始化 Netbox

### 步驟 8.1：創建超級用戶

```bash
# 找到一個 NetBox pod
NETBOX_POD=$(kubectl get pod -n netbox -l app=netbox -o jsonpath='{.items[0].metadata.name}')

# 在 pod 中執行初始化
kubectl exec -it $NETBOX_POD -n netbox -- \
  python manage.py createsuperuser

# 按照提示輸入：
# Username: admin
# Email: admin@example.com
# Password: (設定強密碼)
```

### 步驟 8.2：訪問 Web UI

```bash
# 如果使用 port-forward
# http://localhost:8080/

# 登錄：
# Username: admin
# Password: (你設定的密碼)
```

## 第 9 步：功能驗證

### 驗證清單

- [ ] Web UI 可訪問
- [ ] 可以登錄（admin 用戶）
- [ ] 可以添加設備（Device > New Device）
- [ ] 可以添加 IP 地址（IPAM > IP Addresses）
- [ ] API 可訪問（http://localhost:8080/api/）
- [ ] 實時搜索功能正常

### 性能檢查

```bash
# 檢查 pod 資源使用
kubectl top pods -n netbox

# 檢查節點資源使用
kubectl top nodes
```

## 部署架構圖

```
┌───────────────────────────────────────────────────────────┐
│                   K3s Cluster                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐ │
│  │           netbox namespace                          │ │
│  │                                                       │ │
│  │  Netbox Service (ClusterIP，僅提供 Web/API)         │ │
│  │  └─ netbox-pod-1                                    │ │
│  │                                                       │ │
│  │  netbox-worker-pod-1（背景工作 Pod，非 Service 端點）│ │
│  │         │                                            │ │
│  │         └──► PostgreSQL Service                     │ │
│  │         │    ├─ postgresql-0 (Primary)              │ │
│  │         │                                            │ │
│  │         │         │                                  │ │
│  │         │         └─► PersistentVolume (5Gi)        │ │
│  │         │                                            │ │
│  │         └──► Redis Service                          │ │
│  │              ├─ redis-master-0                      │ │
│  │              └─ (standalone)                        │ │
│  │                                                       │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                             │
└───────────────────────────────────────────────────────────┘

    │
    └─► Mac localhost:8080 (port-forward)
```

## 故障排查常見命令

### 資源不足排查（優先順序）

1. **內存不足 (OOMKilled)**：Netbox 在執行 `manage.py migrate` 時非常消耗內存，建議限制至少設為 `1Gi` (本指南已更新為 `2Gi` 以確保 100% 成功)。
2. 檢查 netbox-worker 的記憶體使用量是否過高。
3. 如果節點顯示 `Insufficient cpu`，請檢查是否有多個 pod 競爭同一個節點（特別是 bound 到特定節點的 PVC）。

```bash
# 查看部署狀態
kubectl get deployment -n netbox

# 查看完整事件日誌
kubectl get events -n netbox --sort-by='.lastTimestamp'

# 獲取某個 pod 的完整日誌
kubectl logs netbox-xxx -n netbox --all-containers=true

# 進入 pod 進行調試
kubectl exec -it netbox-xxx -n netbox -- /bin/bash

# 清理部署（如需重新開始）
helm uninstall netbox -n netbox
```

## 下一步

閱讀 [configuration-reference.md](./configuration-reference.md) 了解完整的配置選項。
