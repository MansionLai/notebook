# Ceph dc1 Baseline + dc2 Migration Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update IaC and documentation so `3node-ceph` builds only dc1 baseline (3 MON + 3 OSD), while dc2 expansion is documented under cross-DC migration.

**Architecture:** Refactor Bicep from fixed 3-node parameters to node-list driven configuration with role-based disk counts. Then align `storage/3node-ceph/spec.md`, `phase-0~5.md`, and `storage/ceph-cross-dc-migration/spec.md` to the approved boundary: dc1 baseline in `3node-ceph`, dc2 expansion in cross-DC docs.

**Tech Stack:** Azure Bicep, Markdown docs, ripgrep-based consistency checks.

---

### Task 1: Refactor VM module for role-based OSD disk count

**Files:**
- Modify: `storage/3node-ceph/iac/modules/vm.bicep`
- Test: `storage/3node-ceph/iac/modules/vm.bicep` (build validation)

- [ ] **Step 1: Write the failing structural check**

```bash
rg "dataDisks:\\s*\\[" storage/3node-ceph/iac/modules/vm.bicep -n
```

Expected: shows fixed 2-disk array in `dataDisks`.

- [ ] **Step 2: Implement dynamic disk count input**

```bicep
@description('Number of OSD data disks to attach.')
param osdDiskCount int = 2
```

- [ ] **Step 3: Replace fixed disk array with loop**

```bicep
dataDisks: [for lun in range(0, osdDiskCount): {
  lun: lun
  createOption: 'Empty'
  diskSizeGB: dataDiskSizeGb
  managedDisk: {
    storageAccountType: dataDiskSku
  }
  deleteOption: 'Delete'
}]
```

- [ ] **Step 4: Validate module compiles**

Run:

```bash
az bicep build --file storage/3node-ceph/iac/modules/vm.bicep
```

Expected: build succeeds without syntax errors.

- [ ] **Step 5: Commit**

```bash
git add storage/3node-ceph/iac/modules/vm.bicep
git commit -m "refactor(iac): make vm module support variable osd disk count"
```

### Task 2: Refactor main Bicep to node-list driven deployment

**Files:**
- Modify: `storage/3node-ceph/iac/main.bicep`
- Test: `storage/3node-ceph/iac/main.bicep` (build validation)

- [ ] **Step 1: Write the failing structural check**

```bash
rg "param cephNode0[1-3]" storage/3node-ceph/iac/main.bicep -n
```

Expected: finds hardcoded 3-node params.

- [ ] **Step 2: Add node definition parameter**

```bicep
@description('Ceph node definitions for dc1 baseline.')
param cephNodes array
```

- [ ] **Step 3: Replace per-node NIC/VM modules with loops**

```bicep
module cephNodeNics './modules/nic.bicep' = [for node in cephNodes: {
  name: 'nic-${node.name}'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    publicSubnetId: network.outputs.publicSubnetId
    clusterSubnetId: network.outputs.clusterSubnetId
    publicNicName: '${node.name}-nic-public'
    clusterNicName: '${node.name}-nic-cluster'
    publicIpName: '${node.name}-pip'
    publicPrivateIp: node.publicIp
    clusterPrivateIp: node.clusterIp
  }
}]
```

```bicep
module cephNodeVms './modules/vm.bicep' = [for (node, i) in cephNodes: {
  name: 'vm-${node.name}'
  params: {
    location: location
    vmName: node.name
    nicIds: [
      cephNodeNics[i].outputs.publicNicId
      cephNodeNics[i].outputs.clusterNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: node.vmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    osDiskSizeGb: osDiskSizeGb
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
    osdDiskCount: node.osdDiskCount
  }
}]
```

- [ ] **Step 4: Update outputs to array-based outputs**

```bicep
output vmNames array = [for node in cephNodes: node.name]
output cephNodePublicAddresses array = [for nic in cephNodeNics: nic.outputs.publicIpAddress]
output cephNodeClusterIps array = [for node in cephNodes: node.clusterIp]
```

- [ ] **Step 5: Validate compile**

Run:

```bash
az bicep build --file storage/3node-ceph/iac/main.bicep
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add storage/3node-ceph/iac/main.bicep
git commit -m "refactor(iac): switch 3node-ceph main template to node-list model"
```

