---
title: Ceph Index Cabinet Redesign
date: 2026-05-12
status: approved-in-chat
---

# Ceph Index Cabinet Redesign

## Problem Statement

The landing page at `storage/ceph-cross-dc-migration/index.md` is still too text-heavy for a topic that now has dedicated `solutions.md` and `detail_runbook.md` pages.

The user wants the landing page to become more visual and more scan-friendly:

- condense the scenario text
- remove redundant explanatory sections already covered elsewhere
- merge rack naming into topology metadata
- redraw the architecture as a cabinet-oriented diagram with a CRUSH-style metadata view

## Confirmed User Decisions

1. The node summary should be condensed so `3 MON / 15 OSD nodes / 10 OSD disks per node` reads as one line
2. Remove the sentence stating that all IPs across both sites are unique
3. Fold `Rack 命名規範` into `Topology Metadata`
4. Present metadata in a CRUSH-like hierarchy using:
   - `datacenter`
   - `room`
   - `rack`
5. Do not show `default` in the metadata tree
6. Remove the `遷移策略：Option B` section from the landing page
7. Remove the `CRUSH 設計原則` section from the landing page
8. Redraw the architecture diagram in a more visual, cabinet-oriented style
9. For the new diagram direction:
   - use the user-selected visual direction **B**
   - use the user-selected density **balanced**
   - emphasize visuals over text on the landing page

## Scope

In scope:

- redesign `storage/ceph-cross-dc-migration/index.md`
- condense the overview / scenario block
- rewrite `Topology Metadata` as a compact datacenter → room → rack tree
- replace the current architecture diagram with a cabinet-style Mermaid diagram
- keep the page as the landing page for the topic with reading-guide links intact

Out of scope:

- changing `solutions.md`
- changing `detail_runbook.md`
- changing the migration strategy itself
- changing the topology facts or rack names

## Target Page Structure

### 1. Overview / Scenario

Keep this section, but compress it into a lighter landing-page summary.

Expected content shape:

- dc1 line: `3 MON、15 OSD nodes（每台 10 顆 OSD disks）`
- dc2 line: same hardware summary
- network line:
  - stretched Layer 2
  - same IP segment for server OS and Ceph private network
- keep the existing RBD / KubeVirt context
- remove the “all IP addresses are unique” line

### 2. Topology Metadata

This becomes the main textual structure section.

It should:

- absorb the rack naming content
- show hierarchy using only:
  - `datacenter`
  - `room`
  - `rack`
- omit `default`
- read more like a CRUSH-location tree than prose

Expected content shape:

```text
datacenter dc1
└─ room r1
   ├─ rack m1 / m2 / m3
   └─ rack o1 / o2 / o3

datacenter dc2
└─ room r2
   ├─ rack m4 / m5 / m6
   └─ rack o4 / o5 / o6
```

The MON note may remain, but only if it still helps the reader and does not re-expand the page too much.

### 3. Architecture Diagram

Replace the current diagram with a more visual hybrid:

- left side: metadata / CRUSH-style tree
- right side: cabinet-style grouping for dc1 and dc2

Balanced-density rendering means:

- do not label every individual rack in the cabinet area
- do show:
  - `MON racks × 3`
  - `OSD racks × 3`
  - `15 nodes / 150 OSDs`
- keep the cabinet side visual and high level
- keep exact rack names in the metadata tree, not repeated heavily in the cabinet blocks

The diagram should still communicate:

- dc1 maps to `room r1`
- dc2 maps to `room r2`
- each DC has MON and OSD rack groups
- the topic is a cross-DC Ceph environment serving RBD for KubeVirt

### 4. Reading Guide

Keep the current landing-page role:

- link to `solutions/`
- link to `detail_runbook/`

This section should remain mostly unchanged.

## Content Principles

1. **Visual-first landing page**
   - the page should feel lighter and more diagram-centric

2. **No duplicate strategy prose**
   - strategy analysis belongs in `solutions.md`
   - procedural detail belongs in `detail_runbook.md`

3. **Metadata tree over prose**
   - use structured hierarchy instead of separate “rack naming” explanation blocks

4. **Balanced diagram density**
   - metadata detail on the left
   - cabinet summary on the right
   - avoid over-labeling every cabinet element

## Acceptance Criteria

The redesign is complete when:

1. `index.md` no longer has separate `Rack 命名規範`, `遷移策略：Option B`, or `CRUSH 設計原則` sections
2. the scenario text is shorter and the node summary is condensed to one-line hardware summaries
3. the unique-IP sentence is removed
4. `Topology Metadata` shows `datacenter -> room -> rack` without `default`
5. the new architecture diagram follows the selected B-direction and balanced-density style
6. `Reading Guide` links remain intact
