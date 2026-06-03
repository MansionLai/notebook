---
title: 3node Ceph IaC / Bicep
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_exclude: true
permalink: /storage/3node-ceph/iac/
---

This folder stores the Phase 0 Azure MCP + Bicep definitions for a **dc1 baseline Ceph deployment (3 MON + 3 OSD, total 6 VMs)** on Azure. It contains the entrypoint Bicep files and modular building blocks used to provision infrastructure required for the Phase 0 deployment.

## Shared VNet model

The Ceph lab **does not create its own VNet**. It consumes the shared `mansion-shared-vnet` VNet that is owned and created by the KubeVirt lab. Specifically:

- `mansion-shared-vnet` and `shared-node-subnet` (10.10.10.0/24) are treated as **existing resources** — they must already exist before deploying this Bicep.
- This deployment **creates** only `mansion-ceph-cluster-subnet` (172.10.10.0/24) inside the existing shared VNet. The 172.10.0.0/16 address space was pre-declared by the KubeVirt VNet deployment so no destructive VNet update is needed.
- This Ceph lab deploys into **`mansion_ceph_resource`**.
- Ceph-related resources use the **`mansion-ceph-`** naming prefix (Azure resources do not accept `_`).
- Ceph public NICs use 10.10.10.21-26 (sharing the `shared-node-subnet` with KubeVirt K8s nodes at .10-.12).
- Ceph cluster NICs use 172.10.10.21-26 on the dedicated `mansion-ceph-cluster-subnet`.

## File map

- main.bicep
- main.bicepparam
- modules/network.bicep
- modules/nsg.bicep
- modules/nic.bicep
- modules/vm.bicep

## Operator-overridden values

The operator is expected to supply or override critical values in the parameter file (or via the CLI) when deploying. These include, but are not limited to:

- allowedSourceCidr — CIDR block(s) allowed to access management endpoints.
- adminPublicKey — SSH public key for operator access to provisioned VMs.
- region — Azure region to deploy into (if not using the repository default region).

## Usage notes

- Ensure the KubeVirt lab (`mansion-shared-vnet` and `shared-node-subnet`) is deployed first before running this Ceph deployment.
- Always run `az deployment group what-if --resource-group mansion_ceph_resource --template-file main.bicep --parameters main.bicepparam` before performing a `create`/`deploy` to validate changes.
- The default Jammy 22.04 image in `main.bicepparam` was confirmed available in `japaneast`.
- NSG inbound rules include `AllowSSH` (22/tcp) and `AllowMCP8000` (8000/tcp); both are restricted by `allowedSourceCidr` (do not broaden to `0.0.0.0/0`).

Concise, focused, and intentionally minimal: this README explains intent, file layout, and operator expectations for Phase 0 Ceph IaC.
