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

## 第 3 步：配置本地 Values 檔案

您可以直接修改 `netbox/values.yaml` 中的預設值。請使用編輯器（如 `vi` 或 `nano`）搜尋並修改以下關鍵配置：

```bash
vi netbox/values.yaml
```

### 關鍵修改清單：

| 項目 | 搜尋關鍵字 | 建議設定值 | 說明 |
| :--- | :--- | :--- | :--- |
| **超級管理員** | `superuser:` | `existingSecret: "netbox-superuser"` | 引用 Step 2 建立的 Secret |
| **NetBox 記憶體** | 第一個 `resources:` | `memory: 2Gi` | 核心 Web 服務，Migration 需較大記憶體 |
| **Worker 記憶體** | `worker:` 下的 `resources:` | `memory: 1Gi` | 背景任務（如 Webhooks）所需記憶體 |
| **資料庫記憶體** | `postgresql:` 下的 `resources:` | `memory: 1Gi` | PostgreSQL 資料庫核心記憶體 |
| **Redis 記憶體** | `redis:` 下的 `resources:` | `memory: 512Mi` | Redis 快取層所需記憶體 |
| **資料庫儲存類** | `postgresql:` 下的 `storageClassName:` | `"local-path"` | K3s 預設儲存類 |
| **資料庫大小** | `postgresql:` 下的 `size:` | `5Gi` | 測試環境建議值 |

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
# redis-master-0                1/1     Running   0          3m
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
