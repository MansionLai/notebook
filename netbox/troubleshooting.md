---
title: 故障排查指南
parent: Netbox
nav_order: 6
---

# 故障排查指南

本文檔提供 Azure VM K3s + NetBox 常見問題的診斷方法和解決方案。

## 常見問題和解決方案

### 問題 1：Pod 一直卡在 Pending 狀態

**症狀：**
```bash
kubectl get pods -n netbox
# NAME                     READY   STATUS    RESTARTS   AGE
# netbox-xxx               0/1     Pending   0          5m
```

**原因和解決方案：**

```bash
# 1. 查看 pod 詳細信息
kubectl describe pod netbox-xxx -n netbox

# 2. 檢查是否缺少節點
kubectl get nodes

# 3. 檢查 PVC（如果是 PostgreSQL pod）
kubectl get pvc -n netbox

# 常見原因及解決方案：
# 原因 1：節點資源不足
#   檢查：kubectl top nodes
#   解決：增加節點資源或減少副本數

# 原因 2：存儲類不存在
#   檢查：kubectl get storageclass
#   解決：使用 local-path storageClass（Azure VM 上的 K3s 預設）

# 原因 3：PVC 無法綁定
#   檢查：kubectl get pvc -n netbox
#   解決：檢查 PV 可用性
```

### 問題 2：Pod CrashLoopBackOff

**症狀：**
```bash
# Pod 不斷重啟
kubectl get pods -n netbox
# NAME              READY   STATUS             RESTARTS   AGE
# netbox-xxx        0/1     CrashLoopBackOff   5          2m
```

**診斷步驟：**

```bash
# 1. 查看 pod 日誌（最重要）
kubectl logs netbox-xxx -n netbox

# 2. 查看前一個容器的日誌（如果已重啟）
kubectl logs netbox-xxx -n netbox --previous

# 3. 查看 pod 事件
kubectl describe pod netbox-xxx -n netbox

# 常見錯誤：
# - "連接數據庫失敗" → PostgreSQL 未就緒或密碼錯誤
# - "內存不足 (OOMKilled)" → Netbox 初始遷移需要較多內存。
#   解決：將 `resources.limits.memory` 增加至至少 `1Gi` 或 `2Gi`。
# - "權限被拒絕" → 檢查 PVC 權限
```

### 問題 3：PostgreSQL 無法連接

**症狀：**
```
ERROR: could not connect to server
```

**診斷步驟：**

```bash
# 1. 檢查 PostgreSQL pod 狀態
kubectl get pod -n netbox -l app=postgresql

# 2. 查看 PostgreSQL 日誌
kubectl logs postgresql-0 -n netbox

# 3. 測試連接
kubectl exec -it postgresql-0 -n netbox -- \
  psql -U netbox -d netbox -c "SELECT 1"

# 常見問題：
# 問題 1：密碼錯誤
#   解決：檢查 values.yaml 中的密碼
#   kubectl get secret -n netbox -o yaml | grep password

# 問題 2：數據庫初始化失敗
#   解決：檢查持久化存儲
#   kubectl get pvc -n netbox

# 問題 3：主從複製失敗
#   解決：檢查 pod 間的網絡連通性
#   kubectl exec -it postgresql-0 -- ping postgresql-1
```

### 問題 4：Redis 連接失敗

**症狀：**
```
WRONGPASS invalid username-password pair
```

**診斷步驟：**

```bash
# 1. 查看 Redis pod
kubectl get pod -n netbox -l app=redis

# 2. 測試 Redis 連接
kubectl exec -it redis-master-0 -n netbox -- redis-cli

# 3. 檢查密碼設置
kubectl get secret -n netbox -o yaml | grep redis

# 4. 測試帶密碼連接
kubectl exec -it redis-master-0 -n netbox -- \
  redis-cli -a your-password PING

# 常見解決方案：
# - 檢查密碼是否在 values.yaml 中正確設置
# - 重新部署 Redis：helm upgrade --reuse-values
```

### 問題 5：磁盤空間不足

**症狀：**
```bash
# Pod 無法寫入數據
# error: No space left on device
```

**診斷步驟：**

```bash
# 1. 檢查存儲使用
kubectl exec -it postgresql-0 -n netbox -- df -h

# 2. 檢查 PVC 使用情況
kubectl get pvc -n netbox

# 3. 進入 PostgreSQL 進行清理
kubectl exec -it postgresql-0 -n netbox -- \
  psql -U netbox -d netbox -c "VACUUM ANALYZE;"

# 解決方案：
# - 擴展 PVC 大小（如果支持）
# - 清理舊數據
# - 添加新的 PV
```

### 問題 6：API 響應緩慢

**症狀：**
```bash
# API 請求耗時長（> 5秒）
curl -w "Time: %{time_total}s\n" http://localhost:8000/api/dcim/devices/
```

**診斷步驟：**

```bash
# 1. 查看 pod 資源使用
kubectl top pods -n netbox

# 2. 查看數據庫查詢性能
kubectl exec -it postgresql-0 -n netbox -- \
  psql -U netbox -d netbox -c "SELECT * FROM pg_stat_statements LIMIT 10;"

# 3. 查看 Redis 是否有問題
kubectl exec -it redis-master-0 -n netbox -- \
  redis-cli INFO stats

# 解決方案：
# - 增加 pod replicas
# - 優化數據庫索引
# - 增加 PostgreSQL shared_buffers
# - 檢查 Redis 連接數限制
```

