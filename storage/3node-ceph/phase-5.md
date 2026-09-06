---
title: Phase 5 - Observability 與 Log Shipping
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 15
permalink: /storage/3node-ceph/phase-5/
---

# Phase 5 — Observability 與 Log Shipping（dc1 baseline）

## 目標

為 dc1 baseline 部署 metrics + logs：

- `ceph-exporter`
- `prometheus-node-exporter`
- `fluent-bit`

## 前置條件

- 已完成 [Phase 4](/storage/3node-ceph/phase-4/)

## Ansible 執行方式

```bash
cd storage/3node-ceph/ansible
ansible-playbook playbooks/phase-5.yml
```

## 這個 Ansible 會修改哪些系統狀態

- 安裝並啟用 Docker（供 observability 容器/服務使用）。
- 建立 `/etc/fluent-bit` 與 `/var/lib/fluent-bit`，渲染 `fluent-bit.conf`，並安裝 `fluent-bit.service`。
- 安裝並啟用 `prometheus-node-exporter`（所有 ceph_nodes）。
- 在 `ceph_mon` 節點建立 `/etc/prometheus-agent`，渲染 `prometheus.yml`，並安裝/啟用 `prometheus-agent.service`。
- 在 `ceph_mon` 節點安裝並啟用 `ceph-exporter.service`。
- 重新載入 systemd daemon，讓上述服務加入開機自啟並啟動。

## 驗證方式

```bash
ssh ubuntu@<mon-dc1-01-public-ip> "sudo systemctl status ceph-exporter --no-pager"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo systemctl status prometheus-agent --no-pager"
ssh ubuntu@<osd-dc1-01-public-ip> "sudo systemctl status fluent-bit --no-pager"
ssh ubuntu@<osd-dc1-02-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
ssh ubuntu@<osd-dc1-03-public-ip> "sudo systemctl status prometheus-node-exporter --no-pager"
```

預期結果：

- 監控與日誌元件均為 active
- Prometheus / OpenSearch 可查到 dc1 baseline 指標與日誌