### Task 3: Update parameter file to dc1-only 6-node baseline

**Files:**
- Modify: `storage/3node-ceph/iac/main.bicepparam`
- Test: `storage/3node-ceph/iac/main.bicep` with new params

- [ ] **Step 1: Write the failing check for old node names**

```bash
rg "mansion-ceph-node-0[1-3]" storage/3node-ceph/iac/main.bicepparam -n
```

Expected: old mixed-role node names are present.

- [ ] **Step 2: Replace node params with `cephNodes` array**

```bicep
param cephNodes = [
  { name: 'mon-dc1-01', role: 'mon', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.21', clusterIp: '172.10.10.21', osdDiskCount: 0 }
  { name: 'mon-dc1-02', role: 'mon', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.22', clusterIp: '172.10.10.22', osdDiskCount: 0 }
  { name: 'mon-dc1-03', role: 'mon', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.23', clusterIp: '172.10.10.23', osdDiskCount: 0 }
  { name: 'osd-dc1-01', role: 'osd', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.24', clusterIp: '172.10.10.24', osdDiskCount: 2 }
  { name: 'osd-dc1-02', role: 'osd', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.25', clusterIp: '172.10.10.25', osdDiskCount: 2 }
  { name: 'osd-dc1-03', role: 'osd', vmSize: 'Standard_D2s_v4', publicIp: '10.10.10.26', clusterIp: '172.10.10.26', osdDiskCount: 2 }
]
```

- [ ] **Step 3: Validate template + params**

Run:

```bash
az bicep build --file storage/3node-ceph/iac/main.bicep
```

Expected: builds successfully with the new param shape.

- [ ] **Step 4: Commit**

```bash
git add storage/3node-ceph/iac/main.bicepparam
git commit -m "feat(iac): define dc1 6-node role-based baseline parameters"
```

### Task 4: Rewrite `3node-ceph` spec and phase-0 to dc1 baseline

**Files:**
- Modify: `storage/3node-ceph/spec.md`
- Modify: `storage/3node-ceph/phase-0.md`
- Test: wording consistency checks

- [ ] **Step 1: Write failing checks for outdated topology text**

```bash
rg "3 台 Ubuntu|MON \\+ MGR \\+ OSD|每台有 3 顆磁碟" storage/3node-ceph/spec.md storage/3node-ceph/phase-0.md -n
```

Expected: legacy 3-node mixed-role wording appears.

- [ ] **Step 2: Update `spec.md` baseline tables and goals**

```md
- dc1 baseline: 3 MON + 3 OSD (6 VMs)
- MON nodes: 1x OS disk
- OSD nodes: 1x OS disk + 2x OSD disks
```

- [ ] **Step 3: Update `phase-0.md` environment and disk sections**

```md
| mon-dc1-01 | Standard_D2s_v4 | 10.10.10.21 | 172.10.10.21 | MON |
| osd-dc1-01 | Standard_D2s_v4 | 10.10.10.24 | 172.10.10.24 | OSD x2 disks |
```

- [ ] **Step 4: Re-run checks**

```bash
rg "MON \\+ MGR \\+ OSD x2|3 台 VM" storage/3node-ceph/spec.md storage/3node-ceph/phase-0.md -n
```

Expected: no stale baseline text remains.

- [ ] **Step 5: Commit**

```bash
git add storage/3node-ceph/spec.md storage/3node-ceph/phase-0.md
git commit -m "docs(storage): switch 3node-ceph spec and phase-0 to dc1 6-node baseline"
```

### Task 5: Align phase-1 to phase-5 with role-aware dc1-only flow

**Files:**
- Modify: `storage/3node-ceph/phase-1.md`
- Modify: `storage/3node-ceph/phase-2.md`
- Modify: `storage/3node-ceph/phase-3.md`
- Modify: `storage/3node-ceph/phase-4.md`
- Modify: `storage/3node-ceph/phase-5.md`
- Test: phase consistency checks

- [ ] **Step 1: Write failing checks for 3-node assumptions**

```bash
rg "三台|ceph-node-01|ceph-node-02|ceph-node-03" storage/3node-ceph/phase-{1,2,3,4,5}.md -n
```

