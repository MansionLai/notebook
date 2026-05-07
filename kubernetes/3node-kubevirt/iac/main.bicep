targetScope = 'resourceGroup'

@description('Azure region for deployment.')
param location string = 'japaneast'
@description('Name of the virtual network.')
param virtualNetworkName string
@description('CIDR for the virtual network.')
param virtualNetworkAddressPrefix string
@description('Name of the Kubernetes subnet.')
param k8sSubnetName string
@description('CIDR for the Kubernetes subnet.')
param k8sSubnetPrefix string
@description('Name of the KubeVirt subnet.')
param kubevirtSubnetName string
@description('CIDR for the KubeVirt subnet.')
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

module network './modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressPrefix: virtualNetworkAddressPrefix
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
