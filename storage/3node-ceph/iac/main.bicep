targetScope = 'resourceGroup'

@description('Azure region for deployment.')
param location string = 'japaneast'
@description('Name of the virtual network.')
param virtualNetworkName string
@description('CIDR for the virtual network.')
param virtualNetworkAddressPrefix string
@description('CIDR for the cluster address space inside the virtual network.')
param clusterAddressPrefix string = '172.10.0.0/16'
@description('Name of the public subnet.')
param publicSubnetName string
@description('CIDR for the public subnet.')
param publicSubnetPrefix string
@description('Name of the cluster subnet.')
param clusterSubnetName string
@description('CIDR for the cluster subnet.')
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

@description('Ceph node 01 VM name.')
param cephNode01VmName string
@description('Ceph node 02 VM name.')
param cephNode02VmName string
@description('Ceph node 03 VM name.')
param cephNode03VmName string
@description('Ceph node 01 VM size.')
param cephNode01VmSize string
@description('Ceph node 02 VM size.')
param cephNode02VmSize string
@description('Ceph node 03 VM size.')
param cephNode03VmSize string
@description('Ceph node 01 public IP name.')
param cephNode01PublicIpName string = '${cephNode01VmName}-pip'
@description('Ceph node 02 public IP name.')
param cephNode02PublicIpName string = '${cephNode02VmName}-pip'
@description('Ceph node 03 public IP name.')
param cephNode03PublicIpName string = '${cephNode03VmName}-pip'
@description('Ceph node 01 public NIC name.')
param cephNode01PublicNicName string = '${cephNode01VmName}-nic-public'
@description('Ceph node 02 public NIC name.')
param cephNode02PublicNicName string = '${cephNode02VmName}-nic-public'
@description('Ceph node 03 public NIC name.')
param cephNode03PublicNicName string = '${cephNode03VmName}-nic-public'
@description('Ceph node 01 cluster NIC name.')
param cephNode01ClusterNicName string = '${cephNode01VmName}-nic-cluster'
@description('Ceph node 02 cluster NIC name.')
param cephNode02ClusterNicName string = '${cephNode02VmName}-nic-cluster'
@description('Ceph node 03 cluster NIC name.')
param cephNode03ClusterNicName string = '${cephNode03VmName}-nic-cluster'
@description('Ceph node 01 public network private IP.')
param cephNode01PublicIp string = '10.10.10.10'
@description('Ceph node 02 public network private IP.')
param cephNode02PublicIp string = '10.10.10.11'
@description('Ceph node 03 public network private IP.')
param cephNode03PublicIp string = '10.10.10.12'
@description('Ceph node 01 cluster network private IP.')
param cephNode01ClusterIp string = '172.10.10.10'
@description('Ceph node 02 cluster network private IP.')
param cephNode02ClusterIp string = '172.10.10.11'
@description('Ceph node 03 cluster network private IP.')
param cephNode03ClusterIp string = '172.10.10.12'
@description('Data disk SKU for OSD disks.')
param dataDiskSku string = 'StandardSSD_LRS'
@description('Data disk size in GB for OSD disks.')
param dataDiskSizeGb int = 64

module network './modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    clusterAddressPrefix: clusterAddressPrefix
    publicSubnetName: publicSubnetName
    publicSubnetPrefix: publicSubnetPrefix
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
    publicSubnetPrefix: publicSubnetPrefix
    clusterSubnetPrefix: clusterSubnetPrefix
  }
}

module cephNode01Nic './modules/nic.bicep' = {
  name: 'cephNode01Nic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    publicSubnetId: network.outputs.publicSubnetId
    clusterSubnetId: network.outputs.clusterSubnetId
    publicNicName: cephNode01PublicNicName
    clusterNicName: cephNode01ClusterNicName
    publicIpName: cephNode01PublicIpName
    publicPrivateIp: cephNode01PublicIp
    clusterPrivateIp: cephNode01ClusterIp
  }
}

module cephNode02Nic './modules/nic.bicep' = {
  name: 'cephNode02Nic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    publicSubnetId: network.outputs.publicSubnetId
    clusterSubnetId: network.outputs.clusterSubnetId
    publicNicName: cephNode02PublicNicName
    clusterNicName: cephNode02ClusterNicName
    publicIpName: cephNode02PublicIpName
    publicPrivateIp: cephNode02PublicIp
    clusterPrivateIp: cephNode02ClusterIp
  }
}

module cephNode03Nic './modules/nic.bicep' = {
  name: 'cephNode03Nic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    publicSubnetId: network.outputs.publicSubnetId
    clusterSubnetId: network.outputs.clusterSubnetId
    publicNicName: cephNode03PublicNicName
    clusterNicName: cephNode03ClusterNicName
    publicIpName: cephNode03PublicIpName
    publicPrivateIp: cephNode03PublicIp
    clusterPrivateIp: cephNode03ClusterIp
  }
}

module cephNode01Vm './modules/vm.bicep' = {
  name: 'cephNode01Vm'
  params: {
    location: location
    vmName: cephNode01VmName
    nicIds: [
      cephNode01Nic.outputs.publicNicId
      cephNode01Nic.outputs.clusterNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: cephNode01VmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
  }
}

module cephNode02Vm './modules/vm.bicep' = {
  name: 'cephNode02Vm'
  params: {
    location: location
    vmName: cephNode02VmName
    nicIds: [
      cephNode02Nic.outputs.publicNicId
      cephNode02Nic.outputs.clusterNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: cephNode02VmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
  }
}

module cephNode03Vm './modules/vm.bicep' = {
  name: 'cephNode03Vm'
  params: {
    location: location
    vmName: cephNode03VmName
    nicIds: [
      cephNode03Nic.outputs.publicNicId
      cephNode03Nic.outputs.clusterNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: cephNode03VmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
    dataDiskSku: dataDiskSku
    dataDiskSizeGb: dataDiskSizeGb
  }
}

output targetResourceGroupName string = resourceGroup().name
output virtualNetworkId string = network.outputs.virtualNetworkId
output publicSubnetId string = network.outputs.publicSubnetId
output clusterSubnetId string = network.outputs.clusterSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
output cephNode01PublicNicId string = cephNode01Nic.outputs.publicNicId
output cephNode01ClusterNicId string = cephNode01Nic.outputs.clusterNicId
output cephNode02PublicNicId string = cephNode02Nic.outputs.publicNicId
output cephNode02ClusterNicId string = cephNode02Nic.outputs.clusterNicId
output cephNode03PublicNicId string = cephNode03Nic.outputs.publicNicId
output cephNode03ClusterNicId string = cephNode03Nic.outputs.clusterNicId
output cephNode01PublicAddress string = cephNode01Nic.outputs.publicIpAddress
output cephNode02PublicAddress string = cephNode02Nic.outputs.publicIpAddress
output cephNode03PublicAddress string = cephNode03Nic.outputs.publicIpAddress
output cephNodePublicAddresses array = [
  cephNode01Nic.outputs.publicIpAddress
  cephNode02Nic.outputs.publicIpAddress
  cephNode03Nic.outputs.publicIpAddress
]
output cephNodeClusterIps array = [
  cephNode01ClusterIp
  cephNode02ClusterIp
  cephNode03ClusterIp
]
output cephNode01VmId string = cephNode01Vm.outputs.vmId
output cephNode02VmId string = cephNode02Vm.outputs.vmId
output cephNode03VmId string = cephNode03Vm.outputs.vmId
output vmNames array = [
  cephNode01VmName
  cephNode02VmName
  cephNode03VmName
]
