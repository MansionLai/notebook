using './main.bicep'

param location = 'japaneast'
// Shared VNet — owned by KubeVirt lab, consumed here as an existing resource.
// KubeVirt creates this VNet with address spaces 10.10.0.0/16 and 172.10.0.0/16.
param virtualNetworkName = 'mansion-shared-vnet'
param virtualNetworkResourceGroupName = 'mansion-shared-resource'
// Shared node subnet — already exists in the shared VNet (created by KubeVirt lab).
// KubeVirt K8s nodes occupy 10.10.10.10-12; Ceph nodes use 10.10.10.21-23.
param sharedNodeSubnetName = 'shared-node-subnet'
param sharedNodeSubnetPrefix = '10.10.10.0/24'
// Ceph-dedicated cluster subnet — created by this deployment inside the shared VNet.
param clusterSubnetName = 'mansion-ceph-cluster-subnet'
param clusterSubnetPrefix = '172.10.10.0/24'
param networkSecurityGroupName = 'mansion-ceph-nsg'
param allowedSourceCidr = '61.216.143.3/32'
param cephNode01VmName = 'mansion-ceph-node-01'
param cephNode02VmName = 'mansion-ceph-node-02'
param cephNode03VmName = 'mansion-ceph-node-03'
param cephNode01VmSize = 'Standard_D4s_v4'
param cephNode02VmSize = 'Standard_D4s_v4'
param cephNode03VmSize = 'Standard_D4s_v4'
param adminUsername = 'ubuntu'
// REQUIRED: Operators MUST replace this empty string with a valid SSH public key before deployment.
// Password authentication is disabled; SSH key authentication is mandatory.
param adminPublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPrTSUgVBJAg7NEFNg17pfs2eRGd0H+xRDSU5cG4Oyp mansionlai@MansiondeMac-mini.local'
param imagePublisher = 'Canonical'
param imageOffer = '0001-com-ubuntu-server-jammy'
param imageSku = '22_04-lts-gen2'
param imageVersion = 'latest'
// Ceph public NICs attach to the shared-node-subnet; IPs .21-.23 are reserved for Ceph
// (KubeVirt K8s nodes occupy .10-.12 in the same subnet).
param cephNode01PublicIp = '10.10.10.21'
param cephNode02PublicIp = '10.10.10.22'
param cephNode03PublicIp = '10.10.10.23'
// Ceph cluster NICs attach to the dedicated mansion-ceph-cluster-subnet (172.10.10.0/24).
param cephNode01ClusterIp = '172.10.10.21'
param cephNode02ClusterIp = '172.10.10.22'
param cephNode03ClusterIp = '172.10.10.23'
param osDiskSizeGb = 64
param dataDiskSku = 'StandardSSD_LRS'
param dataDiskSizeGb = 64
