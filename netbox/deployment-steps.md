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
```bash
# 創建專用命名空間
kubectl create namespace netbox

# 建立 Superuser 憑證 Secret
# 將下方 '您的自訂Token' 替換為剛才產生的 40 字元字串
kubectl create secret generic netbox-superuser \
  --from-literal=password='您的自訂密碼' \
  --from-literal=apiToken='您的自訂Token' \
  -n netbox
```

### 重新練習時的 Rollback 到 Step 2

如果你已經做完 step3~step5、想回到只有叢集和 namespace 的狀態：

```bash
# 移除 Helm release
helm -n netbox uninstall netbox

# 移除 Secret
kubectl delete secret netbox-superuser -n netbox

# 如果你也想清掉 step3 產生的本地檔案
rm -rf netbox/
rm -f netbox-values.yaml
```

## 第 3 步：準備 Values 配置文件

```bash
# 拉取官方 chart 以查看默認值 (僅作參考)
helm pull netbox/netbox --untar

# 創建自訂 values 文件
cat > netbox-values.yaml << 'EOF'
# Superuser 配置 (引用預先建立的 Secret)
superuser:
  name: admin
  email: admin@example.com
  existingSecret: netbox-superuser

# NetBox 副本數
replicaCount: 1

# Netbox 容器資源
resources:
  limits:
    cpu: 1000m
    memory: 2Gi # 提高內存以防止 Migration 時 OOM
  requests:
    cpu: 500m
    memory: 1Gi

# PostgreSQL 配置
postgresql:
  enabled: true
  architecture: standalone
  primary:
    persistence:
      enabled: true
      size: 5Gi
      storageClassName: local-path
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
helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
  -n netbox \
  -f netbox-values.yaml \
  --dry-run --debug
```

## 第 5 步：執行實際部署

```bash
# 部署 NetBox 及其依賴
helm install netbox oci://ghcr.io/netbox-community/netbox-chart/netbox \
  -n netbox \
  -f netbox-values.yaml

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

## 第 8 步：初始化 Netbox（可選，若已在 Step 2 建立 Secret 則跳過）

如果您在 Step 2 & 3 已經使用了 `existingSecret`，NetBox 在啟動時會自動建立該管理員帳號。

### 如果需要手動重設密碼：

```bash
# 找到一個 NetBox pod
NETBOX_POD=$(kubectl get pod -n netbox -l app.kubernetes.io/name=netbox -o jsonpath='{.items[0].metadata.name}')

# 在 pod 中執行密碼修改
kubectl exec -it $NETBOX_POD -n netbox -- \
  python manage.py changepassword admin
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
```

## 故障排查常見命令

### 資源不足排查（優先順序）

1. **內存不足 (OOMKilled)**：Netbox 在執行 `manage.py migrate` 時非常消耗內存，建議限制至少設為 `2Gi` 以確保 成功。
2. 檢查 netbox-worker 的記憶體使用量是否過高。

```bash
# 查看部署狀態
kubectl get deployment -n netbox

# 清理部署（如需重新開始）
helm uninstall netbox -n netbox
```
