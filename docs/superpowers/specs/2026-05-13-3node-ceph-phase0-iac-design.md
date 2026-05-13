---
title: 3node Ceph Phase 0 IaC Design
date: 2026-05-13
status: approved-in-chat
---

# 3node Ceph Phase 0 IaC Design

## Problem Statement

`storage/3node-ceph/phase-0.md` already claims that the recommended Phase 0 workflow is **Azure MCP + Bicep**, but the `storage/3node-ceph/` topic currently has no repo-local IaC assets:

- no `iac/` directory
- no `main.bicep`
- no `main.bicepparam`
- no Bicep module files

This creates a mismatch between the documentation and the actual repository state. The current docs describe a Bicep-first workflow, but they still tell the reader to assume the IaC files have been prepared elsewhere.

The goal is to make `storage/3node-ceph/` self-contained by adding a real, deployable Bicep project and aligning the Phase 0 docs to those concrete files.

## Confirmed User Decisions

1. Fill the gap completely rather than leaving placeholders
2. Create a **directly deployable** `storage/3node-ceph/iac/` folder with real `.bicep` and `.bicepparam` files
3. Reuse the proven structure from `kubernetes/3node-kubevirt/iac/` where helpful, but make the result **3node-ceph specific**
4. Align `phase-0.md` and `commands.md` with the new repo-local IaC instead of asking the reader to prepare Bicep files separately

## Scope

In scope:

- create `storage/3node-ceph/iac/`
- add a Ceph-specific `main.bicep`
- add a Ceph-specific `main.bicepparam`
- add the required Bicep modules under `storage/3node-ceph/iac/modules/`
- add `storage/3node-ceph/iac/README.md`
- update `storage/3node-ceph/phase-0.md`
- update `storage/3node-ceph/commands.md`

Out of scope:

- deploying the new Ceph Phase 0 environment in Azure as part of this docs task
- changing later Ceph build phases beyond the Phase 0 references they depend on
- introducing Azure Portal-first or pure az CLI manual workflows as primary guidance

## Design Summary

### 1. Add a real `storage/3node-ceph/iac/` project

The topic should gain its own IaC folder so the storage note is self-contained:

- `storage/3node-ceph/iac/README.md`
- `storage/3node-ceph/iac/main.bicep`
- `storage/3node-ceph/iac/main.bicepparam`
- `storage/3node-ceph/iac/modules/network.bicep`
- `storage/3node-ceph/iac/modules/nsg.bicep`
- `storage/3node-ceph/iac/modules/nic.bicep`
- `storage/3node-ceph/iac/modules/vm.bicep`

The structure should intentionally mirror the already-proven kubevirt IaC layout closely enough to stay maintainable, but the resource naming, parameter set, and topology assumptions must match the Ceph lab.

### 2. Make the IaC Ceph-specific, not kubevirt-branded

The Ceph IaC should model the topology described in `phase-0.md`:

- three Ceph nodes
- each node on the public subnet and cluster subnet
- each node with two extra managed disks for OSD data
- SSH access controlled by `allowedSourceCidr`
- outputs that help the later Ceph setup stages

This means the new IaC must not preserve the old kubevirt role model of `master / infra / worker`. Instead it should use Ceph-oriented naming such as:

- `cephNode01VmName`
- `cephNode02VmName`
- `cephNode03VmName`

and corresponding NIC / disk / IP parameter names.

### 3. Align the docs to the real repo-local IaC

Once the IaC exists, the docs should stop saying "assume you already prepared the Bicep files".

`phase-0.md` should:

- point directly to `storage/3node-ceph/iac/`
- explain that Azure MCP + Bicep remains the recommended workflow
- present the `az deployment group what-if/create` commands as the local equivalent / validation commands against the repo's actual files

`commands.md` should:

- reference `storage/3node-ceph/iac/main.bicep`
- reference `storage/3node-ceph/iac/main.bicepparam`
- align the example resource names and deployment commands to the new Ceph IaC naming

## Target File Structure

### `storage/3node-ceph/iac/README.md`

Purpose:

- explain what the IaC folder contains
- describe how Azure MCP and Bicep divide responsibilities
- document the file/module map
- identify the values operators are expected to override before deployment

Required content:

- short scope statement for Ceph Phase 0 on Azure
- file guide for `main.bicep`, `main.bicepparam`, and each module
- note that `allowedSourceCidr` and `adminPublicKey` are operator-provided inputs
- note that `what-if` should be run before `create`

### `storage/3node-ceph/iac/main.bicep`

