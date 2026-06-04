# Ceph `_admin` Label Topic Design

Date: 2026-06-04  
Status: Approved for implementation

## 1. Goal

Add a new topic under `storage/` to explain Ceph `_admin` label behavior, with focus on:

1. `_admin` label functional scope
2. What `ceph-mgr` / orchestrator does around `_admin` nodes
3. A readable workflow diagram
4. Actionable commands for inspect/apply/verify/rollback

Target output format is a single note:

- `storage/mon_admin_label/index.md`

## 2. File Scope

### Create

- `storage/mon_admin_label/index.md`

### Update

- `storage/index.md` (add navigation entry for the new topic if needed by existing style)

## 3. Content Structure for `index.md`

The note is architecture-first and organized in five sections:

1. `_admin label` overview
   - What it is and what it is not
   - Boundary with data-plane roles (OSD/MON data path)

2. `ceph-mgr` and orchestrator interactions
   - Label discovery via host inventory
   - Management-plane operations on `_admin` hosts
   - Why `_admin` hosts are practical admin entry points

3. Workflow diagram
   - Host labeled `_admin`
   - mgr/orchestrator reconciliation
   - config/keyring/admin-command usability on `_admin` node
   - verification checkpoints

4. Practical command flow
   - Inspect labels
   - Add `_admin`
   - Verify expected behavior
   - Remove `_admin` rollback path

5. Risks and recommendations
   - Avoid single admin host dependence
   - Keep at least two admin-capable nodes
   - Version-specific behavior note

## 4. Accuracy Rules

1. `_admin` is treated as management-plane convenience, not data-plane throughput control.
2. Avoid overclaiming internal mgr implementation details that depend on Ceph version.
3. Use command examples that are valid for cephadm/orchestrator host workflows.

## 5. Diagram Rules

Use Mermaid `flowchart TD` with clear step labels:

- `Set _admin label`
- `mgr/orchestrator reconcile`
- `admin artifacts/operations available`
- `validate with ceph orch host ls / ceph -s`

Keep the graph compact and terminal-render friendly.

## 6. Success Criteria

1. New topic exists at `storage/mon_admin_label/index.md`.
2. Reader can understand `_admin` purpose in under 2 minutes.
3. Reader can execute end-to-end inspect/add/verify/remove commands directly.
4. Flowchart matches narrative and command sequence without contradictions.
