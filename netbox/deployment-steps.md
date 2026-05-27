# 完整部署步驟

## 概述

本文檔提供逐步部署 Netbox 的完整指南，包括所有前置準備和驗證步驟。

## 前置準備

- K3s 叢集已運行（3 個節點）
- kubectl 已配置
- Helm 3 已安裝
- 至少 30GB 可用存儲空間

## 第 1 步：添加 Helm Repository

```bash
# 添加官方 Netbox Helm repo
helm repo add netbox-community https://github.com/netbox-community/helm-charts

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
helm pull netbox-community/netbox --untar

# 創建自訂 values 文件
cat > netbox-values.yaml << 'EOF'
# Netbox 副本數
replicaCount: 3

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
  replicaCount: 3
  primary:
    persistence:
      enabled: true
      size: 20Gi
      storageClassName: local-path
  auth:
    username: netbox
    password: netbox
    database: netbox

# Redis 配置
redis:
  enabled: true
  replica:
    replicaCount: 2
  auth:
    enabled: true
    password: redis-password

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
# 部署 Netbox 及其依賴
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
# netbox-xxx                    1/1     Running   0          2m
# netbox-xxx                    1/1     Running   0          2m
# postgresql-0                  1/1     Running   0          3m
# postgresql-1                  1/1     Running   0           2m
# postgresql-2                  1/1     Running   0           2m
# redis-master-0                1/1     Running   0          3m
# redis-replica-0               1/1     Running   0           2m
# redis-replica-1               1/1     Running   0           2m
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
kubectl port-forward svc/netbox 8000:80 -n netbox

# 在瀏覽器中打開
# http://localhost:8000
```

### 選項 2：使用 NodePort（持久訪問）

編輯 service 類型：

```bash
kubectl edit svc netbox -n netbox

# 將 type: ClusterIP 改為 type: NodePort

# 查看分配的端口
kubectl get svc netbox -n netbox

# 預期輸出會顯示 PORT (例如 8080:31234/TCP)
# 訪問：http://localhost:31234
```

## 第 8 步：初始化 Netbox

### 步驟 8.1：創建超級用戶

```bash
# 找到一個 Netbox pod
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
# http://localhost:8000/

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
- [ ] API 可訪問（http://localhost:8000/api/）
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
│  │  Netbox Service (ClusterIP)                         │ │
│  │  ├─ netbox-pod-1                                    │ │
│  │  ├─ netbox-pod-2                                    │ │
│  │  └─ netbox-pod-3                                    │ │
│  │         │                                            │ │
│  │         └──► PostgreSQL Service                     │ │
│  │         │    ├─ postgresql-0 (Primary)              │ │
│  │         │    ├─ postgresql-1 (Replica)              │ │
│  │         │    └─ postgresql-2 (Replica)              │ │
│  │         │         │                                  │ │
│  │         │         └─► PersistentVolume (20Gi)       │ │
│  │         │                                            │ │
│  │         └──► Redis Service                          │ │
│  │              ├─ redis-master-0                      │ │
│  │              ├─ redis-replica-0                     │ │
│  │              └─ redis-replica-1                     │ │
│  │                                                       │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                             │
└───────────────────────────────────────────────────────────┘

    │
    └─► Mac localhost:8000 (port-forward)
```

## 故障排查常見命令

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
