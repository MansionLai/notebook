targetScope = 'resourceGroup'

@description('Azure region for deployment.')
param location string = 'japaneast'
@description('Name of the shared virtual network (owned by KubeVirt lab; also consumed by Ceph lab).')
param virtualNetworkName string
@description('CIDR for the shared virtual network (KubeVirt side, e.g. 10.10.0.0/16).')
param virtualNetworkAddressPrefix string
@description('Second CIDR for the shared virtual network address space (e.g. 172.10.0.0/16). Required from day one so the Ceph cluster subnet (172.10.10.0/24) can later exist within the same shared VNet without a destructive VNet update.')
param clusterAddressPrefix string
@description('Name of the shared node subnet (10.10.10.0/24). KubeVirt K8s nodes use .10-.12; Ceph nodes will later use .20-.22.')
param k8sSubnetName string
@description('CIDR for the shared node subnet.')
param k8sSubnetPrefix string
@description('Name of the KubeVirt-exclusive secondary subnet for VM overlay traffic (Worker eth1).')
param kubevirtSubnetName string
@description('CIDR for the KubeVirt secondary subnet.')
param kubevirtSubnetPrefix string
@description('Name of the network security group.')
param networkSecurityGroupName string
@description('Trusted source CIDR for inbound rules.')
param allowedSourceCidr string
@description('Master VM name.')
param masterVmName string
@description('Infra VM name.')
param infraVmName string
@description('Worker VM name.')
param workerVmName string
@description('Master public IP name.')
param masterPublicIpName string = '${masterVmName}-pip'
@description('Infra public IP name.')
param infraPublicIpName string = '${infraVmName}-pip'
@description('Worker public IP name.')
param workerPublicIpName string = '${workerVmName}-pip'
@description('Master NIC name.')
param masterNicName string = '${masterVmName}-nic'
@description('Infra NIC name.')
param infraNicName string = '${infraVmName}-nic'
@description('Worker primary NIC name.')
param workerNicName string = '${workerVmName}-nic'
@description('Worker secondary NIC name.')
param workerSecondaryNicName string = '${workerVmName}-nic2'
@description('Master private IP.')
param masterPrivateIp string = '10.10.10.10'
@description('Infra private IP.')
param infraPrivateIp string = '10.10.10.11'
@description('Worker private IP.')
param workerPrivateIp string = '10.10.10.12'
@description('Worker secondary private IP.')
param workerSecondaryPrivateIp string = '10.10.100.12'
@description('Administrator username for the Linux VMs.')
param adminUsername string = 'ubuntu'
@description('SSH public key content for the Linux VM admin user.')
param adminPublicKey string
@description('Master VM size.')
param masterVmSize string = 'Standard_D2s_v5'
@description('Infra VM size.')
param infraVmSize string = 'Standard_D4s_v5'
@description('Worker VM size.')
param workerVmSize string = 'Standard_D4s_v5'
@description('Ubuntu image publisher.')
param imagePublisher string = 'Canonical'
@description('Ubuntu image offer.')
param imageOffer string = '0001-com-ubuntu-server-noble'
@description('Ubuntu image SKU.')
param imageSku string = '24_04-lts-gen2'
@description('Ubuntu image version.')
param imageVersion string = 'latest'

module network './modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
    clusterAddressPrefix: clusterAddressPrefix
    k8sSubnetName: k8sSubnetName
    k8sSubnetPrefix: k8sSubnetPrefix
    kubevirtSubnetName: kubevirtSubnetName
    kubevirtSubnetPrefix: kubevirtSubnetPrefix
  }
}

module nsg './modules/nsg.bicep' = {
  name: 'nsg'
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupName
    allowedSourceCidr: allowedSourceCidr
    internalSourceCidr: virtualNetworkAddressPrefix
  }
}

module masterNic './modules/nic.bicep' = {
  name: 'masterNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: network.outputs.k8sSubnetId
    nicName: masterNicName
    publicIpName: masterPublicIpName
    privateIp: masterPrivateIp
  }
}

module infraNic './modules/nic.bicep' = {
  name: 'infraNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: network.outputs.k8sSubnetId
    nicName: infraNicName
    publicIpName: infraPublicIpName
    privateIp: infraPrivateIp
  }
}

module workerNic './modules/nic.bicep' = {
  name: 'workerNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: network.outputs.k8sSubnetId
    nicName: workerNicName
    publicIpName: workerPublicIpName
    privateIp: workerPrivateIp
    createSecondaryNic: true
    secondaryNicName: workerSecondaryNicName
    secondarySubnetId: network.outputs.kubevirtSubnetId
    secondaryPrivateIp: workerSecondaryPrivateIp
  }
}

module masterVm './modules/vm.bicep' = {
  name: 'masterVm'
  params: {
    location: location
    vmName: masterVmName
    nicIds: [
      masterNic.outputs.nicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: masterVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

module infraVm './modules/vm.bicep' = {
  name: 'infraVm'
  params: {
    location: location
    vmName: infraVmName
    nicIds: [
      infraNic.outputs.nicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: infraVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

module workerVm './modules/vm.bicep' = {
  name: 'workerVm'
  params: {
    location: location
    vmName: workerVmName
    nicIds: [
      workerNic.outputs.nicId
      workerNic.outputs.secondaryNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: workerVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

output targetResourceGroupName string = resourceGroup().name
output virtualNetworkId string = network.outputs.virtualNetworkId
output k8sSubnetId string = network.outputs.k8sSubnetId
output kubevirtSubnetId string = network.outputs.kubevirtSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
output masterNicId string = masterNic.outputs.nicId
output infraNicId string = infraNic.outputs.nicId
output workerNicId string = workerNic.outputs.nicId
output workerSecondaryNicId string = workerNic.outputs.secondaryNicId
output masterPrivateIpAddress string = masterPrivateIp
output infraPrivateIpAddress string = infraPrivateIp
output workerPrivateIpAddress string = workerPrivateIp
output workerSecondaryPrivateIpAddress string = workerSecondaryPrivateIp
output masterPublicIpAddress string = masterNic.outputs.publicIpAddress
output infraPublicIpAddress string = infraNic.outputs.publicIpAddress
output workerPublicIpAddress string = workerNic.outputs.publicIpAddress
output masterVmId string = masterVm.outputs.vmId
output infraVmId string = infraVm.outputs.vmId
output workerVmId string = workerVm.outputs.vmId
output vmNames array = [
  masterVmName
  infraVmName
  workerVmName
]
output vmPrivateIps array = [
  masterPrivateIp
  infraPrivateIp
  workerPrivateIp
]
output publicIpAddresses array = [
  masterNic.outputs.publicIpAddress
  infraNic.outputs.publicIpAddress
  workerNic.outputs.publicIpAddress
]
