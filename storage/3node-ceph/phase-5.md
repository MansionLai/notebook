---
title: Phase 5 - Observability 與 Log Shipping
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 15
permalink: /storage/3node-ceph/phase-5/
---

# Phase 5 — Observability 與 Log Shipping

## 目標

從 Mac mini 透過 Ansible 安裝並啟用：

- `ceph-exporter`（Ceph metrics）
- `prometheus-node-exporter`（Node metrics）
- `fluent-bit`（Ceph/OS logs）

並將 metrics 轉送到既有 Prometheus、將 logs 送到既有 OpenSearch。

---

## 前置條件

- 已完成 [Phase 4](https://mansionlai.github.io/notebook/storage/3node-ceph/phase-4/)
- `storage/3node-ceph/ansible/inventory/group_vars/all.yml` 已填入：
  - 觀測與 log shipping 的非敏感設定
- `storage/3node-ceph/ansible/inventory/group_vars/encrypted.yml` 已填入：
  - `vault_prometheus_agent_remote_write_url`
  - `vault_fluent_bit_opensearch_host`
  - `vault_fluent_bit_opensearch_username`
  - `vault_fluent_bit_opensearch_password`

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-5.yml
```

---

## 這個 Phase 的 role 會做什麼

- **在三個 Ceph 節點上安裝 `prometheus-node-exporter`**，抓取 OS-level metrics（CPU、Memory、Disk、Network）
- **在 `ceph-node-01` 安裝並啟用 `ceph-exporter`**，抓取 Ceph cluster metrics
- **在三個節點安裝並設定 `fluent-bit`**，收集 syslog、kernel log 與 Ceph daemon logs
- **在 `ceph-node-01` 部署 Prometheus agent**（remote_write 模式）
  - 聚合 node-exporter + ceph-exporter 的 metrics
  - 轉送到既有 Kubernetes 環境的 Prometheus（`vault_prometheus_agent_remote_write_url`）
- fluent-bit 將日誌送到既有 Kubernetes 環境的 OpenSearch（`vault_fluent_bit_opensearch_*` 憑證）

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-5.yml
storage/3node-ceph/ansible/roles/observability/
```

---

## 驗證方式

```bash
# exporters on all three nodes
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
ssh ubuntu@<ceph-node-02-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
ssh ubuntu@<ceph-node-03-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"

# ceph-exporter (ceph-node-01 only)
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status ceph-exporter --no-pager"

# prometheus agent + fluent-bit (ceph-node-01 only)
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status prometheus-agent --no-pager"
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status fluent-bit --no-pager"

# Verify fluent-bit can connect to OpenSearch (from any node or ceph-node-01)
curl -u "<vault_fluent_bit_opensearch_username>:<vault_fluent_bit_opensearch_password>" \
  "https://<vault_fluent_bit_opensearch_host>:9200/_cat/indices?v" | grep ceph

# Check Prometheus has scraped metrics (verify remote_write URL is reachable)
ssh ubuntu@<ceph-node-01-public-ip> "sudo curl -s http://localhost:9090/api/v1/query?query=node_cpu_seconds_total | jq '.data.result | length'"
```

預期結果：

- 三個 `prometheus-node-exporter` 都 active
- `ceph-exporter` active（ceph-node-01）
- `prometheus-agent` active（ceph-node-01）
- `fluent-bit` active（ceph-node-01）
- OpenSearch 內出現 ceph-lab 相關 index
- Prometheus 能查詢到 node metrics
