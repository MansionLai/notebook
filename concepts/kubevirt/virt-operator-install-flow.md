# KubeVirt v1.5.0 — virt-operator 安裝流程與元件建立機制

> 建立日期：2026-04-15  
> 分類：concepts/kubevirt  
> 版本：KubeVirt v1.5.0

---

## 概述

KubeVirt 採用 Operator Pattern 安裝。安裝分兩步：先 apply operator（含 CRD），再 apply KubeVirt CR。virt-operator 監聽 KubeVirt CR 後，自動建立 virt-api、virt-controller、virt-handler，並視叢集是否有 Prometheus Operator 來決定是否建立 ServiceMonitor 與 PrometheusRule。

---

## 安裝順序

```bash
# Step 1：安裝 operator（含 CRD、RBAC、virt-operator Deployment）
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.5.0/kubevirt-operator.yaml

# Step 2：等 virt-operator Running 後，apply KubeVirt CR
kubectl wait -n kubevirt deployment/virt-operator --for=condition=Available --timeout=2m
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.5.0/kubevirt-cr.yaml

# Step 3：等待完全部署完成
kubectl wait kv kubevirt -n kubevirt --for=condition=Available --timeout=10m
```

> ⚠️ 不能反過來。`kind: KubeVirt` CR 依賴 kubevirt-operator.yaml 裡安裝的 CRD，若先 apply CR 會報錯：`no kind "KubeVirt" is registered`

---

## virt-operator 元件建立流程圖

```mermaid
flowchart TD
    A([kubectl apply kubevirt-operator.yaml]) --> B[建立 Namespace: kubevirt]
    B --> C[安裝 CRDs\nKubeVirt / VirtualMachine /\nVirtualMachineInstance 等 20+ CRDs]
    C --> D[建立 RBAC\nClusterRole / ClusterRoleBinding /\nServiceAccount]
    D --> E[部署 virt-operator Deployment\n由 K8s scheduler 排程]
    E --> F([kubectl apply kubevirt-cr.yaml\nkind: KubeVirt CR])
    F --> G{virt-operator\nWatch KubeVirt CR\nReconcile Loop 啟動}
    G --> H[Phase: Deploying]
    H --> I1[建立 virt-api Deployment\n2 replicas · port 8443\nWebhook + REST API]
    H --> I2[建立 virt-controller Deployment\n2 replicas\n管理 VM 狀態機]
    H --> I3[建立 virt-handler DaemonSet\n每個 node 一個\n直接存取 /dev/kvm]
    I1 & I2 & I3 --> J[等待各元件 Ready\nreadiness probe 通過]
    J --> K{檢查 Prometheus Operator CRD\nservicemonitors.monitoring.coreos.com\n是否存在？}
    K -->|CRD 存在| L1[建立 ServiceMonitor x4\nvirt-api / virt-controller\nvirt-operator / virt-handler]
    K -->|CRD 存在| L2[建立 PrometheusRule\nKubeVirt alerting rules\n約 15 條告警]
    K -->|CRD 不存在| L3[跳過監控元件\n靜默略過，不報錯]
    L1 & L2 --> M[建立 kubevirt-prometheus-rule ConfigMap]
    L3 --> N
    M --> N([Phase: Deployed\nKubeVirt CR status.phase = Deployed])
```

---

## 元件建立順序說明

### Stage 1：kubevirt-operator.yaml 包含

| 資源 | 說明 |
|------|------|
| Namespace `kubevirt` | 所有 KubeVirt 元件的命名空間 |
| 20+ CRDs | VirtualMachine、VirtualMachineInstance、KubeVirt、DataVolume 等 |
| ClusterRole / ClusterRoleBinding | virt-operator 的 RBAC 權限 |
| ServiceAccount | virt-operator 身份 |
| Deployment `virt-operator` | Operator 本體，啟動後開始監聽 KubeVirt CR |

### Stage 2：apply KubeVirt CR 後，virt-operator reconcile 建立

| 元件 | 類型 | replicas | 功能 |
|------|------|----------|------|
| `virt-api` | Deployment | 2 | 處理 VM/VMI REST API 請求、Webhook |
| `virt-controller` | Deployment | 2 | 管理 VM 生命週期狀態機 |
| `virt-handler` | DaemonSet | 每 node 1 | Node-level KVM agent，直接存取 /dev/kvm |
| `virt-exportproxy` | Deployment | 1 | VM disk export 功能（v1.x 新增）|
| `ServiceMonitor` × 4 | 監控資源 | — | 條件建立（見下節）|
| `PrometheusRule` | 監控資源 | — | 條件建立（見下節）|

---

## ServiceMonitor & PrometheusRule 條件建立機制

