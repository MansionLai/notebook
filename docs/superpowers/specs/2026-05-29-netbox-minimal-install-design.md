# NetBox 3-node K3s Minimal Install Design

Date: 2026-05-29  
Scope: Keep 3-node topology while minimizing CPU, memory, and disk usage for local Mac mini constraints.

## 1. Goals

- Keep the existing 3-node K3s layout (1 control-plane + 2 workers).
- Minimize VM resource allocation for local development.
- Avoid unsupported in-place VM disk shrinking.
- Keep current installation flow and documentation structure.

## 2. Constraints and Decisions

- Existing Multipass VM disks are not shrunk in place; shrink requires VM recreation.
- Target VM sizing:
  - control-plane: 2 vCPU / 4GB RAM / 20GB disk
  - worker-1: 1 vCPU / 2GB RAM / 15GB disk
  - worker-2: 1 vCPU / 2GB RAM / 15GB disk
- NetBox deployment uses a minimal resource profile by reducing Kubernetes requests/limits to fit local hardware.

## 3. Architecture

- Topology remains unchanged:
  - control-plane node hosts K3s server role.
  - two worker nodes host workloads.
- VM provisioning is updated to minimal values; functional roles are unchanged.
- NetBox remains Helm-based but runs under reduced pod resource envelopes.

## 4. Data and Control Flow

1. Recreate Multipass VMs using minimal CPU/memory/disk values.
2. Install/attach K3s control-plane and join worker nodes.
3. Apply NetBox Helm chart with minimal resource values.
4. Validate cluster and workload health.

## 5. Error Handling

- If cluster components fail due to memory pressure:
  - first reduce NetBox resource requests/limits further (non-critical components first).
- If disk pressure remains:
  - clean stale Multipass images/caches and recreate VMs with defined disk sizes.
- No fallback path relies on in-place disk shrink operations.

## 6. Validation Criteria

- All 3 VMs are created and reachable.
- K3s nodes are Ready across all three nodes.
- NetBox-related pods are Running (or Completed for one-shot jobs) without restart loops.
- Local machine remains stable under expected usage.

## 7. Documentation Changes

- Update `netbox/multipass-k3s-setup.md` with minimal VM sizing defaults.
- Update `netbox/deployment-steps.md` with minimal resource profile guidance for NetBox Helm values.
- Keep `netbox/README.md` references aligned with updated defaults.

## 8. Out of Scope

- Changing from 3-node topology to single-node.
- Production-grade HA tuning.
- Major chart architecture changes unrelated to local resource minimization.
