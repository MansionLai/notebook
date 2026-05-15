using './main.bicep'

param location = 'japaneast'
// Shared VNet — owned by KubeVirt lab, consumed here as an existing resource.
// KubeVirt creates this VNet with address spaces 10.10.0.0/16 and 172.10.0.0/16.
param virtualNetworkName = 'mansion-shared-vnet'
// Shared node subnet — already exists in the shared VNet (created by KubeVirt lab).
// KubeVirt K8s nodes occupy 10.10.10.10-12; Ceph nodes use 10.10.10.20-22.
param sharedNodeSubnetName = 'shared-node-subnet'
param sharedNodeSubnetPrefix = '10.10.10.0/24'
// Ceph-dedicated cluster subnet — created by this deployment inside the shared VNet.
param clusterSubnetName = 'ceph-cluster-subnet'
param clusterSubnetPrefix = '172.10.10.0/24'
param networkSecurityGroupName = 'ceph-nsg'
param allowedSourceCidr = '203.0.113.10/32'
param cephNode01VmName = 'ceph-node-01'
param cephNode02VmName = 'ceph-node-02'
param cephNode03VmName = 'ceph-node-03'
param cephNode01VmSize = 'Standard_D4s_v4'
param cephNode02VmSize = 'Standard_D4s_v4'
param cephNode03VmSize = 'Standard_D4s_v4'
param adminUsername = 'ubuntu'
// REQUIRED: Operators MUST replace this empty string with a valid SSH public key before deployment.
// Password authentication is disabled; SSH key authentication is mandatory.
param adminPublicKey = ''
param imagePublisher = 'Canonical'
param imageOffer = '0001-com-ubuntu-server-jammy'
param imageSku = '22_04-lts-gen2'
param imageVersion = 'latest'
// Ceph public NICs attach to the shared-node-subnet; IPs .20-.22 are reserved for Ceph
// (KubeVirt K8s nodes occupy .10-.12 in the same subnet).
param cephNode01PublicIp = '10.10.10.20'
param cephNode02PublicIp = '10.10.10.21'
param cephNode03PublicIp = '10.10.10.22'
// Ceph cluster NICs attach to the dedicated ceph-cluster-subnet (172.10.10.0/24).
param cephNode01ClusterIp = '172.10.10.20'
param cephNode02ClusterIp = '172.10.10.21'
param cephNode03ClusterIp = '172.10.10.22'
param dataDiskSku = 'StandardSSD_LRS'
param dataDiskSizeGb = 64
