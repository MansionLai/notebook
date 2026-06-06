---
title: 配置參考表
parent: Netbox
nav_order: 5
---

# 配置參考表

> **Profile 標籤**
> - **Azure VM K3s profile**：Azure VM 叢集請以 [`deployment-steps.md`](./deployment-steps.md) 的精簡 values 為基準。  
> - **HA/production profile**：本文件多數默認值與生產配置段落（如副本與資源建議）偏向 HA/production 參考。  
> ⚠️ Azure VM 規格較小時，必須使用 `deployment-steps.md` 的降配值，不可混用 HA 預設。

本文檔提供 NetBox、PostgreSQL 和 Redis 的完整配置項速查表，方便向同事介紹或調整部署。

## NetBox 配置參考

### 應用級別配置

| 配置項 | 默認值 | 說明 | 示例 |
|------|--------|------|------|
| `replicaCount` | 3 | Netbox pod 副本數 | 3, 5, 10 |
| `image.repository` | netboxcommunity/netbox | 容器鏡像倉庫 | 自訂倉庫 |
| `image.tag` | latest | 版本標籤 | v3.4.0, v3.5.0 |
| `image.pullPolicy` | IfNotPresent | 鏡像拉取策略 | Always, Never |

### 資源配置

| 配置項 | 限制 | 請求 | 說明 |
|------|------|------|------|
| CPU | 1000m | 500m | 單核=1000m |
| 內存 | 2Gi | 1Gi | 1GB=1Gi |

**調整建議：**
- 開發環境：CPU 1000m, Memory 1Gi (建議 2Gi 以確保遷移順利)
- 生產環境（小規模）：CPU 1000m, Memory 2Gi
- 生產環境（大規模）：CPU 2000m, Memory 4Gi

### 健康檢查配置

| 檢查類型 | 參數 | 默認值 | 說明 |
|---------|------|--------|------|
| Readiness | initialDelaySeconds | 30 | pod 啟動後等待時間 |
| Readiness | periodSeconds | 10 | 檢查周期 |
| Liveness | initialDelaySeconds | 120 | pod 啟動後等待時間 |
| Liveness | periodSeconds | 10 | 檢查周期 |

### NetBox 管理員帳號

| 項目 | 說明 |
|------|------|
| `admin` 初始密碼 | 官方 OCI chart 可用 `superuser.password` 在 install 時設定 |
| 建立方式 | 使用官方 OCI chart 的 `superuser.password` / `superuser.apiToken`，或部署後執行 `python manage.py createsuperuser` |
| 重設方式 | `python manage.py changepassword <username>` |
| 已知限制 | 本地 `netbox-values.yaml` 只管理 PostgreSQL / Redis 等基礎服務認證 |
| 其他說明 | 若使用本地 chart/fork，需自行確認是否支援 `superuser.*` 參數 |

## PostgreSQL 配置參考

### 部署配置

| 配置項 | 默認值 | 說明 |
|------|--------|------|
| `enabled` | true | 是否啟用 PostgreSQL chart |
| `replicaCount` | 3 | PostgreSQL StatefulSet 副本數 |
| `primary.persistence.size` | 10Gi | 數據庫存儲大小 |
| `primary.persistence.enabled` | true | 是否啟用持久化存儲 |
| `primary.persistence.storageClassName` | local-path | Azure VM 上的 K3s local-path 存儲類 |

### 認證配置

| 配置項 | 默認值 | 說明 |
|------|--------|------|
| `auth.username` | netbox | 數據庫用戶名 |
| `auth.password` | netbox | 數據庫密碼（應改為強密碼） |
| `auth.database` | netbox | 數據庫名稱 |

### 資源配置

| 資源 | 限制 | 請求 | 說明 |
|------|------|------|------|
| CPU | 1000m | 500m | PostgreSQL 進程 |
| Memory | 1Gi | 512Mi | 內存緩衝 |

**PostgreSQL 特定參數：**

```yaml
postgresql:
  parameters:
    shared_buffers: 256MB  # 共享內存緩衝
    effective_cache_size: 1GB  # 有效緩存大小
    work_mem: 16MB  # 排序和雜湊表大小
    maintenance_work_mem: 64MB  # VACUUM 等維護操作
```

### 備份配置

```yaml
# 自動備份（可選）
backup:
  enabled: true
  schedule: "0 2 * * *"  # 每天凌晨 2 點
  retention: 7  # 保留 7 天
```

## Redis 配置參考

### 部署配置

| 配置項 | 默認值 | 說明 |
|------|--------|------|
| `enabled` | true | 是否啟用 Redis chart |
| `replica.replicaCount` | 2 | Redis 從節點副本數 |
| `persistence.enabled` | false | 是否啟用 RDB 持久化 |

### 認證配置

| 配置項 | 默認值 | 說明 |
|------|--------|------|
| `auth.enabled` | true | 是否啟用密碼認證 |
| `auth.password` | (empty) | Redis 密碼 |

### 資源配置

| 資源 | 限制 | 請求 | 說明 |
|------|------|------|------|
| CPU | 500m | 250m | Redis 進程 |
| Memory | 512Mi | 256Mi | 內存存儲 |

**Redis 特定參數：**

```yaml
redis:
  appendonly: no  # AOF 持久化（通常關閉）
  maxmemory-policy: allkeys-lru  # 內存淘汰策略
  timeout: 0  # 客戶端超時時間（0=禁用）
```

## Service 和 Ingress 配置

### Service 配置

```yaml
service:
  type: ClusterIP  # ClusterIP, NodePort, LoadBalancer
  port: 80  # Service 端口
  targetPort: 8001  # 容器端口
  annotations: {}  # 額外的 service 注解
```

### Ingress 配置

```yaml
ingress:
  enabled: false
  className: nginx  # Ingress 控制器類
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: netbox.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: netbox-tls
      hosts:
        - netbox.example.com
```

## 環境變數配置

NetBox 支持通過環境變數配置，在 ConfigMap 中設置：

```yaml
env:
  NETBOX_ALLOWED_HOSTS: '*'
  NETBOX_CSRF_TRUSTED_ORIGINS: 'http://localhost:8080'
  NETBOX_DEBUG: 'False'
  NETBOX_MAX_PAGE_SIZE: '1000'
  NETBOX_PAGINATE_COUNT: '50'
  NETBOX_LOG_LEVEL: 'INFO'
```

## 數據庫連接字符串示例

### PostgreSQL

```
PostgreSQL://netbox:netbox@postgresql:5432/netbox
```

### Redis

```
redis://:redis-password@redis-master-0:6379/0
```

## 重要配置組合推薦

### 開發環境配置

```yaml
replicaCount: 1
postgresql:
  replicaCount: 1
redis:
  replica:
    replicaCount: 0
```

### 測試環境配置

```yaml
replicaCount: 2
postgresql:
  replicaCount: 2
redis:
  replica:
    replicaCount: 1
```

### 生產環境配置

```yaml
replicaCount: 3
postgresql:
  replicaCount: 3
redis:
  replica:
    replicaCount: 2
  auth:
    password: (strong password)
```

## 快速查詢命令

```bash
# 查看當前部署的 values
helm get values netbox -n netbox

# 查看部署的完整 manifest
helm get manifest netbox -n netbox | grep -A 10 "kind: Deployment"

# 查看 ConfigMap 內容
kubectl get cm netbox-config -n netbox -o yaml

# 查看 Secrets
kubectl get secrets -n netbox
```

## 下一步

閱讀 [troubleshooting.md](./troubleshooting.md) 了解常見問題和解決方案。
