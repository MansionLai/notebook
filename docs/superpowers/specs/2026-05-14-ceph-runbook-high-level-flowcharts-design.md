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

`Start -> Pre-check -> Main migration cycle -> Validation -> Cleanup / End`

The diagrams should remain intentionally simple:

- 5-7 major nodes only
- no command snippets
- no rollback paths
- no low-level branching

### 3. MON Runbook Flow

The MON flowchart should communicate the control-plane sequence at a glance:

1. backup and baseline validation
2. add dc2 MON capacity
3. update client-side MON endpoints
4. validate quorum and client I/O continuity
5. remove dc1 MON members
6. perform final health confirmation

The chart should emphasize add-before-remove and endpoint coordination, but only at a summary level.

### 4. OSD Runbook Flow

The OSD flowchart should communicate the data-plane migration rhythm at a glance:

1. cluster health and readiness check
2. add one dc2 rack
3. wait for rebalance and recovery
4. remove one dc1 rack
5. repeat rack-by-rack cycle
6. perform final balance and health confirmation

The chart should make the repeating rack-by-rack cadence obvious without expanding into every phase from the detailed runbook.

### 5. Writing Style

Diagram labels should follow the existing notebook style:

- concise English action labels are acceptable inside Mermaid
- surrounding explanatory text remains in the current mixed Chinese / English documentation style
- labels should prefer operational verbs and nouns over long sentences

## Expected Outcome

After this change:

- a reader opening either runbook can understand the page purpose in a few seconds
- MON and OSD runbooks feel visually aligned
- the detailed steps remain unchanged and continue to serve as the execution source of truth

## Implementation Notes

Expected implementation should be small and localized:

- add one Mermaid block to each runbook
- add at most a short one-line lead-in if needed
- preserve the current headings and detailed sections below
