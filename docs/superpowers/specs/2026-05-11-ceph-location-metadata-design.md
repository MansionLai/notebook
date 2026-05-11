---
title: Ceph Location Metadata Design
date: 2026-05-11
status: approved-in-chat
---

# Ceph Location Metadata Design

## Problem Statement

The current `storage/ceph-cross-dc-migration/` notebook topic documents a migration model where the cluster keeps a single logical datacenter and uses `rack` as the failure domain.

The user wants to enrich the documentation and example commands with `datacenter` and `room` metadata while explicitly keeping the failure domain at `rack`.

## Confirmed User Decisions

These decisions were confirmed in chat and should be treated as fixed requirements:

1. Failure domain remains `rack`
2. `datacenter` and `room` should be added as topology metadata
3. `dc1` nodes use:
   - `datacenter=dc1`
   - `room=r1`
4. `dc2` nodes use:
   - `datacenter=dc2`
   - `room=r2`
5. The notebook should update both:
   - explanatory text
   - example `ceph orch host add` commands

## Scope

In scope:

- clarify the role of `datacenter`, `room`, and `rack` in the Ceph topology description
- update the migration notebook pages so readers understand that only `rack` is used as the failure domain
- update example host-add commands to include `datacenter`, `room`, and `rack`

Out of scope:

- changing the migration strategy itself
- changing the CRUSH failure domain from `rack` to `room` or `datacenter`
- adding a new rule that places replicas by `room` or `datacenter`
- redesigning the overall notebook structure

## Design Summary

The docs should describe a host location model that includes:

- `datacenter` for site identity (`dc1`, `dc2`)
- `room` for coarse physical room grouping (`r1`, `r2`)
- `rack` for the actual failure domain used by the migration design

This creates a topology description that is richer for operations and inventory purposes, while preserving the current placement policy.

The docs must explicitly state that adding `datacenter` and `room` metadata does **not** change the effective failure domain. Replica placement still follows `rack`.

## Target File Changes

### 1. `storage/ceph-cross-dc-migration/index.md`

Update the topology / CRUSH design section to state:

- the cluster records `datacenter`, `room`, and `rack`
- `dc1 = datacenter=dc1, room=r1`
- `dc2 = datacenter=dc2, room=r2`
- rack names remain:
  - dc1 OSD racks: `o1`, `o2`, `o3`
  - dc1 MON racks: `m1`, `m2`, `m3`
  - dc2 OSD racks: `o4`, `o5`, `o6`
  - dc2 MON racks: `m4`, `m5`, `m6`
- only `rack` is the failure domain
- `datacenter` and `room` are descriptive topology metadata, not replica placement boundaries

### 2. `storage/ceph-cross-dc-migration/detail_runbook.md`

Update the host onboarding examples so the OSD add command uses full location metadata, for example:

```bash
ceph orch host add $node --labels osd --location datacenter=dc2 room=r2 rack=o4
```

The nearby explanatory text should also note:

- dc2 examples use `datacenter=dc2 room=r2`
- existing dc1 nodes would correspond to `datacenter=dc1 room=r1`
- the extra location fields improve topology clarity but do not change the failure domain

## Behavioral Expectations

After the update, a reader should clearly understand:

1. why the docs include `datacenter` and `room`
2. why the cluster still treats `rack` as the failure boundary
3. how to write host-add commands that carry all three location fields consistently

## Risks and Mitigations

### Risk: Readers may assume `datacenter` or `room` changes replica placement

Mitigation:

- explicitly say that the failure domain remains `rack`
- explicitly say that higher-level metadata is descriptive unless corresponding CRUSH buckets/rules are intentionally changed

### Risk: Example commands could imply a hidden CRUSH redesign

Mitigation:

- keep wording narrow and precise
- avoid claiming that `datacenter` or `room` are currently used for placement

## Acceptance Criteria

The design is complete when:

1. `index.md` explains the role of `datacenter`, `room`, and `rack`
2. `detail_runbook.md` shows host-add examples with all three location fields
3. the docs explicitly state that failure domain remains `rack`
4. the docs consistently use:
   - dc1 → `datacenter=dc1`, `room=r1`
   - dc2 → `datacenter=dc2`, `room=r2`