Purpose:

- orchestrate the full Phase 0 resource graph inside a resource group

Required design:

- `targetScope = 'resourceGroup'`
- parameters for:
  - location
  - VNet / subnet names and prefixes
  - NSG name
  - `allowedSourceCidr`
  - SSH username / public key
  - 3 Ceph VM names
  - NIC names
  - private IPs
  - public IP names
  - VM sizes
  - image publisher / offer / sku / version
  - managed disk names / sizes / SKU as needed
- modules for:
  - network
  - nsg
  - per-node NIC creation
  - per-node VM creation
- outputs for:
  - public IPs
  - private IPs
  - VM names / IDs
  - NIC IDs

### `storage/3node-ceph/iac/main.bicepparam`

Purpose:

- provide repo-local default values that match the Ceph Phase 0 lab

Expected defaults:

- Ceph naming with `mansion_ceph_` or equivalent Ceph-specific resource names
- public subnet `10.10.10.0/24`
- cluster subnet `172.10.10.0/24`
- `adminUsername = 'ubuntu'`
- empty-string placeholder for `adminPublicKey` so CLI override is still possible
- VM size defaults matching the current Phase 0 doc expectations unless the implementation finds a safer Azure-availability baseline to document

### `storage/3node-ceph/iac/modules/network.bicep`

Purpose:

- create the Ceph VNet and both subnets

### `storage/3node-ceph/iac/modules/nsg.bicep`

Purpose:

- define inbound SSH access from `allowedSourceCidr`
- allow intra-environment Ceph traffic inside the expected private ranges

### `storage/3node-ceph/iac/modules/nic.bicep`

Purpose:

- create the NICs and public IPs for a Ceph node
- support a two-NIC pattern for Ceph public + cluster traffic

This module should be generalized so all three nodes can use the same pattern instead of special-casing only one node.

### `storage/3node-ceph/iac/modules/vm.bicep`

Purpose:

- create Ubuntu VMs
- attach both NICs
- attach the additional managed disks needed for Ceph OSD use
- configure SSH admin access via public key

## Ceph-Specific Infrastructure Shape

The new IaC should reflect the Phase 0 storage note directly:

1. **Three identical Ceph-oriented nodes**
   - no kubevirt-style role split
   - all three nodes are built as Ceph servers

2. **Dual-network topology on every node**
   - public network NIC for `10.10.10.x`
   - cluster network NIC for `172.10.10.x`

3. **Two extra data disks on every node**
   - model the OSD disks in Azure
   - keep the docs explicit that Azure temporary disk is not part of the Ceph design

4. **Security boundary**
   - SSH only from `allowedSourceCidr`
   - internal Ceph traffic allowed within the environment

## Documentation Changes

### `storage/3node-ceph/phase-0.md`

This page should be changed from "bring your own Bicep files" to "use the IaC in this repo".

Required changes:

- remove the sentence that assumes the reader already prepared `main.bicep` and `main.bicepparam`
- replace it with direct references to `storage/3node-ceph/iac/README.md`, `main.bicep`, and `main.bicepparam`
- keep `az deployment group what-if/create` examples, but clearly frame them as the local equivalent / verification commands for the repo-local Bicep
- keep the top-level recommendation as **Azure MCP + Bicep**

### `storage/3node-ceph/commands.md`

Required changes:

- replace generic preparation wording with references to the actual Ceph IaC files
- align the naming examples with the new Ceph IaC parameter names and resource names
- keep the commands page as a command reference, not a second architecture document

## Content Principles

1. The storage topic must become self-contained
2. The new Ceph IaC should borrow structure from kubevirt IaC, not kubevirt semantics
3. The docs must point at real files in the repo, not hypothetical local files
4. Azure MCP remains the recommended control plane, while `az deployment group what-if/create` remains valid as the underlying Bicep deployment interface
5. Keep operator-overridden inputs explicit: especially SSH public key, allowed source CIDR, and region-specific values

## Acceptance Criteria

This work is complete when:

1. `storage/3node-ceph/iac/` exists
2. the folder contains:
   - `README.md`
   - `main.bicep`
   - `main.bicepparam`
   - `modules/network.bicep`
   - `modules/nsg.bicep`
   - `modules/nic.bicep`
   - `modules/vm.bicep`
3. the new Bicep files model a Ceph-specific 3-node Phase 0 topology
4. `phase-0.md` points to the actual repo-local IaC instead of assuming pre-existing external files
5. `commands.md` references the real Ceph IaC files and Ceph-aligned naming
