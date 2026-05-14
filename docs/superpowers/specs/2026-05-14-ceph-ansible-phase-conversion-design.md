# Ceph 3-Node Phase 1-4 Ansible Conversion Design

## Problem

`storage/3node-ceph/phase-1.md` through `phase-4.md` are currently written as host-by-host manual runbooks. That makes the Azure lab reproducible only if the operator manually replays each command over SSH. The user wants these phases to become Ansible-driven so a Mac mini can orchestrate the full post-provisioning Ceph buildup against the three Azure VMs.

The design goal is not only to add Ansible files, but to make the Phase 1-4 docs themselves point to an Ansible-first workflow, while preserving the existing Ceph topology and operational intent:

- Phase 1: OS prep and node validation
- Phase 2: Ceph prerequisites and cephadm install
- Phase 3: bootstrap and cluster formation
- Phase 4: RBD pool creation and validation

## Assumptions

Because the user was unavailable during clarification, this design assumes the recommended path:

1. `phase-1.md` through `phase-4.md` become **Ansible-first operator guides**
2. Ansible artifacts live **inside** `storage/3node-ceph/ansible/` so the notebook remains self-contained
3. The Mac mini is the Ansible control node
4. Inventory is static and based on the three Azure VM public IPs created in Phase 0
5. Phase boundaries remain visible to readers, but each phase maps to a dedicated Ansible role and playbook

## Approaches Considered

### Approach A — Ansible-first phases with co-located playbooks and roles (**Recommended**)

Add `storage/3node-ceph/ansible/` with inventory, shared vars, `playbooks/phase-1.yml` to `phase-4.yml`, and one primary role per phase. Rewrite each phase doc so the main execution path is “run this playbook from the Mac mini”, while still documenting what the playbook does and how to verify results.

**Pros**
- Matches the user’s stated intent exactly
- Keeps docs and automation together in one project folder
- Makes the current phase structure directly reusable
- Easy for future readers to map docs <-> automation

**Cons**
- Duplicates some logic between docs and Ansible unless carefully curated
- Static inventory means Phase 0 outputs must still be copied into Ansible vars/inventory

### Approach B — Keep docs mostly manual, add an Ansible subproject as an optional accelerator

Keep `phase-1.md` to `phase-4.md` largely as they are, and add a parallel “automation path” in `storage/3node-ceph/ansible/`.

**Pros**
- Lower doc rewrite cost
- Easier if manual runbook fidelity is more important than automation-first usage

**Cons**
- Splits the operator story into two equal paths
- Leaves the docs inconsistent with the user’s stated desired workflow
- Harder to maintain over time

### Approach C — Build a more generic Ceph automation framework first

Create a reusable automation framework with dynamic inventory, reusable environment profiles, and more granular roles than the phase boundaries.

**Pros**
- More extensible for future environments
- Stronger long-term reuse

**Cons**
- Over-scoped for the current notebook project
- Higher design and maintenance cost
- Delays delivering the Azure lab workflow the user actually asked for

## Recommendation

Use **Approach A**.

This keeps the notebook project understandable: the phase docs remain the operator-facing source of truth, but the operator no longer performs the phase work manually on each VM. Instead, each phase doc becomes a thin execution guide around a phase-specific playbook and role set.

## Proposed File Structure

### Existing docs to modify

- `storage/3node-ceph/phase-1.md`
- `storage/3node-ceph/phase-2.md`
- `storage/3node-ceph/phase-3.md`
- `storage/3node-ceph/phase-4.md`
- `storage/3node-ceph/buildup.md`
- `storage/3node-ceph/commands.md`
- `storage/3node-ceph/index.md` (only if phase descriptions need small wording updates)

### New Ansible subtree

```text
storage/3node-ceph/ansible/
├── README.md
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── group_vars/
│   └── all.yml
├── host_vars/
│   ├── ceph-node-01.yml
│   ├── ceph-node-02.yml
│   └── ceph-node-03.yml
├── playbooks/
│   ├── phase-1.yml
│   ├── phase-2.yml
│   ├── phase-3.yml
│   ├── phase-4.yml
│   └── site.yml
└── roles/
    ├── phase1_os_prep/
    ├── phase2_ceph_prereqs/
    ├── phase3_cluster_build/
    └── phase4_rbd_pool/
```

## Role Boundaries

### Role: `phase1_os_prep`

**Purpose:** Normalize the three VMs into the expected Ceph-ready OS baseline.

**Responsibilities**
- install baseline packages
- set hostnames
- manage `/etc/hosts`
- validate both NICs and expected IPs
- validate OSD disks exist and are still unused
- ensure chrony is present and running
- disable ufw for the lab workflow

**Not responsible for**
- installing Ceph
- generating cephadm SSH keys
- creating cluster resources

### Role: `phase2_ceph_prereqs`

**Purpose:** Install runtime prerequisites and cephadm-related tooling on all nodes.

