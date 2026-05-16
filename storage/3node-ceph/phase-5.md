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
- `storage/3node-ceph/ansible/group_vars/all.yml` 已填入：
  - `prometheus_agent_remote_write_url`
  - `fluent_bit_opensearch_host`
  - `fluent_bit_opensearch_username`
  - `fluent_bit_opensearch_password`

---

## Ansible 執行方式

在 Mac mini 執行：

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-5.yml
```

---

## 這個 Phase 的 role 會做什麼

- 在 `ceph-node-01` 安裝並啟用 `ceph-exporter`
- 在三台節點安裝並啟用 `prometheus-node-exporter`
- 在三台節點安裝並設定 `fluent-bit`
- 在 `ceph-node-01` 部署 Prometheus agent（remote_write 模式）
  - 抓取 node-exporter + ceph-exporter metrics
  - 轉送到 `prometheus_agent_remote_write_url`
- fluent-bit 將 `/var/log/syslog`、`/var/log/kern.log`、`/var/log/ceph/*.log` 送到 OpenSearch

對應檔案：

```text
storage/3node-ceph/ansible/playbooks/phase-5.yml
storage/3node-ceph/ansible/roles/observability/
```

---

## 驗證方式

```bash
# exporters
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status ceph-exporter --no-pager"
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
ssh ubuntu@<ceph-node-02-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
ssh ubuntu@<ceph-node-03-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"

# prometheus agent + fluent-bit
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status prometheus-agent --no-pager"
ssh ubuntu@<ceph-node-01-public-ip> "sudo systemctl status fluent-bit --no-pager"

# OpenSearch document check (from your OpenSearch endpoint)
curl -u "<user>:<password>" "https://<opensearch-host>:9200/_cat/indices?v" | grep ceph-lab
```

---

## Troubleshooting

- `Please set prometheus/opensearch endpoint variables`：先補齊 `group_vars/all.yml` 內的 endpoint 參數
- `ceph-exporter` 無法啟動：確認 `ceph-node-01` 上已有 `ceph` CLI 與 `/etc/ceph` 設定
- `prometheus-agent` 無資料：確認 remote_write URL 與認證是否正確
- OpenSearch 無資料：確認 fluent-bit 可連線到 OpenSearch 端點與帳密權限
