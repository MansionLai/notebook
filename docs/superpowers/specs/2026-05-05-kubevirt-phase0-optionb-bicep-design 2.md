# KubeVirt Phase 0 Option B Bicep Design

## Summary

This design defines the Phase 0 Azure infrastructure for the `kubernetes/3node-kubevirt` project using modular Bicep. The template set provisions only the Azure resources required before Kubernetes installation begins. It does not install kubeadm, Cilium, KubeVirt, or any guest workloads.

The design targets the documented Option A node topology while implementing the Phase 0 Option B execution model: provisioning from a Mac mini through Azure CLI and Azure MCP with Infrastructure as Code.

## Goals

1. Provision the complete Phase 0 Azure foundation from code.
2. Keep the template layout readable and maintainable for rebuild scenarios.
3. Match the documented network topology, static IP assignments, and worker secondary NIC behavior.
4. Keep deployment instructions simple enough to run from the user's Mac mini.
5. Align VM sizing with the production-leaning recommendations in `architecture.md`.

## Non-goals

1. Installing or configuring Kubernetes components.
2. Using cloud-init to bootstrap operating system state.
3. Installing Cilium, KubeVirt, Prometheus, or other cluster software.
4. Managing secrets beyond passing the SSH public key at deploy time.
5. Replacing the existing phase documents; this IaC complements them.

## Source Documents

- `kubernetes/3node-kubevirt/phase-0.md`
- `kubernetes/3node-kubevirt/architecture.md`

## Repository Layout

The IaC assets will live under the KubeVirt project directory so the docs and deployable assets stay adjacent but clearly separated.

```text
kubernetes/3node-kubevirt/
├── iac/
│   ├── main.bicep
│   ├── main.bicepparam
│   ├── modules/
│   │   ├── network.bicep
│   │   ├── nsg.bicep
│   │   ├── nic.bicep
│   │   └── vm.bicep
│   └── README.md
```

## Module Responsibilities

### `main.bicep`

- Defines top-level parameters and shared defaults.
- Orchestrates module invocation order.
- Wires resource IDs and names between modules.
- Exposes useful outputs for post-deployment review.

### `modules/network.bicep`

- Creates the virtual network.
- Creates both subnets:
  - `k8s-subnet`
  - `kubevirt-subnet`

### `modules/nsg.bicep`

- Creates the NSG for the cluster.
- Defines the initial inbound rules required by the documented Phase 0 design.

### `modules/nic.bicep`

- Creates NICs for all three VMs.
- Assigns static private IPs.
- Creates and attaches the worker secondary NIC on `kubevirt-subnet`.
- Enables IP forwarding on the worker secondary NIC.
- Associates the NSG to the NICs.
- Creates the required Public IP resources because the approved design keeps Public IPs on all three nodes.

### `modules/vm.bicep`

- Creates the Ubuntu Server 24.04 LTS VMs.
- Attaches the correct NIC set to each VM.
- Applies admin username and SSH public key configuration.
- Sets VM size and OS disk choices.

### `README.md`

- Documents prerequisites on the Mac mini.
- Shows deploy commands.
- Explains which values are fixed defaults and which should be reviewed before each rebuild.
- States clearly that Kubernetes installation still follows the phase documents after Azure resources are ready.

## Fixed Design Decisions

These decisions are approved and should be treated as the baseline behavior of the first implementation.

| Area | Decision |
| --- | --- |
| Scope | Provision only Phase 0 Azure resources |
| Azure region | `Japan East` |
| Deployment model | Modular Bicep |
| Parameter file strategy | Commit a `main.bicepparam` with documented defaults |
| SSH public key | Read from `~/.ssh/id_ed25519.pub` at deployment time rather than committing the key content |
| VM sizing basis | Use the v5 recommendations from `architecture.md` |
| Public IP strategy | Keep Public IPs on all three VMs |

## Parameter Strategy

The design uses two parameter layers:

1. `main.bicepparam` for stable environment defaults that are already part of the documented architecture.
2. CLI overrides for local or operator-specific values that should not be committed as repo defaults.

### Values stored in `main.bicepparam`

