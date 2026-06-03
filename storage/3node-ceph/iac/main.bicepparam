using './main.bicep'

param location = 'japaneast'
param virtualNetworkName = 'mansion-shared-vnet'
param virtualNetworkResourceGroupName = 'mansion-shared-resource'
param sharedNodeSubnetName = 'shared-node-subnet'
param sharedNodeSubnetPrefix = '10.10.10.0/24'
param clusterSubnetName = 'mansion-ceph-cluster-subnet'
param clusterSubnetPrefix = '172.10.10.0/24'
param networkSecurityGroupName = 'mansion-ceph-nsg'
param allowedSourceCidr = '61.216.143.3/32'
param adminUsername = 'ubuntu'
param adminPublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPrTSUgVBJAg7NEFNg17pfs2eRGd0H+xRDSU5cG4Oyp mansionlai@MansiondeMac-mini.local'
param imagePublisher = 'Canonical'
param imageOffer = '0001-com-ubuntu-server-jammy'
param imageSku = '22_04-lts-gen2'
param imageVersion = 'latest'
param osDiskSizeGb = 64
param dataDiskSku = 'StandardSSD_LRS'
param dataDiskSizeGb = 64

param cephNodes = [
  {
    name: 'mon-dc1-01'
    role: 'mon'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.21'
    clusterIp: '172.10.10.21'
    osdDiskCount: 0
  }
  {
    name: 'mon-dc1-02'
    role: 'mon'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.22'
    clusterIp: '172.10.10.22'
    osdDiskCount: 0
  }
  {
    name: 'mon-dc1-03'
    role: 'mon'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.23'
    clusterIp: '172.10.10.23'
    osdDiskCount: 0
  }
  {
    name: 'osd-dc1-01'
    role: 'osd'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.24'
    clusterIp: '172.10.10.24'
    osdDiskCount: 2
  }
  {
    name: 'osd-dc1-02'
    role: 'osd'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.25'
    clusterIp: '172.10.10.25'
    osdDiskCount: 2
  }
  {
    name: 'osd-dc1-03'
    role: 'osd'
    vmSize: 'Standard_D2s_v4'
    publicIp: '10.10.10.26'
    clusterIp: '172.10.10.26'
    osdDiskCount: 2
  }
]
