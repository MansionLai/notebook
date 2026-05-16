---
title: Kubernetes Spec Alignment Design
parent: superpowers specs
nav_exclude: true
---

# Kubernetes Spec Alignment Design

## Problem

`kubernetes/spec.md` is now the source of truth for the notebook's Kubernetes scope, but the current `3node-kubevirt` documentation and Azure Bicep IaC still reflect older assumptions. The biggest drift is in Azure resource naming, VM IP allocation, and the documented platform stack. `3node-multipass/buildup.md` is closer to the current intent, but it still omits two explicit requirements from the spec.

The requested workflow is to make the corrections on branch `ai/k8s`, verify them, and then merge the result back into `main`.

## Goals

1. Align `3node-kubevirt` docs and IaC with `kubernetes/spec.md`.
2. Keep `3node-multipass` documentation consistent with its stated scope.
3. Preserve the existing project structure under `kubernetes/`.
4. Complete the work on `ai/k8s`, then merge back to `main` only after validation succeeds.

## Non-Goals

1. Re-design the Kubernetes folder taxonomy.
2. Expand the spec beyond what is already stated in `kubernetes/spec.md`.
3. Add new infrastructure capabilities not already implied by the spec.
4. Rework unrelated notebook topics outside `kubernetes/`.

## Approach Options

### Option 1 — Full spec alignment (recommended)

Update the affected docs and IaC so that naming, IPs, versions, and required components all follow `kubernetes/spec.md` directly.

**Pros**
- One clear source of truth.
- Removes lingering ambiguity from older shared-VNet naming decisions.
- Simplifies future maintenance because diffs can be judged directly against the spec.

**Cons**
- Replaces some existing shared-network wording that was designed around later Ceph reuse.

### Option 2 — Minimal patching

Fix only the obvious mismatches, such as IPs, prefixes, and top-level doc omissions, while leaving older design language in place where possible.

**Pros**
- Smallest set of edits.

**Cons**
- Leaves conceptual drift in the repo.
- Increases the chance that future notes diverge again.

### Option 3 — Mixed compatibility model

Make the docs say the spec is authoritative while leaving selected IaC naming and topology assumptions partially shared for backward compatibility.

**Pros**
- Less disruptive to older design context.

**Cons**
- Creates a mismatch between the spec and the deployed definition.
- Harder to reason about than either a clean migration or a clear legacy design.

## Decision

Use **Option 1**. The notebook should treat `kubernetes/spec.md` as the authoritative requirement set, and the implementation will align the docs and IaC to it without preserving the old shared-network naming model as the primary story.

## Design

### 1. Branch and merge flow

- Create `ai/k8s` from the current notebook state.
- Make all edits on `ai/k8s`.
- Validate the changed docs and Bicep files.
- Commit the changes on `ai/k8s`.
- Merge `ai/k8s` into `main` after validation passes.

### 2. `3node-kubevirt` documentation changes

Update the project docs so they explicitly reflect the spec:

- Azure resource group name: `mansion_kubevirt_resource`
- Azure resource naming convention: all relevant resource names begin with `mansion_kubevirt`
- Three Ubuntu 22.04 VMs: master, infra, worker
- Node subnet: `10.10.10.0/24`
- Worker secondary NIC / VM subnet: `10.10.100.0/24`
- SSH user: `ubuntu`, key-based authentication only
- VM sizes and static IPs:
  - master: `Standard_D2s_v4`, `10.10.10.11`
  - infra: `Standard_D4s_v4`, `10.10.10.12`
  - worker: `Standard_D4s_v4`, `10.10.10.13`
- Platform stack:
  - Kubernetes `v1.31`
  - CRI-O
  - Cilium
  - Rook-Ceph `v1.17` connected to the self-built Ceph cluster
  - Prometheus
  - Alertmanager
  - Grafana connected to Prometheus
  - OpenSearch
  - Node Exporter on every node
  - Fluent Bit on every node
  - KubeVirt `v1.5.0`

The main emphasis is to make `buildup.md` and any directly referenced IaC/README material stop implying a different architecture than the spec.

### 3. Azure Bicep IaC changes

Update the `3node-kubevirt/iac` defaults so the deployable definition matches the spec:

- Rename default Azure resource names from the older `mansion-k8s-*` and shared VNet variants to `mansion_kubevirt*`.
- Change the default node IPs to `.11`, `.12`, and `.13`.
- Keep the worker secondary NIC and `10.10.100.0/24` subnet.
- Keep Ubuntu 22.04, `ubuntu`, and SSH-key-only authentication.
- Update the IaC README to state that deployments must target `mansion_kubevirt_resource`.

If a current comment or README passage still describes the old shared-VNet / Ceph ownership model as the canonical layout, it should either be removed or rewritten so it does not conflict with the spec-first naming model.

### 4. `3node-multipass` documentation changes

Add two missing explicit statements to `3node-multipass/buildup.md`:

- The VMs are bridged to `en0` on the `192.168.50.x/24` network.
- The lab is a pure three-node Kubernetes environment and does not include KubeVirt.

No broader redesign is needed for the Multipass project.

## Error Handling and Safety

- Do not overwrite unrelated user edits.
- Keep changes limited to spec-alignment files.
- If an existing file contains legacy wording that cannot be safely reconciled in a small edit, prefer an explicit rewrite of that section over leaving contradictory text behind.

## Validation

Validation will focus on:

1. Bicep syntax/build for the updated IaC files.
2. Manual comparison of changed docs against `kubernetes/spec.md`.
3. Git review to confirm the branch contains only the intended Kubernetes notebook changes before merge.

## Success Criteria

The work is complete when:

1. `3node-kubevirt` docs and IaC no longer contradict `kubernetes/spec.md`.
2. `3node-multipass/buildup.md` explicitly matches the spec's scope statement.
3. The changes are committed on `ai/k8s`.
4. `ai/k8s` is merged back into `main` after validation succeeds.