- Resource group name: `mansion_resource`
- Location: `Japan East`
- Virtual network name: `mansion-k8s-vnet`
- Address space: `10.10.0.0/16`
- `k8s-subnet` CIDR: `10.10.10.0/24`
- `kubevirt-subnet` CIDR: `10.10.100.0/24`
- VM names:
  - `mansion-k8s-master`
  - `mansion-k8s-infra`
  - `mansion-k8s-worker`
- Static private IPs:
  - master: `10.10.10.10`
  - infra: `10.10.10.11`
  - worker primary NIC: `10.10.10.12`
  - worker secondary NIC: `10.10.100.12`
- Admin username: `ubuntu`
- VM image reference for Ubuntu Server 24.04 LTS
- VM sizes aligned to the architecture recommendations

### Values supplied at deploy time

- `adminPublicKey`, sourced from `~/.ssh/id_ed25519.pub`
- Allowed source IP or CIDR for inbound administrative access

This keeps the repository reusable while preserving a nearly ready-to-run default configuration.

## Resource Model

### Resource group

The deployment assumes the resource group exists as the deployment target. The README will provide the command to create it if needed before running the group deployment.

### Network topology

- One VNet: `mansion-k8s-vnet`
- Address space: `10.10.0.0/16`
- One primary subnet for the cluster nodes:
  - `k8s-subnet` = `10.10.10.0/24`
- One secondary subnet for KubeVirt VM networking on the worker:
  - `kubevirt-subnet` = `10.10.100.0/24`

### NSG rules

The initial NSG rules match the documented minimal set:

| Priority | Purpose | Port / Range | Source |
| --- | --- | --- | --- |
| 100 | SSH | `22/TCP` | operator-provided source CIDR |
| 200 | Kubernetes API | `6443/TCP` | operator-provided source CIDR |
| 300 | NodePort | `30000-32767/TCP` | operator-provided source CIDR |
| 1000 | Internal traffic | `Any` | `10.10.0.0/16` |

### VM layout

The deployment creates three Ubuntu VMs:

| VM | Role | Size basis | Primary private IP |
| --- | --- | --- | --- |
| `mansion-k8s-master` | Kubernetes control plane | `architecture.md` v5 recommendation | `10.10.10.10` |
| `mansion-k8s-infra` | Infra services + KubeVirt management plane | `architecture.md` v5 recommendation | `10.10.10.11` |
| `mansion-k8s-worker` | KubeVirt workload host | `architecture.md` v5 recommendation | `10.10.10.12` |

Each VM also receives a Public IP because the approved design optimizes for direct SSH access during the current operating model.

### Worker secondary NIC

The worker receives a second NIC with these properties:

- subnet: `kubevirt-subnet`
- static private IP: `10.10.100.12`
- IP forwarding: enabled

This is required so the later KubeVirt phases have the documented Azure-side network foundation in place.

## Deployment UX

The README should present a simple deployment flow from the Mac mini:

1. Authenticate with Azure CLI.
2. Select the correct subscription.
3. Ensure the target resource group exists.
4. Read the SSH public key from `~/.ssh/id_ed25519.pub`.
5. Run `az deployment group create` with `main.bicep`, `main.bicepparam`, and CLI parameter overrides.

The first implementation should prefer explicit commands over wrappers so the operator can see exactly how the deployment works.

## Expected Outputs

`main.bicep` should output enough information for immediate review after deployment:

- VM names
- VM private IPs
- Public IP names or addresses
- Worker secondary NIC private IP
- VNet and subnet names

These outputs support quick comparison with the phase documents and reduce portal lookup after deployment.

## Security and Operational Posture

This design intentionally keeps the first iteration conservative and explicit:

- No embedded private credentials
- No committed SSH public key contents
- No permissive `0.0.0.0/0` default for inbound management access
- No automatic software bootstrap beyond Azure resource provisioning

The result is a reusable Phase 0 baseline that is easy to inspect, diff, and rebuild.

## Implementation Boundaries

The implementation that follows this design must stop after Azure infrastructure is ready. The next phases remain documented and manual unless a future design explicitly expands automation into cluster bootstrap.

## Success Criteria

The design is successful when the implementation can:

1. Deploy the documented Phase 0 Azure resources into `Japan East`.
2. Produce the documented static IP layout.
3. Attach the worker secondary NIC correctly with IP forwarding enabled.
4. Leave the environment ready for the existing phase-based Kubernetes setup workflow.
