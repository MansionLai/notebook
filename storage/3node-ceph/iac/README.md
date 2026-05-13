---
title: 3node Ceph IaC / Bicep
parent: 3-Node Ceph (Azure)
grand_parent: Storage
nav_exclude: true
permalink: /storage/3node-ceph/iac/
---

This folder stores the Phase 0 Azure MCP + Bicep definitions for a 3-node Ceph deployment on Azure. It contains the entrypoint Bicep files and modular building blocks used to provision the minimal infrastructure required for the Phase 0 (infrastructure and bootstrap) deployment.

## Planned file map

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

- This directory only contains the IaC scaffold and documentation. The concrete Bicep modules and parameter files will be added in subsequent tasks.
- Always run `az deployment group what-if --resource-group <rg> --template-file main.bicep --parameters @main.bicepparam` before performing a `create`/`deploy` to validate changes.

Concise, focused, and intentionally minimal: this README explains intent, planned layout, and operator expectations for Phase 0 Ceph IaC.