### 問題 7：Web UI 無法訪問

**症狀：**
```bash
# curl: (7) Failed to connect to localhost port 8000
```

**診斷步驟：**

```bash
# 1. 檢查 port-forward
ps aux | grep "port-forward"

# 2. 重新啟動 port-forward
kubectl port-forward svc/netbox 8000:80 -n netbox

# 3. 查看 Service 狀態
kubectl get svc -n netbox

# 4. 檢查 Netbox pod 日誌
kubectl logs deployment/netbox -n netbox

# 5. 測試 Service 內部連接
kubectl run -it --image=alpine curl -- sh
# 在 pod 內執行：
# curl http://netbox:80/
```

### 問題 8：登錄失敗

**症狀：**
```bash
# 輸入正確密碼後仍然登錄失敗
# 或出現 "CSRF verification failed"
```

**診斷步驟：**

```bash
# 1. 檢查 Redis 會話存儲
kubectl exec -it redis-master-0 -n netbox -- redis-cli
# 在 redis-cli 內：
# KEYS session:*  # 查看會話 key

# 2. 檢查 CSRF 配置
kubectl get cm netbox-config -n netbox -o yaml | grep CSRF

# 3. 清理 Redis 緩存
kubectl exec -it redis-master-0 -n netbox -- redis-cli FLUSHDB

# 4. 查看 Netbox 日誌
kubectl logs deployment/netbox -n netbox | grep -i "csrf\|session"
```

## 日誌查詢技巧

### 查看特定時間範圍的日誌

```bash
# 查看最後 100 行日誌
kubectl logs netbox-xxx -n netbox --tail=100

# 追蹤實時日誌
kubectl logs -f netbox-xxx -n netbox

# 查看所有副本的日誌
kubectl logs deployment/netbox -n netbox --all-containers=true
```

### 搜索特定錯誤

```bash
# 在日誌中查找"ERROR"
kubectl logs deployment/netbox -n netbox | grep ERROR

# 查看多個 pod 的日誌並篩選
for pod in $(kubectl get pods -n netbox -l app=netbox -o name); do
  echo "=== $pod ==="
  kubectl logs $pod -n netbox | tail -20
done
```

## 性能監控

### 實時資源監控

```bash
# 查看 pod 資源使用
kubectl top pods -n netbox

# 查看節點資源使用
kubectl top nodes

# 監控數據庫連接數
kubectl exec -it postgresql-0 -n netbox -- \
  psql -U netbox -d netbox -c "SELECT count(*) FROM pg_stat_activity;"

# 監控 Redis 連接
kubectl exec -it redis-master-0 -n netbox -- redis-cli INFO clients
```

### 性能優化建議

```bash
# 1. 增加 Netbox pod 副本數
kubectl scale deployment netbox --replicas=5 -n netbox

# 2. 優化 PostgreSQL 配置
# 編輯 postgresql 參數

# 3. 增加 Redis 內存限制
# 編輯 redis resources.limits.memory

# 4. 添加數據庫索引
# 查看慢查詢：
kubectl exec -it postgresql-0 -n netbox -- \
  psql -U netbox -d netbox -c "SET log_min_duration_statement = 1000; SELECT * FROM pg_stat_statements LIMIT 10;"
```

## 備份和恢復

### PostgreSQL 備份

```bash
# 創建數據庫備份
kubectl exec -it postgresql-0 -n netbox -- \
  pg_dump -U netbox netbox > netbox_backup.sql

# 恢復備份
kubectl exec -i postgresql-0 -n netbox -- \
  psql -U netbox netbox < netbox_backup.sql
```

### Redis 備份

```bash
# 創建 Redis 快照（如已啟用 RDB）
kubectl exec -it redis-master-0 -n netbox -- redis-cli BGSAVE

# 獲取快照文件
kubectl exec -it redis-master-0 -n netbox -- cat /data/dump.rdb > redis_backup.rdb
```

## 清理和重置

### 完全刪除部署

```bash
# 刪除 Helm release
helm uninstall netbox -n netbox

# 刪除 namespace（包括所有數據）
kubectl delete namespace netbox

# 警告：這會刪除所有數據，包括 PVC 中的數據
```

### 重置數據庫

```bash
# 進入 PostgreSQL pod
kubectl exec -it postgresql-0 -n netbox -- psql -U netbox netbox

# 刪除所有表
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

# 或通過 Netbox 管理界面重建
```

## 獲取幫助

如遇到無法解決的問題，參考：

- [Netbox 官方文檔](https://docs.netbox.dev/)
- [Netbox GitHub Issues](https://github.com/netbox-community/netbox/issues)
- [Kubernetes 官方文檔](https://kubernetes.io/docs/)
- [Helm 官方文檔](https://helm.sh/docs/)

---

**提示：** 在提出問題前，始終先收集：
1. 所有 pod 的日誌
2. Pod 詳細狀態（describe）
3. 集群事件日誌
4. 資源使用情況
