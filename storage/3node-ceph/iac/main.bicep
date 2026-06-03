targetScope = 'resourceGroup'

@description('Azure region for deployment.')
param location string = 'japaneast'
@description('Name of the shared virtual network (owned by KubeVirt lab; consumed here as an existing resource).')
param virtualNetworkName string
@description('Resource group name where the shared VNet exists.')
param virtualNetworkResourceGroupName string = resourceGroup().name
@description('Name of the shared node subnet that already exists in the shared VNet.')
param sharedNodeSubnetName string = 'shared-node-subnet'
@description('CIDR of the shared node subnet. Used by the NSG internal-traffic rule.')
param sharedNodeSubnetPrefix string = '10.10.10.0/24'
@description('Name of the Ceph-dedicated cluster subnet to create inside the shared VNet.')
param clusterSubnetName string
@description('CIDR for the Ceph cluster subnet.')
param clusterSubnetPrefix string
@description('Name of the network security group.')
param networkSecurityGroupName string
@description('Trusted source CIDR for inbound rules.')
param allowedSourceCidr string
@description('Administrator username for the Linux VMs.')
param adminUsername string = 'ubuntu'
@description('SSH public key content for the Linux VM admin user.')
@secure()
param adminPublicKey string
@description('Ubuntu image publisher.')
param imagePublisher string = 'Canonical'
@description('Ubuntu image offer.')
param imageOffer string
@description('Ubuntu image SKU.')
param imageSku string
@description('Ubuntu image version.')
param imageVersion string = 'latest'
@description('OS disk size in GB for Ubuntu OS disk.')
param osDiskSizeGb int = 64
@description('Data disk SKU for OSD disks.')
param dataDiskSku string = 'StandardSSD_LRS'
@description('Data disk size in GB for OSD disks.')
param dataDiskSizeGb int = 64

@description('dc1 baseline Ceph nodes. MON uses osdDiskCount=0, OSD uses osdDiskCount=2.')
param cephNodes array

module network './modules/network.bicep' = {
  name: 'network'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkResourceGroupName: virtualNetworkResourceGroupName
    sharedNodeSubnetName: sharedNodeSubnetName
    clusterSubnetName: clusterSubnetName
    clusterSubnetPrefix: clusterSubnetPrefix
  }
}

module nsg './modules/nsg.bicep' = {
  name: 'nsg'
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupName
    allowedSourceCidr: allowedSourceCidr
    publicSubnetPrefix: sharedNodeSubnetPrefix
    clusterSubnetPrefix: clusterSubnetPrefix
  }
}

module cephNodeNics './modules/nic.bicep' = [for node in cephNodes: {
  name: 'cephNodeNic-${node.name}'
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

module cephNodeVms './modules/vm.bicep' = [for (node, i) in cephNodes: {
  name: 'cephNodeVm-${node.name}'
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

output targetResourceGroupName string = resourceGroup().name
output virtualNetworkId string = network.outputs.virtualNetworkId
output publicSubnetId string = network.outputs.publicSubnetId
output clusterSubnetId string = network.outputs.clusterSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
output vmNames array = [for node in cephNodes: node.name]
output cephNodePublicAddresses array = [for i in range(0, length(cephNodes)): cephNodeNics[i].outputs.publicIpAddress]
output cephNodeClusterIps array = [for node in cephNodes: node.clusterIp]
output cephNodePublicNicIds array = [for i in range(0, length(cephNodes)): cephNodeNics[i].outputs.publicNicId]
output cephNodeClusterNicIds array = [for i in range(0, length(cephNodes)): cephNodeNics[i].outputs.clusterNicId]
output cephNodeVmIds array = [for i in range(0, length(cephNodes)): cephNodeVms[i].outputs.vmId]
