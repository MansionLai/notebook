---
title: Ceph Runbook Split and Client Coordination
date: 2026-05-12
status: approved-in-chat
---

# Ceph Runbook Split and Client Coordination

## Problem Statement

The current `storage/ceph-cross-dc-migration/detail_runbook.md` mixes two different operational concerns into one long document:

1. **MON migration / client endpoint coordination**
2. **OSD data migration / rack-by-rack execution**

For this environment, the user wants these concerns split so operators can reason about them independently. This matters even more because the client path is:

- KubeVirt VMs
- running on Kubernetes
- connecting to the Ceph cluster through **Rook-Ceph external mode**
- using the Ceph cluster's **RBD pool**

That means MON migration is not just a Ceph quorum task. It also requires coordinated updates to the Rook / ceph-csi client side so KubeVirt-backed workloads do not continue using stale MON endpoints.

## Confirmed User Decisions

1. Use **Option B** for the runbook split
2. Keep `detail_runbook.md`, but repurpose it into the **MON Migration Runbook**
3. Create a separate `osd-migration.md` for the data-plane migration steps
4. Include **Rook-Ceph external mode** and **KubeVirt VM** considerations in **both** runbooks
5. Do not stop for spec review; write and push the spec directly to the notebook repo

## Scope

In scope:

- rewrite `storage/ceph-cross-dc-migration/detail_runbook.md` into a MON-focused runbook
- create `storage/ceph-cross-dc-migration/osd-migration.md`
- update cross-links from `index.md` and `solutions.md`
- make the MON runbook explicitly cover Rook-Ceph external mode client coordination
- keep the OSD runbook focused on rack-by-rack migration, recovery observation, and workload impact

Out of scope:

- changing the overall migration strategy away from **OSD first, MON later** for this scenario
- redesigning the landing page structure beyond link updates
- changing the cluster architecture itself
- introducing a separate third page for client coordination

## Design Summary

### 1. `detail_runbook.md` becomes the MON Migration Runbook

The file keeps its existing permalink so current links do not break, but its role changes.

It should become the control-plane and client-coordination manual for:

- adding dc2 MONs
- validating quorum
- updating client-visible MON endpoints
- removing dc1 MONs only after both Ceph and client-side checks pass

This page should no longer contain the detailed rack-by-rack OSD phase execution as its primary body.

### 2. Add `osd-migration.md` for the data-plane runbook

This new page should carry the detailed OSD migration execution:

- pre-migration validation
- add dc2 rack
- wait for recovery
- remove dc1 rack
- repeat for all racks
- recovery throttling guidance
- per-phase gate criteria and rollback boundaries

Most of the existing OSD phase content in `detail_runbook.md` should move here, with wording tightened so the page is clearly about data movement rather than control-plane cutover.

### 3. Separate the two risk models

The split should make the two operational risk types obvious:

- **MON runbook risk:** quorum stability, Rook endpoint propagation, ceph-csi refresh behavior, short client-side MON failover disturbance
- **OSD runbook risk:** recovery / backfill pressure, RBD latency variation, operator batch size, gate discipline

This prevents MON endpoint cutover risk from being buried inside the OSD execution flow.

## Target Content Structure

### A. MON Migration Runbook (`detail_runbook.md`)

Recommended structure:

1. **Purpose and positioning**
   - explain that this page handles MON migration and client coordination
   - state clearly that OSD bulk migration is documented separately

2. **Pre-checks**
   - verify current MON quorum
   - inventory current external MON endpoints used by Rook
   - back up `rook-ceph-mon-endpoints` and `rook-ceph-config`
   - identify relevant `csi-rbdplugin`, provisioner, and KubeVirt workloads

3. **Add-before-remove MON sequence**
   - add dc2 MONs first
   - verify they are in quorum
   - update Rook-visible endpoint configuration to include both old and new MONs
   - validate client propagation
   - remove dc1 MONs only after the new endpoint set is proven stable

4. **Rook-Ceph external mode coordination**
   - `rook-ceph-mon-endpoints`: use **add-before-remove**
   - `rook-ceph-config`: verify `mon_host` reflects the new endpoint set
   - `csi-rbdplugin`: observe first; if pods do not absorb updates correctly, roll through a **batched restart** rather than a blanket restart

5. **KubeVirt-specific checks**
   - verify running VM disks continue normal I/O
   - treat short MON endpoint failover disturbance as a workload validation item
   - phrase timeout tuning as an environment-specific validation item, not a mandatory configuration change

6. **Gate criteria and rollback**
   - quorum stable
   - client config updated
   - ceph-csi healthy
   - VM / RBD I/O normal
   - if any of those fail, stop before removing old MONs

### B. OSD Migration Runbook (`osd-migration.md`)

Recommended structure:

1. **Purpose and positioning**
   - explain that this page assumes MON/client coordination is handled elsewhere
   - focus on rack-by-rack OSD movement only

2. **Phase 0: shared pre-checks**
   - cluster health
   - PG clean state
   - CRUSH backup
   - network verification
   - baseline metrics

3. **Rack-by-rack migration phases**
   - add dc2 rack o4
   - remove dc1 rack o1
   - add dc2 rack o5
   - remove dc1 rack o2
   - add dc2 rack o6
   - remove dc1 rack o3

4. **Per-phase sections**
   - execution steps
   - validation commands
   - recovery observation
   - gate criteria
   - rollback boundary

5. **KubeVirt / RBD workload impact**
   - focus on latency and throughput disturbance
   - explain that the major client-side risk here is performance degradation, not MON endpoint loss
   - keep recovery throttling guidance near the observation sections

## Cross-Document Changes

### `solutions.md`

The strategy page should keep its scenario-specific conclusion:

- for this migration scenario, **OSD first, MON later**

But its runbook references should no longer imply there is only one detailed runbook. It should point readers to:

- MON migration runbook
- OSD migration runbook

### `index.md`

The landing page reading guide should be updated so readers can clearly choose among:

- strategy / comparison
- MON migration execution
- OSD migration execution

The wording should make the split obvious without adding too much prose back into the landing page.

## Content Principles

1. Keep the MON runbook centered on **endpoint correctness and control-plane safety**
2. Keep the OSD runbook centered on **data movement, workload impact, and gate discipline**
3. Avoid duplicating long explanations across the two pages; duplicate only short, necessary operator warnings
4. Treat Gemini-style suggestions as operational hypotheses to validate and encode carefully, not as unquestioned vendor law
5. Preserve existing permalinks when possible, especially for `detail_runbook.md`

## Acceptance Criteria

This work is complete when:

1. `detail_runbook.md` is clearly a MON migration runbook
2. `osd-migration.md` exists and contains the rack-by-rack OSD execution flow
3. the MON runbook explicitly covers:
   - `rook-ceph-mon-endpoints`
   - `rook-ceph-config`
   - ceph-csi refresh / restart handling
   - KubeVirt VM validation during MON endpoint cutover
4. the OSD runbook explicitly covers:
   - rack-by-rack migration phases
   - RBD / VM performance observation
   - throttling and gate criteria
5. `index.md` and `solutions.md` link to the new structure correctly
