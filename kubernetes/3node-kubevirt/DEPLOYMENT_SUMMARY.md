# Kubernetes 3-Node KubeVirt Cluster on Azure

## ✅ Deployment Status: COMPLETE

**Deployed:** 2026-05-16 (UTC+8 16:02:09)

### VM Instances

| Node | VM Name | Size | Status | Public IP | Private IP (Primary) | Private IP (Secondary) |
|------|---------|------|--------|-----------|----------------------|------------------------|
| Master | `mansion-kubevirt-master` | D2s_v4 (2C/8G) | Running | 20.89.45.114 | 10.10.10.11 | - |
| Infra | `mansion-kubevirt-infra` | D4s_v4 (4C/16G) | Running | 20.210.91.94 | 10.10.10.12 | - |
| Worker | `mansion-kubevirt-worker` | D4s_v4 (4C/16G) | Running | 20.89.97.249 | 10.10.10.13 | 10.10.100.13 |

### Networking

- **Resource Group:** `mansion_kubevirt_resource` (japaneast)
- **Virtual Network:** `mansion_kubevirt_vnet`
  - Primary CIDR: `10.10.0.0/16`
  - Secondary CIDR: `172.10.0.0/16` (Ceph cluster)
- **Subnets:**
  - `mansion_kubevirt_node_subnet`: `10.10.10.0/24` (K8s nodes)
  - `mansion_kubevirt_vm_subnet`: `10.10.100.0/24` (KubeVirt VM overlay)
  - `mansion_kubevirt_ceph_subnet`: `172.10.10.0/24` (Ceph cluster)
- **NSG:** `mansion_kubevirt_nsg`
  - SSH ingress: Allowed from `61.216.143.3/32`
  - Internal traffic: Allowed within `10.10.0.0/16`

### SSH Access

Connect via SSH key (ubuntu user):

```bash
# Master
ssh ubuntu@20.89.45.114

# Infra
ssh ubuntu@20.210.91.94

# Worker
ssh ubuntu@20.89.97.249
```

### Next Steps

1. **K8s Cluster Setup** - Follow `phase-0.md` through `phase-5.md`:
   - Phase 0: Network configuration & container runtime (CRI-O)
   - Phase 1: Kubernetes (v1.31) cluster initialization with Cilium CNI
   - Phase 2: Storage & Infrastructure (Rook-Ceph v1.17)
   - Phase 3: Monitoring stack (Prometheus, Grafana, Alertmanager)
   - Phase 4: Logging (OpenSearch, Fluent-Bit)
   - Phase 5: KubeVirt (v1.5.0) installation

2. **Azure Resource Management:**
   - IaC source: `/kubernetes/3node-kubevirt/iac/`
   - Parameter file: `main.bicepparam` (contains SSH key and IP configuration)
   - Main template: `main.bicep`
   - Modules: `modules/{network,nsg,nic,vm}.bicep`

### Troubleshooting

- **SSH timeout:** NSG rules may take a few seconds to propagate
- **Hostname verification:** Use `ssh ubuntu@<public-ip> hostname` to verify Linux hostname resolution (underscores replaced with hyphens)

---

**Deployment ID:** `main` (Bicep deployment)  
**Last Updated:** 2026-05-16
