# Helm Chart 深度指南

## 概述

本指南詳細解析官方 Netbox Helm chart 的結構，幫助你理解每個配置項的含義，並學會根據需要調整部署。

## Netbox Helm Chart 結構

官方 Netbox Helm chart 地址：https://github.com/netbox-community/helm-charts

### 目錄結構

```
netbox/
├── Chart.yaml              # Chart 元數據
├── values.yaml             # 默認配置值（最重要）
├── charts/                 # 依賴 chart
│   ├── postgresql/         # PostgreSQL chart
│   └── redis/              # Redis chart
├── templates/              # Kubernetes 資源模板
│   ├── deployment.yaml     # Netbox Deployment
│   ├── service.yaml        # Service 配置
│   ├── configmap.yaml      # 配置文件
│   ├── secret.yaml         # 敏感信息
│   ├── ingress.yaml        # Ingress 配置
│   └── statefulset.yaml    # PostgreSQL StatefulSet
└── README.md               # 使用文檔
```

## Values.yaml 核心配置項

### 第 1 部分：Netbox 應用配置

```yaml
# Netbox 副本數
replicaCount: 3

# Netbox 容器鏡像
image:
  repository: netboxcommunity/netbox
  tag: "latest"
  pullPolicy: IfNotPresent

# 資源限制
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Pod 健康檢查
readinessProbe:
  enabled: true
  path: /api/version/
  initialDelaySeconds: 30
  periodSeconds: 10

livenessProbe:
  enabled: true
  path: /api/version/
  initialDelaySeconds: 120
  periodSeconds: 10
```

### 第 2 部分：PostgreSQL 數據庫配置

```yaml
postgresql:
  enabled: true
  
  # PostgreSQL StatefulSet 副本數
  replicaCount: 3
  
  # Primary 副本配置
  primary:
    persistence:
      enabled: true
      size: 10Gi  # 數據庫磁盤大小
      storageClassName: local-path  # K3s 默認存儲類
  
  # PostgreSQL 容器資源
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  
  # 數據庫名稱、用戶、密碼
  auth:
    username: netbox
    password: netbox  # 實際部署時應改為強密碼
    database: netbox
```

### 第 3 部分：Redis 緩存配置

```yaml
redis:
  enabled: true
  
  # Redis 副本數
  replica:
    replicaCount: 2  # 1 primary + 2 replicas
  
  # Redis 持久化
  persistence:
    enabled: false  # 會話丟失時會重新登錄，通常不需要持久化
  
  # Redis 資源限制
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  
  # Redis 認證
  auth:
    enabled: true
    password: redis-password
```

### 第 4 部分：Service 和 Ingress

```yaml
# Service 配置
service:
  type: ClusterIP  # 或 NodePort
  port: 80
  targetPort: 8001

# Ingress 配置（用於外部訪問）
ingress:
  enabled: false  # 如果要外部訪問，改為 true
  className: nginx
  hosts:
    - host: netbox.example.com
      paths:
        - path: /
          pathType: Prefix
```

## 部署流程圖

```
1. Helm 命令
   ▼
helm install netbox netbox-chart/

   ▼
2. Helm 解析 values.yaml

   ▼
3. 模板渲染（templates/ 文件）

   ▼
4. 生成 Kubernetes 資源
   ├── Deployment (Netbox)
   ├── StatefulSet (PostgreSQL)
   ├── StatefulSet (Redis)
   ├── Services
   ├── ConfigMap
   ├── Secrets
   └── PersistentVolumeClaim

   ▼
5. 提交到 Kubernetes API Server

   ▼
6. Kubernetes 調度和部署
   ├── 創建 Pod
   ├── 分配資源
   ├── 綁定 PVC
   └── 啟動容器

   ▼
7. Pod 就緒並監聽連接
```

## 重要配置決策表

| 配置項 | 選項 | 優勢 | 劣勢 | 建議 |
|------|------|------|------|------|
| replicaCount | 1 / 3 / 5 | 1: 簡單 / 3+: 高可用 | 1: 無故障轉移 / 3+: 資源多 | 3 (平衡) |
| PostgreSQL 副本 | 1 / 3 | 1: 簡單 / 3: 高可用 | 1: 無備份 / 3: 複雜 | 3 (生產) |
| Redis 持久化 | true / false | true: 數據保留 | true: 性能下降 | false (會話可重建) |
| Service 類型 | ClusterIP / NodePort | ClusterIP: 安全 / NodePort: 外部可訪問 | ClusterIP: 需 port-forward | NodePort (開發) |
| 存儲大小 | 10Gi / 50Gi / 100Gi | 取決於數據量 | 超大會影響性能 | 初期 10Gi |

## 自訂 values.yaml 步驟

### 步驟 1：下載官方 Chart

```bash
# 添加官方 Helm repository
helm repo add netbox-community https://github.com/netbox-community/helm-charts

# 更新 repo
helm repo update

# 拉取 chart
helm pull netbox-community/netbox --untar
```

### 步驟 2：檢查默認值

```bash
cat netbox/values.yaml | head -50
```

### 步驟 3：創建自訂配置文件

```bash
# 創建 my-values.yaml
cat > my-values.yaml << EOF
replicaCount: 3

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

postgresql:
  enabled: true
  primary:
    persistence:
      size: 20Gi

redis:
  enabled: true
  auth:
    password: your-strong-password
EOF
```

### 步驟 4：驗證配置

```bash
# 模擬部署（不實際部署）
helm install netbox netbox/ -f my-values.yaml --dry-run --debug
```

## 下一步

閱讀 [deployment-steps.md](./deployment-steps.md) 學習實際部署步驟。
