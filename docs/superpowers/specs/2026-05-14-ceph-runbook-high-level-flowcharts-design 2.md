---
title: Ceph Runbook High-Level Flowcharts Design
date: 2026-05-14
status: approved-design
---

# Ceph Runbook High-Level Flowcharts Design

## Problem

`storage/ceph-cross-dc-migration/detail_runbook.md` and `storage/ceph-cross-dc-migration/osd-migration.md` are already detailed operational runbooks, but readers currently need to read several paragraphs before they can quickly understand the main motion of each page.

The goal is to add a very high-level flowchart near the top of each runbook so a reader can immediately see what that runbook mainly does before reading the detailed steps.

## Scope

In scope:

- `storage/ceph-cross-dc-migration/detail_runbook.md`
- `storage/ceph-cross-dc-migration/osd-migration.md`

Out of scope:

- changing the runbook strategy itself
- adding low-level commands into the diagrams
- adding rollback branches or detailed decision trees
- changing `index.md` or `solutions.md` unless a later implementation need is discovered

## Design Decisions

### 1. Placement

Each runbook gets one Mermaid high-level flowchart placed:

1. after the H1 and introductory summary text
2. before the first principles section

This keeps the flowchart visible immediately at page entry without interrupting the detailed runbook structure further down.

### 2. Shared Diagram Style

Both runbooks use the same high-level visual skeleton so readers can scan them consistently:

`Pre-check -> Main migration cycle -> Validation -> Final confirmation`

The diagrams should remain intentionally simple:

- horizontal layout (`flowchart LR`)
- 5-7 major nodes only
- no standalone "start" marker node
- no command snippets
- no rollback paths
- no low-level branching

### 3. Execution Context Blocks

Both diagrams should visually separate actions by execution context using Mermaid subgraphs and background styling:

- one `Ceph cluster` block
- one `K8s cluster` block

The distinction should be visible even before reading node text. The preferred mechanism is:

1. `subgraph` blocks to group nodes
2. `classDef` styling to give Ceph and K8s groups different background colors

This change is not about architecture accuracy at every low-level detail; it is about reader orientation at page entry.

### 4. MON Runbook Flow

The MON flowchart should communicate the control-plane sequence at a glance:

Ceph cluster block:

1. backup and baseline validation
2. add dc2 MON capacity
3. remove dc1 MON members
4. perform final health confirmation

K8s cluster block:

1. update client-side MON endpoints
2. validate client I/O continuity

The diagram should read left-to-right, with arrows crossing between the Ceph and K8s blocks where coordination happens.

The chart should emphasize add-before-remove and endpoint coordination, but only at a summary level.

### 5. OSD Runbook Flow

The OSD flowchart should communicate the data-plane migration rhythm at a glance:

Ceph cluster block:

1. cluster health and readiness check
2. add one dc2 rack
3. wait for rebalance and recovery
4. remove one dc1 rack
5. wait again until rack cycles complete
6. perform final balance and health confirmation

K8s cluster block:

1. observe VM / RBD impact during the migration rhythm

The K8s block may be lighter than the Ceph block on this page, but it should still exist so the reader can distinguish operational actions executed on the Ceph cluster from workload-side validation done from the Kubernetes side.

The chart should make the repeating rack-by-rack cadence obvious without expanding into every phase from the detailed runbook.

### 6. Writing Style

Diagram labels should follow the existing notebook style:

- concise Chinese labels are preferred for consistency with the surrounding notebook pages
- surrounding explanatory text remains in the current mixed Chinese / English documentation style
- labels should prefer operational verbs and nouns over long sentences

## Expected Outcome

After this change:

- a reader opening either runbook can understand the page purpose in a few seconds
- MON and OSD runbooks feel visually aligned
- a reader can immediately tell which actions belong to the Ceph cluster and which belong to the K8s cluster
- the detailed steps remain unchanged and continue to serve as the execution source of truth

## Implementation Notes

Expected implementation should be small and localized:

- add one Mermaid block to each runbook
- switch both diagrams to a horizontal structure
- add block-level styling for Ceph vs K8s execution context
- add at most a short one-line lead-in if needed
- preserve the current headings and detailed sections below
