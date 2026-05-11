---
title: Ceph Cross-DC Migration Refresh Design
date: 2026-05-11
status: approved-in-chat
---

# Ceph Cross-DC Migration Refresh Design

## Problem Statement

Refresh the existing notebook note at `storage/ceph-cross-dc-migration/index.md` so the scenario and topology match the latest requirements:

- dc1 OSD node count changes from 12 to 15
- dc2 OSD node count changes from 12 to 15
- rack naming must be explicitly restated as:
  - dc1 OSD racks: `o1`, `o2`, `o3`
  - dc1 MON racks: `m1`, `m2`, `m3`
  - dc2 OSD racks: `o4`, `o5`, `o6`
  - dc2 MON racks: `m4`, `m5`, `m6`
- add a two-DC server/rack architecture diagram so readers can understand the physical layout more easily

This is a focused documentation refresh, not a redesign of the migration strategy.

## Scope

In scope:

- update the `Overview / Scenario` section in `storage/ceph-cross-dc-migration/index.md`
- update the topology examples in the same file so they are internally consistent with 15 OSD nodes per DC
- add one Mermaid diagram to the same file showing two-DC server/rack distribution

Out of scope:

- changing the migration model away from Option B
- changing the CRUSH design away from single logical dc / failure domain = rack
- splitting the note into multiple files
- modifying other notebook topics

## Confirmed Decisions

The following decisions were confirmed in chat:

1. Keep the topic as a **single main notebook file**.
2. Keep the current migration strategy (**Option B**, same-cluster expansion then dc1 removal).
3. Keep the CRUSH model as **one logical dc** with **failure domain = rack**.
4. The architecture diagram should emphasize **server/rack distribution**, not packet flow or Ceph internal traffic.
5. Preferred implementation approach is to update both the prose and the existing ASCII topology blocks, not only the overview text.

## Recommended Change Set

### 1. Update Overview / Scenario

Revise the opening scenario so it clearly says:

- dc1 = 3 MON + 15 OSD nodes
- dc2 = 3 MON + 15 OSD nodes
- each OSD node still has 10 OSD disks
- dc1 rack labels remain `o1/o2/o3` and `m1/m2/m3`
- dc2 rack labels remain `o4/o5/o6` and `m4/m5/m6`

### 2. Add a Mermaid two-DC architecture diagram

Insert a new architecture section near the top of the note, after the scenario and before the long runbook sections.

The diagram should:

- show `dc1` and `dc2` as separate subgraphs
- show MON rack groups and OSD rack groups per site
- make the 15 OSD node count visible at a glance
- show that both sites remain in one Ceph cluster
- show stretched Layer 2 / same IP segment / unique IP as a short relationship note
- mention that the existing RBD pool continues to serve KubeVirt VMs from the same cluster

The diagram should stay concise. It should help orientation, not become a giant inventory dump.

### 3. Update topology examples

The note currently includes text-based topology blocks for:

- Current (dc1 only)
- Target (dc1 + dc2)
- Final (dc2 only)

These blocks should be updated so they no longer imply 12 OSD hosts. They should reflect:

- 15 dc1 OSD hosts across `o1/o2/o3`
- 15 dc2 OSD hosts across `o4/o5/o6`

The distribution should remain easy to read. It does not need to enumerate every single host if a concise grouped representation is clearer, but the final wording must make the 15-host count explicit and unambiguous.

## Content Constraints

The refresh must preserve these existing truths in the note:

- this is still **Option B**
- this is still **not** a second-cluster migration
- the cluster still uses a **single logical dc**
- the main operational boundary is still **rack**
- MON nodes still do **not** participate in CRUSH placement

## Expected File Changes

Modify:

- `storage/ceph-cross-dc-migration/index.md`

No other notebook file is required for this refresh.

## Quality Bar

The final notebook update should satisfy all of the following:

1. A reader can understand the **new total scale** immediately.
2. A reader can visually distinguish **dc1 racks** from **dc2 racks**.
3. The note stays internally consistent: overview, diagram, and topology examples all agree on **15 OSD nodes per site**.
4. The new diagram supports GitHub Pages rendering via Mermaid and follows existing notebook conventions.
