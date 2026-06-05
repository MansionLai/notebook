---
title: Azure VM + K3s 基礎設施搭建
parent: Netbox
nav_order: 2
---

# Azure VM + K3s 基礎設施搭建指南

## 概述

本指南帶你在 Azure VM 上建立 3-node K3s 叢集，作為 NetBox Helm chart 的執行基礎。

> **預設資源群組：** `mansion_k3s_netbox`

## 前置要求

- Azure subscription 與可用配額
- 已安裝並登入 `az`
- 已安裝 `kubectl`、`helm`、`ssh`
- 可 SSH 的管理機或 jumpbox
- 3 台 Ubuntu Server Azure VM

## 建議拓撲

| VM 名稱 | 角色 | 建議規格 |
|---|---|---|
| `netbox-k3s-cp-01` | K3s control plane | 2 vCPU / 4 GiB RAM / 64 GiB disk |
| `netbox-k3s-worker-01` | K3s worker | 2 vCPU / 4 GiB RAM / 64 GiB disk |
| `netbox-k3s-worker-02` | K3s worker | 2 vCPU / 4 GiB RAM / 64 GiB disk |

## 第 1 步：建立資源群組

```bash
az group create \
  --name mansion_k3s_netbox \
  --location japaneast
```

## 第 2 步：建立 Azure VM

以下示範使用 Ubuntu 22.04。Control plane 需要開啟 22 與 6443，worker 只需要 22。

```bash
RG=mansion_k3s_netbox
LOC=japaneast
ADMIN_USER=azureuser
SSH_KEY=~/.ssh/id_rsa.pub
IMAGE=Ubuntu2204

az vm create \
  --resource-group $RG \
  --name netbox-k3s-cp-01 \
  --image $IMAGE \
  --size Standard_D2s_v4 \
  --admin-username $ADMIN_USER \
  --ssh-key-values $SSH_KEY

az vm open-port \
  --resource-group $RG \
  --name netbox-k3s-cp-01 \
  --port 22

az vm open-port \
  --resource-group $RG \
  --name netbox-k3s-cp-01 \
  --port 6443

az vm create \
  --resource-group $RG \
  --name netbox-k3s-worker-01 \
  --image $IMAGE \
  --size Standard_D2s_v4 \
  --admin-username $ADMIN_USER \
  --ssh-key-values $SSH_KEY

az vm create \
  --resource-group $RG \
  --name netbox-k3s-worker-02 \
  --image $IMAGE \
  --size Standard_D2s_v4 \
  --admin-username $ADMIN_USER \
  --ssh-key-values $SSH_KEY
```

## 第 3 步：安裝 K3s control plane

```bash
ssh azureuser@<cp-public-ip>

curl -sfL https://get.k3s.io | sh -s - server \
  --write-kubeconfig-mode 644 \
  --tls-san <cp-public-ip>

sudo cat /var/lib/rancher/k3s/server/node-token
```

## 第 4 步：安裝 worker

```bash
ssh azureuser@<worker-01-public-ip>

K3S_URL="https://<cp-private-or-public-ip>:6443"
K3S_TOKEN="<node-token>"
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -
```

重複一次到 `netbox-k3s-worker-02`。

## 第 5 步：設定 kubeconfig

```bash
mkdir -p ~/.kube
scp azureuser@<cp-public-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/netbox-k3s.yaml
python3 - <<'PY'
from pathlib import Path
path = Path.home() / ".kube" / "netbox-k3s.yaml"
path.write_text(path.read_text().replace("127.0.0.1", "<cp-public-ip>"))
PY
export KUBECONFIG=~/.kube/netbox-k3s.yaml
kubectl get nodes -o wide
```

## 第 6 步：驗證叢集

```bash
kubectl get nodes
kubectl get pods -A
```

預期看到 1 個 control plane、2 個 worker 都是 `Ready`。

## K3s 叢集拓撲圖

```
┌─────────────────────────────────────────────────────────┐
│                     Azure Subscription                  │
│                                                         │
│   Resource Group: mansion_k3s_netbox                   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │               Azure VM K3s Cluster               │   │
│  │                                                  │   │
│  │  netbox-k3s-cp-01     netbox-k3s-worker-01       │   │
│  │  netbox-k3s-worker-02                             │   │
│  │                                                  │   │
│  │  Kubernetes API / K3s / kubectl / helm           │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 下一步

K3s 叢集完成後，參考 [deployment-steps.md](./deployment-steps.md) 安裝 NetBox Helm chart。
