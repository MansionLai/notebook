# Ceph dc1 Baseline + dc2 Migration Redesign

Date: 2026-06-03  
Status: Approved for implementation

## 1. Context and Goal

Current documents mix baseline build steps and cross-DC expansion assumptions.  
Target architecture is changed to role-separated nodes:

- dc1: 3 MON + 3 OSD (6 VMs)
- dc2: 3 MON + 3 OSD (6 VMs)
- Total: 12 VMs

The design must keep day-to-day baseline build simple while moving expansion complexity to migration docs.

## 2. Confirmed Decisions

1. Update scope includes both docs and IaC.
2. Naming is role-based:
   - `mon-dc1-01~03`, `osd-dc1-01~03`
   - `mon-dc2-01~03`, `osd-dc2-01~03`
3. Existing `mansion-ceph-node-01~06` are treated as legacy and not the primary target path.
4. VM sizing uses `Standard_D2s_v4` for both MON and OSD nodes.
5. Disk model:
   - MON node: `1x OS disk` only
   - OSD node: `1x OS disk + 2x OSD disks`
6. Document boundary:
   - `storage/3node-ceph/phase-0~5`: build dc1 baseline only
   - `storage/ceph-cross-dc-migration/*`: add dc2 and execute migration

## 3. Architecture Boundary

### 3.1 dc1 Baseline (3node-ceph)

`storage/3node-ceph/spec.md` and `phase-0~5` become the canonical path for a single-site baseline cluster in dc1:

- 6 nodes total (3 MON, 3 OSD)
- Role-aware inventory grouping and validation
- No dc2 deployment steps in phase docs

### 3.2 dc2 Expansion (ceph-cross-dc-migration)

`storage/ceph-cross-dc-migration/spec.md` becomes the expansion playbook:

- Preconditions: dc1 baseline already complete
- Add dc2 6 nodes
- Execute OSD and MON migration runbooks
- Reach dual-site 12-node topology

## 4. IaC Design Changes

### 4.1 Main template shape

Refactor `storage/3node-ceph/iac/main.bicep` from fixed `cephNode01/02/03` parameters to node-list driven configuration.

Each node object includes:

- `name`
- `role` (`mon` or `osd`)
- `vmSize`
- `publicIp`
- `clusterIp`
- `osdDiskCount`

This allows one template to represent 6-node dc1 baseline cleanly and keeps room for future extension.

### 4.2 VM module disk behavior

`storage/3node-ceph/iac/modules/vm.bicep` changes from fixed two data disks to generated data disks from `osdDiskCount`.

- `mon` nodes set `osdDiskCount = 0`
- `osd` nodes set `osdDiskCount = 2`

### 4.3 Parameter file

`storage/3node-ceph/iac/main.bicepparam` is updated to describe only dc1 baseline nodes and their IPs, consistent with `phase-0`.

## 5. Document Update Plan

### 5.1 `storage/3node-ceph/spec.md`

- Rewrite goal and baseline to dc1-only 6-node topology.
- Replace old 3-node mixed-role table with 6-node role-separated table.
- Update recognized state assumptions and wording to align with baseline scope.

### 5.2 `storage/3node-ceph/phase-0.md`

- Update environment overview table to dc1 6 nodes.
- Update disk section to role-based disk model.
- Update expected outputs and validation language.

### 5.3 `storage/3node-ceph/phase-1.md` ~ `phase-5.md`

- Replace “3 nodes” assumptions with role-aware `ceph_mon` and `ceph_osd` group language.
- Keep phase intent unchanged, but align prerequisites, commands, and expected results to 6-node dc1 baseline.

### 5.4 `storage/ceph-cross-dc-migration/spec.md`

- Replace baseline numbers (`3 MON + 15 OSD`) with new lab-scale dual-site model (`dc1 3+3`, `dc2 3+3`).
- Clarify that dc2 build belongs here, not in 3node baseline phases.
- Keep migration principles, but scale batch narrative to match the new topology.

## 6. Sizing Evaluation (CPU/Memory)

Selected size is `Standard_D2s_v4` for both roles by request.

Assessment:

- Suitable for lab, documentation verification, and controlled migration rehearsal.
- Risk areas: recovery/backfill and concurrent workload pressure on OSD nodes.
- Recommendation: keep docs explicit that OSD nodes may require a larger size if recovery latency is unacceptable.

## 7. Non-Goals

- No automatic migration path from legacy `mansion-ceph-node-01~06` resources.
- No immediate change to non-targeted runbooks beyond consistency edits required by the new baseline.

## 8. Success Criteria

1. `3node-ceph` spec and phase docs describe only dc1 baseline (3 MON + 3 OSD).
2. `ceph-cross-dc-migration/spec.md` describes dc2 expansion on top of dc1 baseline.
3. IaC supports role-specific disk count and dc1 6-node baseline definition.
4. Terminology, tables, and counts are internally consistent across touched docs.
