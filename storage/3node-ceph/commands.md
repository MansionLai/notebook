---
title: Commands
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_order: 21
permalink: /storage/3node-ceph/commands/
---

# Ceph 3-Node Commands Reference

這份文件整理 Ceph 3-node on Azure 的主要操作指令。Phase 1-4 現在以 **Ansible 從 Mac mini 執行** 為主，手動 Ceph 指令改定位為驗證與除錯用途。

---

## Azure Phase 0（Azure MCP + Bicep）

本節以 Azure MCP + Bicep 為主，建議以 Bicep 檔案進行資源生命週期管理，統一命名採用 mansion_ 前綴。

### Bicep 檔案與參數準備

請直接使用 `storage/3node-ceph/iac/` 內的：

- `main.bicep`
- `main.bicepparam`
- `README.md`

部署前請至少覆寫：

- `allowedSourceCidr`
- `adminPublicKey`
- `location`（若不是預設 region）

### What-If 預覽

> **前置步驟：確認 KubeVirt lab 的 `mansion-shared-vnet` 與 `shared-node-subnet` 已存在**

```bash
az group create --name mansion_resource --location <your-location>
```

```bash
az deployment group what-if \
  --resource-group mansion_resource \
  --name mansion-ceph-phase0-preview \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 套用 Deployment

```bash
az deployment group create \
  --resource-group mansion_resource \
  --name mansion-ceph-phase0 \
  --template-file storage/3node-ceph/iac/main.bicep \
  --parameters storage/3node-ceph/iac/main.bicepparam
```

### 查詢 Deployment Outputs

```bash
az deployment group show \
  --resource-group mansion_resource \
  --name mansion-ceph-phase0 \
  --query properties.outputs
```

---

## Ansible Quickstart（Mac mini）

```bash
cd storage/3node-ceph/ansible

# 檢查 inventory
ansible-inventory --graph

# 分 phase 執行
ansible-playbook playbooks/phase-1.yml
ansible-playbook playbooks/phase-2.yml
ansible-playbook playbooks/phase-3.yml
ansible-playbook playbooks/phase-4.yml

# 或一次跑完整 build
ansible-playbook playbooks/site.yml
```

### 常用 inventory / ad-hoc 驗證

```bash
cd storage/3node-ceph/ansible

ansible ceph_nodes -m ping
ansible ceph_nodes -m command -a hostname
ansible ceph_nodes -m command -a "ip addr show"
ansible ceph_nodes -m command -a "lsblk"
ansible ceph_nodes -m command -a "/usr/local/bin/cephadm version"
```

---

## Ceph 驗證 / 除錯指令

以下指令通常在 `ceph-node-01` 上執行：

```bash
sudo ceph -s
sudo ceph orch host ls
sudo ceph orch ps
sudo ceph orch ps --daemon-type mon
sudo ceph orch ps --daemon-type mgr
sudo ceph orch device ls
sudo ceph mon stat
sudo ceph osd tree
sudo ceph osd pool ls detail
sudo ceph pg stat
sudo ceph df
sudo rbd ls rbdpool
sudo rbd info rbdpool/test-image
```

---

## SSH / 節點檢查

```bash
ssh ubuntu@<ceph-node-01-public-ip>
ssh ubuntu@<ceph-node-02-public-ip>
ssh ubuntu@<ceph-node-03-public-ip>

ssh ubuntu@<ceph-node-01-public-ip> "hostname"
ssh ubuntu@<ceph-node-01-public-ip> "ssh -o BatchMode=yes ceph-node-02 hostname"
ssh ubuntu@<ceph-node-01-public-ip> "ssh -o BatchMode=yes ceph-node-03 hostname"
```
