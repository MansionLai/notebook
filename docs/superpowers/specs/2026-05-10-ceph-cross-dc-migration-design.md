---
title: Ceph Cross-DC Migration Design
date: 2026-05-10
status: approved-in-chat
---

# Ceph Cross-DC Migration Design

## Problem Statement

Design a new Storage topic at `storage/ceph-cross-dc-migration/` as a single `index.md` note that documents best practice analysis and a practical migration runbook for moving an existing Ceph cluster from old hardware in dc1 to replacement hardware in dc2.

The user explicitly wants to use a **single-cluster expansion/contraction** approach instead of building a second cluster. The environment assumptions are:

- Existing cluster in dc1:
  - 3 monitor nodes
  - 12 OSD nodes
  - each OSD node provides 10 OSD disks
  - RBD pool already exists
  - KubeVirt VMs already consume RBD images from this cluster
- New hardware in dc2:
  - 3 monitor nodes
  - 12 OSD nodes
  - same hardware profile as dc1
- Network:
  - dc1 and dc2 are connected at Layer 2
  - server OS network and Ceph private network use the same IP segments across both sites
  - IP addresses will remain unique even though the CIDR segments are the same
- Migration preference:
  - add dc2 nodes into the existing cluster
  - wait for data rebalance / sync
  - remove dc1 nodes afterward

## User Decisions Captured

The following design choices were explicitly confirmed in chat and must be reflected in the documentation:

1. The output should be a **single main file**: `storage/ceph-cross-dc-migration/index.md`.
2. The topic path should be **`storage/ceph-cross-dc-migration`**.
3. The document should follow **Option B**:
   - expand the existing cluster with dc2 nodes
   - then drain and remove dc1 nodes
4. Even though dc1 and dc2 are physically different datacenters, the user wants the CRUSH model to behave as **one logical dc**.
5. The cluster's effective failure domain should remain **`rack`**, not `datacenter`.
6. Existing rack groups are:
   - OSD racks in dc1: `o1`, `o2`, `o3`
   - MON racks in dc1: `m1`, `m2`, `m3`
7. New dc2 nodes should **not** reuse existing rack names; the note should recommend unique new rack labels, for example:
   - OSD racks: `o4`, `o5`, `o6`
   - MON racks: `m4`, `m5`, `m6`

## Recommended Documentation Position

The note should be honest about the trade-off:

- This is **not** the most explicit dc-aware CRUSH model.
- However, it is an acceptable operational model for this user's environment because:
  - both sites are stretched at Layer 2
  - IPs are unique
  - the user intentionally wants a single logical failure model
  - the cluster already uses `rack` as the important failure boundary

The note should state clearly that the cluster will **not** natively represent dc1 and dc2 as separate datacenter buckets. Instead, the migration will be expressed as:

- adding new MON / OSD capacity under **new rack names**
- allowing data to rebalance into the new rack set
- draining and removing the old rack set

The note should also state clearly that this choice weakens datacenter-level placement visibility and control, and therefore requires stricter operational checks during migration.

## Proposed Note Structure

The new `storage/ceph-cross-dc-migration/index.md` should contain these sections:

1. **Overview**
   - describe the migration scenario
   - explain why this is a same-cluster hardware refresh, not a second-cluster migration

2. **Best Practice Analysis**
   - explain why dc-aware CRUSH is normally clearer
   - explain why this note still proceeds with a single logical dc model
   - emphasize prerequisites: unique IPs, stable L2 extension, acceptable latency/bandwidth, healthy cluster baseline

3. **Current and Target Topology**
   - summarize current dc1 racks: `o1/o2/o3`, `m1/m2/m3`
   - define target dc2 rack naming: `o4/o5/o6`, `m4/m5/m6`
   - explain that rack names must remain globally unique across the whole cluster

4. **Migration Principles**
   - no big-bang replacement
   - expand first, contract later
   - move MON quorum gradually
   - add OSD hosts in small batches
   - wait for health recovery between batches
   - use CRUSH placement + reweight / out / purge to move data instead of image-by-image copy

5. **Detailed Runbook**
   - Phase A: baseline health check and change freeze
   - Phase B: verify / normalize CRUSH rack topology
   - Phase C: add dc2 monitor nodes gradually
   - Phase D: add dc2 OSD hosts gradually
   - Phase E: observe rebalance and KubeVirt workload stability
   - Phase F: drain old dc1 OSD hosts gradually
   - Phase G: remove final dc1 monitors and decommission old hardware

6. **Cutover Gates**
   - define exact conditions for moving to next batch:
     - `ceph -s` healthy enough
     - no uncontrolled PG degradation
     - no MON instability
     - client I/O latency within acceptable window

7. **Rollback Strategy**
   - if MON quorum becomes unstable, stop adding/removing nodes
   - if recovery causes client impact, pause next batch and keep both old/new racks in service
   - if a newly added rack behaves badly, isolate the affected host/rack instead of continuing cluster-wide changes

8. **Command Reference**
   - concise command templates only, including:
     - `ceph -s`
     - `ceph health detail`
     - `ceph osd tree`
     - `ceph orch host add`
     - `ceph orch daemon add mon`
     - `ceph osd crush move`
     - `ceph osd out`
     - `ceph osd purge`
     - relevant observation commands for PG and recovery state

## Technical Guidance To Encode

### MON migration guidance

The note should recommend:

- never replacing all 3 monitors at once
- adding new dc2 MONs one at a time
- checking quorum after each change
- gradually shifting the monitor majority to the new side
- removing old dc1 MONs only after the new monitor set is demonstrably stable

### OSD migration guidance

The note should recommend:

- adding OSD hosts in batches of roughly 2-3 hosts, not all 12 at once
- waiting for rebalance / recovery to settle before the next batch
- draining old dc1 hosts only after the new racks are already carrying data
- avoiding "remove old hosts first and hope recovery catches up"

### KubeVirt / RBD guidance

The note should explain:

- because this remains one cluster, KubeVirt and RBD consumers do not need a full storage backend replacement
- nevertheless, operators must watch:
  - VM I/O latency
  - PVC / pod / virtualization events
  - any guest-visible stalls during backfill and recovery windows
- a controlled maintenance window should still be planned before the final dc1 retirement

## Risks To Call Out Explicitly

The final note must explicitly warn about:

1. **Single logical dc model**
   - the cluster loses native datacenter-level placement semantics

2. **Stretched Layer 2 dependency**
   - if the stretched L2 segment is unstable, Ceph behavior will be unstable too

3. **Recovery impact**
   - aggressive rebalance across many OSDs can hurt client workloads

4. **Rack naming mistakes**
   - reusing old rack names for new hosts can blur placement intent and operational visibility

5. **Cluster must already be healthy**
   - do not begin this migration on a degraded, nearfull, or unstable cluster

## Scope Boundaries

In scope:

- one single-topic notebook note under Storage
- best practice analysis tailored to the user's chosen topology
- practical phased runbook
- rollback rules
- command templates

Out of scope:

- building a second Ceph cluster
- RBD mirroring design
- CephFS migration
- hardware procurement guidance
- exact automation scripts for every host

## Implementation Notes

- Follow the notebook repo style already used in `storage/3node-ceph/`.
- Create a new top-level topic entry under `storage/index.md` if needed so GitHub Pages exposes the new note.
- Keep Traditional Chinese for the notebook content.
- The actual notebook deliverable should be concise but operationally useful, not a giant design treatise.