### 判斷邏輯

virt-operator 在 reconcile loop 中，呼叫 `IsPrometheusDeployed()` 函式：

```go
// pkg/virt-operator/resource/generate/components/prometheus.go
func IsPrometheusDeployed(clientset kubecli.KubevirtClient) (bool, error) {
    _, err := clientset.ExtensionsClient().
        ApiextensionsV1().CustomResourceDefinitions().
        Get(context.Background(),
            "servicemonitors.monitoring.coreos.com",
            metav1.GetOptions{})
    if errors.IsNotFound(err) {
        return false, nil   // Prometheus Operator 未安裝 → 跳過
    }
    return err == nil, err  // CRD 存在 → 建立監控資源
}
```

| 情境 | CRD 是否存在 | 行為 |
|------|-------------|------|
| 有安裝 `kube-prometheus-stack` | ✅ | 自動建立 ServiceMonitor + PrometheusRule |
| 有安裝 Prometheus Operator（獨立）| ✅ | 自動建立 |
| 只有原生 Prometheus（無 Operator）| ❌ | 靜默跳過，不報錯 |
| 完全沒有 Prometheus | ❌ | 靜默跳過，不報錯 |

> **對本次建置的意義**：Phase 4a 先安裝 kube-prometheus-stack → Phase 5 安裝 KubeVirt 時，ServiceMonitor 會**自動建立**，不需要手動 apply。

---

## Template 來源：內嵌在 Go Source Code

KubeVirt operator **不讀外部檔案**，所有資源 spec 都硬編碼在 source code 裡：

```
kubevirt/
└── pkg/virt-operator/resource/generate/components/
    ├── prometheus.go       ← ServiceMonitor + PrometheusRule template
    ├── deployments.go      ← virt-api + virt-controller Deployment template
    ├── daemonsets.go       ← virt-handler DaemonSet template
    ├── rbac.go             ← ClusterRole / ClusterRoleBinding template
    └── crds.go             ← 所有 KubeVirt CRD template
```

### PrometheusRule 包含的告警規則（部分）

| Alert Name | 說明 |
|------------|------|
| `KubevirtVMIExcessiveMigrationsDetected` | VM 遷移次數過多 |
| `KubevirtNoAvailableNodesToRunVMs` | 無可用節點運行 VM |
| `KubevirtVMStuck` | VM 卡在非預期狀態 |
| `KubevirtVmiRunningOutsideGuestInfrastructure` | VMI 在非預期節點運行 |
| `KubevirtOrphanedVirtualMachineInstances` | 孤兒 VMI（無對應 VM 資源）|
| `KubevirtVMHighMemoryUsage` | VM 記憶體使用率過高 |

### prometheus.go 簡化範例

```go
func NewPrometheusRule(namespace string) *promv1.PrometheusRule {
    return &promv1.PrometheusRule{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "kubevirt-prometheus-rule",
            Namespace: namespace,
            Labels:    map[string]string{"prometheus.kubevirt.io": ""},
        },
        Spec: promv1.PrometheusRuleSpec{
            Groups: []promv1.RuleGroup{
                {
                    Name: "kubevirt.rules",
                    Rules: []promv1.Rule{
                        {
                            Alert: "KubevirtNoAvailableNodesToRunVMs",
                            Expr:  intstr.FromString(
                                `sum(kube_node_status_allocatable{resource="devices_kubevirt_io_kvm"}) == 0`,
                            ),
                            For:    &metav1.Duration{Duration: 5 * time.Minute},
                            Labels: map[string]string{"severity": "warning"},
                        },
                    },
                },
            },
        },
    }
}
```

---

## 重點整理

- **安裝順序**：`operator.yaml` → 等 virt-operator Running → `cr.yaml`
- **元件建立**：virt-operator watch KubeVirt CR → Reconcile → 依序建立 virt-api / virt-controller / virt-handler
- **監控資源**：條件建立，檢查 `servicemonitors.monitoring.coreos.com` CRD 是否存在
- **Template 來源**：Go source code 硬編碼在 `pkg/virt-operator/resource/generate/components/`，不讀外部 YAML

---

## 參考資料

- [KubeVirt v1.5.0 Release](https://github.com/kubevirt/kubevirt/releases/tag/v1.5.0)
- [virt-operator source: components/](https://github.com/kubevirt/kubevirt/tree/v1.5.0/pkg/virt-operator/resource/generate/components)
- [prometheus.go](https://github.com/kubevirt/kubevirt/blob/v1.5.0/pkg/virt-operator/resource/generate/components/prometheus.go)
- [KubeVirt Monitoring Docs](https://kubevirt.io/user-guide/monitoring/)
