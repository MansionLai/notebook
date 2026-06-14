---
title: Ceph Solutions Comparison Refresh
date: 2026-05-12
status: approved-in-chat
---

# Ceph Solutions Comparison Refresh

## Problem Statement

The current `storage/ceph-cross-dc-migration/solutions.md` focuses only on three OSD migration rhythms. The user wants this page to answer two decision layers more directly:

1. whether to migrate MON nodes first or OSD nodes first
2. how to choose among three OSD migration rhythms

The main comparison criteria should be:

- impact to user-facing `RBD pool` performance
- operational danger / risk during the migration process

## Confirmed User Decisions

1. The page should be organized into two comparison sections
2. Section one compares:
   - MON first
   - OSD first
3. Section two compares these three OSD rhythms:
   - `(a) 一進一出` — node-by-node alternating add/remove
   - `(b) 櫃進櫃出` — rack-by-rack alternating add/remove
   - `(c) 全進全出` — add all dc2 OSD nodes, then remove all dc1 OSD nodes
4. The key comparison focus is:
   - RBD pool performance impact
   - migration danger level
5. The chosen page structure is:
   - first compare MON-vs-OSD sequencing
   - then compare the three OSD rhythms
   - then provide a concise recommendation summary

## Scope

In scope:

- update `storage/ceph-cross-dc-migration/solutions.md`
- restructure the page into two major comparison sections
- reframe the comparison criteria around RBD performance and migration risk
- preserve cross-links back to the landing page and runbook

Out of scope:

- changing `index.md`
- changing `detail_runbook.md`
- changing the actual migration design or runbook steps

## Target Page Structure

### 1. Intro

The intro should explain that this page now answers two separate questions:

1. should MON or OSD move first
2. if OSD moves first, which OSD migration rhythm is most suitable

It should make clear that this page is about **decision-making**, while detailed execution remains in `detail_runbook.md`.

### 2. Comparison Section One: MON First vs OSD First

This section should compare two sequencing approaches:

#### Option A: MON First

Describe it as:

- move / replace quorum members earlier
- settle monitor topology first
- postpone bulk data movement to later

Key comparison points:

- **RBD pool performance impact**
  - likely lower direct data-path impact during this phase
  - but does not reduce the later OSD rebalance burden
- **Migration danger level**
  - higher control-plane / quorum risk
  - mistakes during MON migration affect cluster visibility and coordination

#### Option B: OSD First

Describe it as:

- keep the existing MON quorum stable during the data-movement-heavy stage
- perform data redistribution first
- adjust MON placement later

Key comparison points:

- **RBD pool performance impact**
  - primary impact appears here because OSD movement triggers rebalance and recovery
  - but this keeps the control plane stable while user I/O is already under load
- **Migration danger level**
  - lower quorum risk during the most stressful data-movement stage
  - operationally safer for same-cluster migration

### Expected recommendation for section one

The page should recommend:

- **OSD first, MON later**

Reasoning:

- the main user-visible performance impact comes from OSD rebalance anyway
- it is safer to avoid changing MON quorum while the cluster is under rebalance stress

### 3. Comparison Section Two: Three OSD Migration Rhythms

This section should compare:

#### Option A: 一進一出

- add one dc2 OSD node
- wait for recovery
- remove one dc1 OSD node
- repeat

Expected positioning:

- **RBD performance impact:** lowest peak impact, smallest per-wave disturbance
- **danger level:** lowest per-step blast radius
- **tradeoff:** highest operator burden and longest migration window

#### Option B: 櫃進櫃出

- add one dc2 rack
- wait for recovery
- remove one dc1 rack
- repeat

Expected positioning:

- **RBD performance impact:** medium impact, but still manageable
- **danger level:** medium-low and operationally well-bounded
- **tradeoff:** best balance between service impact and execution practicality

#### Option C: 全進全出

- add all dc2 OSD nodes
- wait for full rebalance
- remove all dc1 OSD nodes

Expected positioning:

- **RBD performance impact:** highest and longest-lasting
- **danger level:** highest, because a single large wave increases recovery pressure and makes troubleshooting harder
- **tradeoff:** lowest command count, but poorest operational safety

### Comparison criteria for section two

The table or narrative should emphasize:

- `RBD pool performance impact`
- `migration danger level`
- `operator effort`
- `overall migration duration`

The old metrics such as recovery frequency or cluster scale peak may remain only if they still help explain the two primary criteria, but they should no longer dominate the page.

### Expected recommendation for section two

The page should recommend:

- **櫃進櫃出 (rack-by-rack)**

Reasoning:

- smaller and safer than all-in/all-out
- much more practical than node-by-node
- acceptable RBD performance impact with better operational containment

### 4. Final Recommendation Summary

The page should end with a short summary that combines both decision layers:

1. **先轉 OSD，再轉 MON**
2. **OSD 採用櫃進櫃出**

The summary should also mention:

- if the top priority is minimizing per-wave user I/O disturbance, choose node-by-node
- if the top priority is minimizing operator work, choose all-in/all-out
- but for most real migrations, rack-by-rack is the best compromise

## Content Principles

1. Keep the page decision-oriented, not procedural
2. Make `RBD performance impact` and `migration danger level` the most visible criteria
3. Use concise wording so the page remains lighter than the runbook
4. Preserve the role of `solutions.md` as the strategy page between the landing page and the runbook

## Acceptance Criteria

The refresh is complete when:

1. `solutions.md` clearly compares MON-first vs OSD-first
2. `solutions.md` clearly compares the three OSD migration rhythms
3. the page emphasizes RBD performance impact and migration danger level
4. the page recommends:
   - OSD first, MON later
   - rack-by-rack for OSD migration
5. cross-links to the landing page and runbook still work
