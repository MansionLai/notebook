# K8s 3-Node Lab on mansion-shared-vnet

## ✅ Deployment Status: COMPLETE

**Deployed:** 2026-05-16 16:22 UTC+8  
**Architecture:** Shared VNet integration with Ceph cluster

### VM Configuration

| Node | VM Name | Size | Private IP (Primary) | Private IP (Secondary) | Public IP |
|------|---------|------|----|----|---------|
| Master | `mansion-kubevirt-master` | D2s_v4 (2C/8G) | 10.10.11.11 | — | 52.243.60.94 |
| Infra | `mansion-kubevirt-infra` | D4s_v4 (4C/16G) | 10.10.11.12 | — | 104.46.220.26 |
| Worker | `mansion-kubevirt-worker` | D4s_v4 (4C/16G) | 10.10.11.13 | 10.10.100.13 | 20.46.170.46 |

### Network Architecture

**Resource Groups:**
- `mansion-shared-resource` — Shared infrastructure
  - VNet: `mansion-shared-vnet` (10.10.0.0/16, 172.10.0.0/16)
  - Subnets:
    - `shared-node-subnet` (10.10.10.0/24) — Ceph nodes
    - `mansion-ceph-cluster-subnet` (172.10.10.0/24) — Ceph cluster
    - `mansion_kubevirt_node_subnet` (10.10.11.0/24) — **NEW: K8s nodes**
    - `mansion_kubevirt_vm_subnet` (10.10.100.0/24) — **NEW: KubeVirt VM overlay**

- `mansion_kubevirt_resource` — K8s workload
  - NSG: `mansion_kubevirt_nsg`
  - 3 VMs attached to shared VNet subnets

### Network Connectivity

✅ **K8s ↔ Ceph communication**
- K8s nodes (10.10.11.x) on same VNet as Ceph nodes (10.10.10.x)
- Full Layer 2 connectivity within `mansion-shared-vnet`
- NSG rules allow internal traffic (10.10.0.0/16)

✅ **KubeVirt VMs**
- Worker secondary NIC on `mansion_kubevirt_vm_subnet` (10.10.100.0/24)
- IP forwarding enabled on secondary NIC
- Accessible from both K8s nodes and Ceph cluster

### SSH Access

```bash
# Master
ssh ubuntu@52.243.60.94

# Infra
ssh ubuntu@104.46.220.26

# Worker
ssh ubuntu@20.46.170.46
```

### Bicep Infrastructure

**Files:**
- `main.bicep` — Template references shared VNet
- `main.bicepparam` — Parameters with node IPs (10.10.11.x)
- `modules/subnet.bicep` — Cross-RG subnet module
- `modules/vm.bicep` — VM template (hostname: _ → -)
- `modules/nsg.bicep` — Network security group
- `modules/nic.bicep` — Network interfaces

**Key Features:**
- Reuses existing `mansion-shared-vnet`
- Creates new subnets for K8s nodes
- NSG attached to K8s subnet for centralized rules
- Handles multi-NIC worker node for KubeVirt

### Verification Checklist

After SSH into each node:

```bash
# Check hostname (should be hyphenated)
hostname

# Check primary IP
ip addr show eth0 | grep "inet "

# For worker: check secondary NIC
ip addr show eth1 | grep "inet "

# Test connectivity to Ceph nodes
ping 10.10.10.21  # should succeed
ping 10.10.10.22
ping 10.10.10.23

# Test connectivity between K8s nodes
ping 10.10.11.12  # from master to infra
```

### Next Steps

1. Configure OS level (phase-0.md)
2. Deploy K8s with Cilium CNI (phase-1.md)
3. Install Rook-Ceph external storage (phase-3.md)
4. Install KubeVirt (phase-5.md)

---

**Deployment ID:** Bicep `main` deployment  
**Shared VNet:** `mansion-shared-vnet` in `mansion-shared-resource`  
**Last Updated:** 2026-05-16