Expected: many direct 3-node assumptions.

- [ ] **Step 2: Update phase prerequisites and execution scopes**

```md
- `ceph_mon` 群組：mon-dc1-01~03
- `ceph_osd` 群組：osd-dc1-01~03
- 本系列 phase 僅涵蓋 dc1 baseline，不含 dc2
```

- [ ] **Step 3: Update validation commands and expected results**

```bash
ansible ceph_mon -m command -a "ceph --version"
ansible ceph_osd -m command -a "lsblk"
ssh ubuntu@<mon-dc1-01-public-ip> "sudo ceph osd tree"
```

- [ ] **Step 4: Run consistency check**

```bash
rg "dc2|跨 DC|12 台" storage/3node-ceph/phase-{1,2,3,4,5}.md -n
```

Expected: only intentional boundary notes, no embedded dc2 run steps.

- [ ] **Step 5: Commit**

```bash
git add storage/3node-ceph/phase-{1,2,3,4,5}.md
git commit -m "docs(storage): align phase-1~5 to dc1 role-separated baseline flow"
```

### Task 6: Update cross-DC spec to own dc2 expansion responsibility

**Files:**
- Modify: `storage/ceph-cross-dc-migration/spec.md`
- Test: terminology and counts check

- [ ] **Step 1: Write failing checks for old large-scale assumptions**

```bash
rg "3 MON \\+ 15 OSD|15 OSD nodes|rack 包含 5 台" storage/ceph-cross-dc-migration/spec.md -n
```

Expected: old scale wording appears.

- [ ] **Step 2: Rewrite scenario baseline and migration narrative**

```md
1. 現況（dc1 baseline）：3 MON + 3 OSD nodes
2. 擴展目標（dc2）：新增 3 MON + 3 OSD nodes
3. 最終拓撲：雙 DC 共 12 VMs
```

- [ ] **Step 3: Clarify responsibility split with `3node-ceph`**

```md
- `storage/3node-ceph/phase-0~5`：dc1 baseline 建置
- `storage/ceph-cross-dc-migration/*`：dc2 加入與遷移流程
```

- [ ] **Step 4: Validate no stale counts remain**

```bash
rg "15 OSD|50 個 OSD|150 個 OSD" storage/ceph-cross-dc-migration/spec.md -n
```

Expected: no stale scale values remain in spec.

- [ ] **Step 5: Commit**

```bash
git add storage/ceph-cross-dc-migration/spec.md
git commit -m "docs(storage): re-scope cross-dc spec for dc2 expansion from dc1 baseline"
```

### Task 7: Final consistency pass and integration commit

**Files:**
- Modify: all files from Tasks 1-6 (if follow-up fixes needed)

- [ ] **Step 1: Run global consistency checks**

```bash
rg "mansion-ceph-node-0[1-6]|3-node|15 OSD" storage/3node-ceph storage/ceph-cross-dc-migration -n
```

Expected: only intentional historical mentions; no active instruction conflict.

- [ ] **Step 2: Run Bicep compile checks**

```bash
az bicep build --file storage/3node-ceph/iac/main.bicep
az bicep build --file storage/3node-ceph/iac/modules/vm.bicep
```

Expected: both builds succeed.

- [ ] **Step 3: Review git diff for scope correctness**

```bash
git --no-pager diff -- storage/3node-ceph storage/ceph-cross-dc-migration
```

Expected: only requested docs/IaC files changed.

- [ ] **Step 4: Final integration commit**

```bash
git add storage/3node-ceph/iac/main.bicep \
        storage/3node-ceph/iac/main.bicepparam \
        storage/3node-ceph/iac/modules/vm.bicep \
        storage/3node-ceph/spec.md \
        storage/3node-ceph/phase-0.md \
        storage/3node-ceph/phase-1.md \
        storage/3node-ceph/phase-2.md \
        storage/3node-ceph/phase-3.md \
        storage/3node-ceph/phase-4.md \
        storage/3node-ceph/phase-5.md \
        storage/ceph-cross-dc-migration/spec.md
git commit -m "docs+iac(storage): redesign dc1 baseline and dc2 migration topology"
```
