---
title: Phase 4 - Observability
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 14
permalink: /kubernetes/3node-kubevirt/phase-4/
---

# Phase 4 — Observability

## 範圍

本頁整合原本的 `Phase 4a`、`Phase 4b`、`Phase 4c`，因為三者都屬於 observability / logging stack。

## Phase 4a：Prometheus Stack（kube-prometheus-stack）

> 在 **mansion-kubevirt-master** 執行

**目的：** 安裝 kube-prometheus-stack（Prometheus + AlertManager + Grafana + node-exporter + kube-state-metrics），提供完整的叢集監控能力。所有元件釘在 infra node，node-exporter 以 DaemonSet 部署到三台 node。

### Step 4a-1：新增 Helm repo

> 新增 Prometheus Community Helm repo，包含 kube-prometheus-stack chart。

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### Step 4a-2：建立 values 檔

> 各元件透過 `nodeSelector: role: infra` 釘在 infra node。
> infra node 有 NoSchedule taint，因此需加 toleration。
> node-exporter 需加 control-plane toleration 才能部署到 master。
> Prometheus 使用 ceph-rbd SC 建立 10Gi PVC 保存 7 天 metrics。

```bash
cat > /tmp/prometheus-values.yaml <<'EOF'
prometheus:
  prometheusSpec:
    nodeSelector:
      role: infra
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"
    retention: 7d
    # 讓 Prometheus 選取所有 namespace 的 ServiceMonitor/Rule（含 KubeVirt 等第三方）
    serviceMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ceph-rbd
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    resources:
      requests:
        memory: 512Mi
        cpu: 200m
      limits:
        memory: 1Gi
        cpu: 500m

alertmanager:
  alertmanagerSpec:
    nodeSelector:
      role: infra
    tolerations:
      - key: "node-role.kubernetes.io/infra"
        operator: "Exists"
        effect: "NoSchedule"

grafana:
  nodeSelector:
    role: infra
  tolerations:
    - key: "node-role.kubernetes.io/infra"
      operator: "Exists"
      effect: "NoSchedule"
  resources:
    requests:
      memory: 128Mi
    limits:
      memory: 256Mi

prometheusOperator:
  nodeSelector:
    role: infra
  tolerations:
    - key: "node-role.kubernetes.io/infra"
      operator: "Exists"
      effect: "NoSchedule"

kube-state-metrics:
  nodeSelector:
    role: infra
  tolerations:
    - key: "node-role.kubernetes.io/infra"
      operator: "Exists"
      effect: "NoSchedule"

prometheus-node-exporter:
  # DaemonSet，部署到所有 node
  tolerations:
    - key: "node-role.kubernetes.io/control-plane"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "node-role.kubernetes.io/infra"
      operator: "Exists"
      effect: "NoSchedule"
EOF
```

### Step 4a-3：建立 monitoring namespace

```bash
kubectl create namespace monitoring
```

### Step 4a-4：安裝

> 如果 monitoring namespace 尚未建立，請先建立（或執行上一步）。

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f /tmp/prometheus-values.yaml
```

### Step 4a-5：驗證

> 確認所有元件在 infra node，node-exporter 在三台 node 各一個。

```bash
kubectl get pods -n monitoring -o wide
# 預期：prometheus-*, alertmanager-*, grafana-*, kube-state-metrics-* 在 mansion-kubevirt-infra
#        node-exporter-* 在三台 node 各一個（master/infra/worker）

kubectl get pvc -n monitoring
# 預期：prometheus-kube-prometheus-stack-prometheus-db-... Bound 10Gi
```

---

## Phase 4b：OpenSearch + OpenSearch Dashboards

> 在 **mansion-kubevirt-master** 執行

**目的：** 安裝 OpenSearch（Elasticsearch 相容的搜尋/分析引擎）和 OpenSearch Dashboards（Kibana 相容的視覺化 UI），用於收集和查詢 Fluent Bit 轉送的 log。Single-node 模式，釘在 infra node。

### Step 4b-1：新增 Helm repo

> 新增 OpenSearch 官方 Helm repo。

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update
```

### Step 4b-2：建立 OpenSearch values

> `singleNode: true` 關閉 cluster 模式，適合 lab 環境節省資源。
> infra node 無 taint，不需要 toleration。
> JVM heap 設 512m（與 memory limit 1Gi 搭配，留空間給 OS）。

> **⚠️ OpenSearch 2.12+ 強制要求設定 `OPENSEARCH_INITIAL_ADMIN_PASSWORD`，密碼需符合強度規則（大小寫＋數字＋特殊符號，且不得與 username 相似）。**
> 建議使用 Python 產生 values 檔以避免 heredoc YAML 格式問題：

```bash
python3 -c "
import yaml
vals = {
    'singleNode': True,
    'nodeSelector': {'role': 'infra'},
    'tolerations': [
        {'key': 'node-role.kubernetes.io/infra', 'operator': 'Exists', 'effect': 'NoSchedule'}
    ],
    'resources': {
        'requests': {'memory': '512Mi', 'cpu': '200m'},
        'limits': {'memory': '1Gi', 'cpu': '500m'}
    },
    'opensearchJavaOpts': '-Xmx512m -Xms512m',
    'persistence': {
        'enabled': True,
        'storageClass': 'ceph-rbd',
        'size': '10Gi'
    },
    'config': {
        'opensearch.yml': 'cluster.name: k8s-lab\nnetwork.host: 0.0.0.0\ndiscovery.type: single-node\n'
    },
    'extraEnvs': [
        {'name': 'OPENSEARCH_INITIAL_ADMIN_PASSWORD', 'value': 'Qr7!pZ9vNw#'}
    ]
}
with open('/tmp/opensearch-values.yaml', 'w') as f:
    yaml.dump(vals, f, default_flow_style=False)
print('Done')
"
```