**Responsibilities**
- install container runtime
- enable/start runtime service
- install cephadm and supporting packages
- disable swap
- apply the chosen sysctl tuning set
- prepare passwordless SSH expectations for cephadm orchestration

**Not responsible for**
- running bootstrap
- adding hosts to the cluster

### Role: `phase3_cluster_build`

**Purpose:** Build the Ceph cluster from the Mac mini by delegating bootstrap-sensitive commands to `ceph-node-01`.

**Responsibilities**
- run `cephadm bootstrap` on node 1
- distribute cephadm SSH material as needed
- add node 2 and node 3 as orchestrator hosts
- apply MON placement
- apply MGR placement
- add OSDs from `/dev/sdc` and `/dev/sdd`
- validate final cluster health and service counts

**Not responsible for**
- application pool creation

### Role: `phase4_rbd_pool`

**Purpose:** Create and validate the initial replicated RBD pool.

**Responsibilities**
- create `rbdpool`
- set pool size/min_size/pg parameters
- enable the `rbd` application
- initialize the pool
- create and inspect a test image
- validate pool, PG, and capacity state

## Execution Model

### Control node

The Mac mini runs Ansible locally and SSHes to the three Azure VMs as `ubuntu`.

### Inventory model

Use a static YAML inventory with these logical groups:

- `ceph_admin` → `ceph-node-01`
- `ceph_nodes` → all three nodes

### Variable model

Shared topology and Ceph settings live in `group_vars/all.yml`, including:

- public network CIDR
- cluster network CIDR
- hostname/IP mapping
- OSD device list
- Ceph version target
- dashboard credentials or the secret-file path strategy
- pool defaults (`rbdpool`, `pg_num`, `size`, `min_size`)

Per-node IP specifics live in `host_vars/*.yml`.

### Playbook model

- `playbooks/phase-1.yml` runs `phase1_os_prep` on `ceph_nodes`
- `playbooks/phase-2.yml` runs `phase2_ceph_prereqs` on `ceph_nodes`
- `playbooks/phase-3.yml` runs `phase3_cluster_build`, with bootstrap/orchestrator steps delegated to `ceph-node-01`
- `playbooks/phase-4.yml` runs `phase4_rbd_pool`, also delegated to `ceph-node-01`
- `playbooks/site.yml` chains phases 1-4 for full rebuilds

## Documentation Changes

### `phase-1.md` to `phase-4.md`

Each phase doc should be rewritten to this pattern:

1. phase goal
2. prerequisites / inputs
3. the exact playbook command to run from the Mac mini
4. what the role does
5. verification commands and expected outcomes
6. troubleshooting notes for that phase

These pages should stop being copy-paste SSH command transcripts.

### `buildup.md`

Keep it as the top-level navigation page, but update the summaries so they explicitly describe Ansible-driven execution from the Mac mini.

### `commands.md`

Split it into:

- Ansible execution commands from the Mac mini
- Ceph validation / debugging commands run after automation

The manual step-by-step build commands should move out of the “main path” and become troubleshooting/reference material only.

## Error Handling and Idempotency Expectations

The Ansible design should prefer idempotent primitives wherever possible:

- package installs through apt modules
- hostname and file management through Ansible modules/templates
- service state through service/systemd modules

For Ceph bootstrap/orchestrator actions that are not naturally idempotent, tasks should gate on current cluster state before making changes. The role should explicitly distinguish between:

- “cluster not bootstrapped yet”
- “bootstrap already completed”
- “host already added”
- “OSD already present”
- “pool already exists”

This is important because the intended workflow is repeatable rebuild and re-run from the Mac mini, not one-shot scripting.

## Verification Strategy

### Phase 1 verification
- Ansible connectivity to all hosts
- hostname checks
- `/etc/hosts` content checks
- NIC/IP validation
- disk presence / unused-state checks

### Phase 2 verification
- container runtime installed and running
- cephadm version matches target
- swap is disabled
- SSH connectivity from `ceph-node-01` to the other nodes succeeds

### Phase 3 verification
- bootstrap success
- 3 hosts visible in orchestrator
- 3 MONs in quorum
- MGR active + standbys present
- 6 OSDs up/in
- cluster health at expected state

### Phase 4 verification
- `rbdpool` exists
- pool parameters match desired values
- test image creation succeeds
- PGs reach active+clean

## Scope Limits

This design does **not** include:

- replacing Phase 0 Bicep with Ansible
- integrating dynamic Azure inventory
- deploying monitoring stack
- adding KubeVirt / Rook external mode integration
- refactoring the whole Ceph project into a generic automation framework

## Implementation Notes

If implemented, the first delivery should focus on the single Azure 3-node lab topology already documented in this notebook. Reusability is good, but not at the cost of making the initial operator path harder to read.

The preferred operator story after this change is:

1. Use Phase 0 Bicep to provision Azure VMs
2. Update Ansible inventory/vars with the known node IPs
3. Run `phase-1.yml` through `phase-4.yml` from the Mac mini
4. Use the docs for verification and troubleshooting, not for manual cluster assembly
