---
title: 完整部署步驟
parent: Netbox
nav_order: 3
---

# 完整部署步驟

## 概述

本文檔提供在 Azure VM K3s 叢集上逐步部署 NetBox 的完整指南，包括所有前置準備和驗證步驟。

## NetBox Helm Chart 結構

官方 Netbox Helm chart 地址：https://github.com/netbox-community/helm-charts

### 目錄結構

```
netbox/
├── Chart.yaml              # Chart 元數據
├── values.yaml             # 默認配置值（最重要）
├── charts/                 # 依賴 chart
│   ├── postgresql/         # PostgreSQL chart
│   └── valkey/             # Valkey chart (取代 Redis)
├── templates/              # Kubernetes 資源模板
└── README.md               # 使用文檔
```

## 第 1 步：添加 Helm Repository 並拉取 Chart

```bash
# 添加官方 NetBox Helm repo
helm repo add netbox https://charts.netbox.oss.netboxlabs.com/
helm repo update

# 拉取官方原始碼至本地進行修改
helm pull netbox/netbox --untar
```

## 第 2 步：創建命名空間與 Secret

### 2.1 產生 API Token
NetBox 的 API Token 有嚴格的長度與格式限制：
*   **長度**：必須至少 **40 個字元**。
*   **格式**：僅限 **十六進位 (Hexadecimal)** 字元 (`0-9`, `a-f`)。

建議使用 `openssl` 產生一個隨機 Token：
```bash
# 產生 40 個字元的隨機 Hex 字串
openssl rand -hex 20
```

### 2.2 建立命名空間與 Secret
> ⚠️ **重要：Secret 欄位限制**
> 當使用 `existingSecret` 時，NetBox Chart **強制要求** Secret 中必須包含以下四個 Key，缺少任何一個都會導致 Pod 啟動失敗：
> 1. `username`: 管理員帳號
> 2. `email`: 管理員信箱
> 3. `password`: 管理員密碼
> 4. `api_token`: 40 字元 Hex Token (小寫底線)

```bash
# 創建專用命名空間
kubectl create namespace netbox

# 建立完整的 Superuser 憑證 Secret
kubectl create secret generic netbox-superuser \
  --from-literal=username='admin' \
  --from-literal=email='admin@example.com' \
  --from-literal=password='您的自訂密碼' \
  --from-literal=api_token='您的40字元Token' \
  -n netbox
```

## 第 3 步：配置本地 Values 檔案

您可以直接修改 `netbox/values.yaml` 中的預設值。請使用編輯器（如 `vi` 或 `nano`）搜尋並替換以下關鍵配置：

```bash
vi netbox/values.yaml
```

### 3.1 超級管理員
請搜尋關鍵字並修改：
*   **搜尋 `superuser:`**：將 `existingSecret` 設為 `"netbox-superuser"`。

### 3.2 組件資源、副本數與存儲設定 (需手動新增/替換)
> ⚠️ **重要提醒**：當 `replicaCount > 1` 時，若 Pod 分散在不同節點，必須使用 **ReadWriteMany (RWX)** 類型的儲存（如 Azure File 或 NFS）才能共享 Media 檔案。本實驗使用 `local-path` (RWO)，副本數設為 2 可能導致磁碟掛載衝突或資料不一致。

#### 1. NetBox 核心 (搜尋第一個 `replicaCount:` 與 `resources: {}`)
```yaml
replicaCount: 2
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi
```

#### 2. NetBox Worker (搜尋 `worker:` 下的 `replicaCount:` 與 `resources: {}`)
```yaml
worker:
  replicaCount: 2
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
```

#### 3. PostgreSQL (搜尋 `postgresql:`，新增 `architecture`、`primary` 與 `readReplicas` 區塊)
```yaml
postgresql:
  enabled: true
  # 必須設定為 replication 才能啟動多個 Pod
  architecture: "replication"
  auth:
    username: netbox
    database: netbox
  primary:
    persistence:
      enabled: true
      storageClassName: "local-path"
      size: 5Gi
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
  readReplicas:
    # 設定為 1 會產生 1 個 Replica Pod (加上 Primary 總共 2 個)
    replicaCount: 1
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
```

#### 4. Valkey (搜尋 `valkey:`，新增 `primary` 區塊與 `replicaCount`)
```yaml
valkey:
  enabled: true
  primary:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 200m
        memory: 512Mi
  replica:
    # 設定為 1 會產生 1 Primary + 1 Replica = 2 Pods
    replicaCount: 1 
```



## 第 4 步：驗證配置（Dry Run）

```bash
# 指向本地 ./netbox 資料夾進行模擬部署
helm install netbox ./netbox \
  -n netbox \
  --dry-run --debug
```

## 第 5 步：執行實際部署

```bash
# 部署 NetBox 及其依賴
helm install netbox ./netbox \
  -n netbox

# 等待 3-5 分鐘讓 pod 啟動（初次部署會執行資料庫 Migration，需較長時間）
kubectl get pods -n netbox -w
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
# valkey-primary-0              1/1     Running   0          3m
```

### 步驟 6.2：詳細檢查 Pod 詳情

```bash
# 查看某個 pod 詳情
kubectl describe pod netbox-xxx -n netbox

# 查看 pod 日誌
kubectl logs netbox-xxx -n netbox
```

### 步驟 6.3：檢查 PostgreSQL 連接

```bash
# 進入 PostgreSQL pod
kubectl exec -it postgresql-0 -n netbox -- bash

# 在 pod 內連接數據庫 (密碼預設為 netbox)
psql -U netbox -d netbox

# 驗證數據庫
\l  # 列出所有數據庫
\dt  # 列出所有表

# 退出
exit
```

### 步驟 6.4：檢查 Valkey 連接

```bash
# 進入 Valkey pod
kubectl exec -it valkey-primary-0 -n netbox -- valkey-cli

# 檢查服務狀態
INFO server
DBSIZE  # 查看存儲的 key 數量

# 退出
exit
```

## 第 7 步：配置外部訪問

### 使用 Port Forward 直接對外開放

如果要從瀏覽器直接打 `http://<VM-Public-IP>:8080`，請先在 Azure NSG 放行 `8080`，然後用：

```bash
kubectl port-forward --address 0.0.0.0 svc/netbox 8080:80 -n netbox
```

## 第 8 步：初始化與維護

### 手動重設管理員密碼

如果您需要手動修改密碼：

```bash
# 找到一個 NetBox pod
NETBOX_POD=$(kubectl get pod -n netbox -l app.kubernetes.io/name=netbox -o jsonpath='{.items[0].metadata.name}')

# 在 pod 中執行密碼修改
kubectl exec -it $NETBOX_POD -n netbox -- \
  python manage.py changepassword admin
```

## 故障排查

### 資源不足 (OOMKilled)
如果 Netbox Pod 一直重啟且狀態顯示為 `OOMKilled`，代表 `values.yaml` 中的 `memory` 給得不夠。
*   檢查 `netbox/values.yaml` 中的 `resources.limits.memory` 是否已設為 `2Gi`。
*   修改後執行 `helm upgrade netbox ./netbox -n netbox`。