### Step 4b-3：安裝 OpenSearch

> 安裝到 monitoring namespace，與 Prometheus stack 共用同一個 namespace。

```bash
helm install opensearch opensearch/opensearch \
  -n monitoring \
  -f /tmp/opensearch-values.yaml
```

### Step 4b-4：建立 OpenSearch Dashboards values

> Dashboards 連線到 OpenSearch cluster master service（9200 port）。
> 需加 toleration 以部署到 infra node。

```bash
cat > /tmp/opensearch-dashboards-values.yaml <<'EOF'
nodeSelector:
  role: infra

tolerations:
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"

resources:
  requests:
    memory: 256Mi
  limits:
    memory: 512Mi

opensearchHosts: "https://opensearch-cluster-master:9200"
EOF
```

### Step 4b-5：安裝 OpenSearch Dashboards

```bash
helm install opensearch-dashboards opensearch/opensearch-dashboards \
  -n monitoring \
  -f /tmp/opensearch-dashboards-values.yaml
```

### Step 4b-6：驗證

> 確認 OpenSearch 和 Dashboards 都在 infra node，PVC 10Gi Bound。

```bash
kubectl get pods -n monitoring -o wide | grep opensearch
# 預期：opensearch-cluster-master-0 和 opensearch-dashboards-* 在 mansion-kubevirt-infra

kubectl get pvc -n monitoring | grep opensearch
# 預期：opensearch-cluster-master-... Bound 10Gi ceph-rbd
```

---

## Phase 4c：Fluent Bit

> 在 **mansion-kubevirt-master** 執行

### Step 4c-1：新增 Helm repo

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

### Step 4c-2：確認 OpenSearch admin 密碼

> 帳號：`admin`，密碼：安裝時透過 `OPENSEARCH_INITIAL_ADMIN_PASSWORD` env 設定的值（`Qr7!pZ9vNw#`）。

```bash
# 確認 opensearch-cluster-master service 可連線
kubectl exec -n monitoring opensearch-cluster-master-0 -- \
  curl -sk -u "admin:Qr7!pZ9vNw#" "https://localhost:9200/_cluster/health?pretty"
```

### Step 4c-3：建立 Fluent Bit values

> **注意事項：**
> - OpenSearch 2.x 移除了 `_type` 欄位，必須加 `Suppress_Type_Name On`，否則 HTTP 400。
> - 使用單引號 heredoc delimiter 避免 shell 展開。

```bash
cat > /tmp/fluent-bit-values.yaml << 'HEREDOC'
tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
  - key: "node-role.kubernetes.io/infra"
    operator: "Exists"
    effect: "NoSchedule"

config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        multiline.parser  docker, cri
        Tag               kube.*
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

  outputs: |
    [OUTPUT]
        Name              opensearch
        Match             kube.*
        Host              opensearch-cluster-master.monitoring.svc.cluster.local
        Port              9200
        HTTP_User         admin
        HTTP_Passwd       Qr7!pZ9vNw#
        Logstash_Format   On
        Logstash_Prefix   k8s-logs
        Replace_Dots      On
        Suppress_Type_Name On
        Retry_Limit       False
        tls               On
        tls.verify        Off
HEREDOC
```

### Step 4c-4：安裝

```bash
helm install fluent-bit fluent/fluent-bit \
  -n monitoring \
  -f /tmp/fluent-bit-values.yaml
```

### Step 4c-5：驗證

```bash
kubectl get pods -n monitoring -o wide | grep fluent
# 預期：fluent-bit-* 在三台 node 各一個（DaemonSet）

kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --since=15s 2>&1 | grep -v 'inotify_fs_add\| info'
# 預期：無任何 error（無 401/400/connection refused）

# 確認 OpenSearch index 已建立
kubectl exec -n monitoring opensearch-cluster-master-0 -- \
  bash -c 'curl -sk -u admin:"$OPENSEARCH_INITIAL_ADMIN_PASSWORD" https://localhost:9200/_cat/indices?v' | grep k8s
# 預期：k8s-logs-YYYY.MM.DD index，status yellow（single-node 無 replica），有 doc count
```

---

## 踩坑記錄（Phase 4）

| 問題 | 原因 | 解法 |
|------|------|------|
| Prometheus / OpenSearch 卡在 `Init` 或 `MountDevice failed`，訊息含 `driver name rook-ceph.rbd.csi.ceph.com not found` | Ceph RBD node plugin 沒有在 infra 節點註冊（`csi-rbdplugin` 未覆蓋到 infra/control-plane） | patch `rook-ceph/csi-rbdplugin` DaemonSet 加上 infra/control-plane toleration，確認 3 節點都有 `csi-rbdplugin` 後再重建 stateful pod |
| OpenSearch 啟動探針短時間 `connection refused` | JVM/插件初始化需要時間，啟動期較長 | 先確認 PVC 已 Bound 與 CSI 正常，再用 condition wait 等待 pod Ready，避免用固定 sleep 判斷失敗 |

### 參考修復指令

```bash
# 讓 rbd node plugin 能跑在 infra/control-plane
kubectl patch daemonset csi-rbdplugin -n rook-ceph --type merge -p '{
  "spec": {
    "template": {
      "spec": {
        "tolerations": [
          {"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"},
          {"key":"node-role.kubernetes.io/infra","operator":"Exists","effect":"NoSchedule"}
        ]
      }
    }
  }
}'

# 重建 Stateful Pod
kubectl delete pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 --force --grace-period=0
kubectl delete pod -n monitoring opensearch-cluster-master-0 --force --grace-period=0
```

---
