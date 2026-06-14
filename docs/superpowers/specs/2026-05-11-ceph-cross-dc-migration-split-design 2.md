---
title: Ceph Cross-DC Migration Split Design
date: 2026-05-11
status: approved-in-chat
---

# Ceph Cross-DC Migration Split Design

## Problem Statement

The current notebook page `storage/ceph-cross-dc-migration/index.md` has grown too large. Split it into three focused documents so readers can move from overview → strategy comparison → operational steps more naturally.

The requested split is:

- keep `index.md` as a lightweight landing page
- move solution comparison into `solutions.md`
- move detailed operational material into `detail_runbook.md`

## Confirmed User Decisions

These decisions were confirmed in chat and should be treated as fixed requirements:

1. `index.md` should keep only:
   - Overview / Scenario
   - topology / architecture content
   - a short reading guide linking to the other pages
2. A new `solutions.md` should compare three migration approaches:
   - add all dc2 OSD nodes, then remove all dc1 OSD nodes
   - add one dc2 rack (5 nodes), then remove one dc1 rack (5 nodes)
   - add one dc2 OSD node, then remove one dc1 OSD node
3. A new `detail_runbook.md` should contain the remaining operational sections now living in `index.md`
4. The `index.md` page should retain a short Reading Guide
5. The topic remains under `storage/ceph-cross-dc-migration/`

## Scope

In scope:

- restructure the content of the existing topic into three notebook pages
- create `solutions.md`
- create `detail_runbook.md`
- trim `index.md` to overview + topology + reading guide
- add lightweight cross-links among the three files

Out of scope:

- changing the underlying migration model itself
- changing the rack naming or topology assumptions
- changing other storage topics

## Target File Responsibilities

### 1. `storage/ceph-cross-dc-migration/index.md`

Purpose: concise entry page

Should contain:

- page title and short opening summary
- Overview / Scenario
- rack naming convention
- Option B statement at a high level
- CRUSH design principle summary at a high level
- topology / architecture diagram
- short Reading Guide that links to:
  - `solutions.md`
  - `detail_runbook.md`

Should not contain:

- long solution trade-off analysis
- phase-by-phase runbook
- cutover gates
- rollback rules
- command reference

### 2. `storage/ceph-cross-dc-migration/solutions.md`

Purpose: decision-making page

Should compare exactly these three strategies:

1. **Bulk expansion then bulk removal**
   - add all dc2 OSD nodes first
   - after rebalance, remove all dc1 OSD nodes
2. **Rack-by-rack alternating migration**
   - add one dc2 rack (5 nodes)
   - wait for recovery
   - remove one dc1 rack (5 nodes)
   - repeat
3. **One-node alternating migration**
   - add one dc2 OSD node
   - wait for recovery
   - remove one dc1 OSD node
   - repeat

For each option, the document should compare:

- operational simplicity
- recovery frequency
- cluster scale peak
- pg_num pressure / temporary scaling pressure
- risk of prolonged migration
- operator effort

The document should explicitly identify the recommended option and explain why.

Given the current discussion, the recommendation should favor the **rack-by-rack alternating migration** model as the best balance between safety and practicality.

### 3. `storage/ceph-cross-dc-migration/detail_runbook.md`

Purpose: operational execution page

Should absorb the detailed execution content currently in `index.md`, including:

- migration principles
- KubeVirt / RBD notes
- detailed phase runbook
- cutover gates
- rollback rules
- command reference

The runbook may be lightly updated so terminology and references still make sense after content is moved out of `index.md`, but this split should not redesign the operational logic unless directly needed for consistency.

## Cross-Linking Requirements

Use lightweight navigation only:

- `index.md` should link to `solutions.md` and `detail_runbook.md`
- `solutions.md` should link back to `index.md` and forward to `detail_runbook.md`
- `detail_runbook.md` should link back to `index.md` and `solutions.md`

This should stay concise. Avoid turning the top of each page into a large nav block.

## Front Matter Expectations

Each new file should use notebook-style Jekyll front matter consistent with the repo conventions and the existing Storage hierarchy.

At minimum, the new files should fit under the same topic tree as `storage/ceph-cross-dc-migration/index.md` so GitHub Pages renders them as children of the same topic.

## Content Preservation Rules

The split must preserve these truths across the resulting pages:

- this topic is still about **Option B** same-cluster migration
- it is still **not** a second-cluster migration
- the cluster still uses **one logical dc**
- failure domain still equals **rack**
- MON nodes still do **not** participate in CRUSH placement
- current scale assumptions remain:
  - dc1 = 3 MON + 15 OSD nodes
  - dc2 = 3 MON + 15 OSD nodes
  - each OSD node has 10 OSD disks
  - dc1 racks = `o1/o2/o3`, `m1/m2/m3`
  - dc2 racks = `o4/o5/o6`, `m4/m5/m6`

## Quality Bar

The resulting notebook topic should satisfy all of the following:

1. A first-time reader can understand the scenario from `index.md` alone.
2. A reader deciding on migration rhythm can open `solutions.md` and compare the three approaches directly.
3. A reader executing the migration can open `detail_runbook.md` without wading through overview material again.
4. No important content is lost during the split.
5. The overall topic becomes easier to scan than the current single long page.
