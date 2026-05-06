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
@description('Admin username for the Azure VMs.')
param adminUsername string
@description('Admin SSH public key for the Azure VMs.')
@secure()
param adminPublicKey string
@description('Master VM name.')
param masterVmName string
@description('Infra VM name.')
param infraVmName string
@description('Worker VM name.')
param workerVmName string
@description('Master VM size.')
param masterVmSize string
@description('Infra VM size.')
param infraVmSize string
@description('Worker VM size.')
param workerVmSize string
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

var masterNicName = '${masterVmName}-nic'
var infraNicName = '${infraVmName}-nic'
var workerNicName = '${workerVmName}-nic'
var workerSecondaryNicName = '${workerVmName}-nic2'
var masterPublicIpName = '${masterVmName}-pip'
var infraPublicIpName = '${infraVmName}-pip'
var workerPublicIpName = '${workerVmName}-pip'

module nic './modules/nic.bicep' = {
  name: 'nic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    k8sSubnetId: network.outputs.k8sSubnetId
    kubevirtSubnetId: network.outputs.kubevirtSubnetId
    masterNicName: masterNicName
    infraNicName: infraNicName
    workerNicName: workerNicName
    workerSecondaryNicName: workerSecondaryNicName
    masterPublicIpName: masterPublicIpName
    infraPublicIpName: infraPublicIpName
    workerPublicIpName: workerPublicIpName
    masterPrivateIp: masterPrivateIp
    infraPrivateIp: infraPrivateIp
    workerPrivateIp: workerPrivateIp
    workerSecondaryPrivateIp: workerSecondaryPrivateIp
  }
}

module vm './modules/vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    masterVmName: masterVmName
    infraVmName: infraVmName
    workerVmName: workerVmName
    masterVmSize: masterVmSize
    infraVmSize: infraVmSize
    workerVmSize: workerVmSize
    masterNicId: nic.outputs.masterNicId
    infraNicId: nic.outputs.infraNicId
    workerNicId: nic.outputs.workerNicId
    workerSecondaryNicId: nic.outputs.workerSecondaryNicId
  }
}

output targetResourceGroupName string = resourceGroup().name
output virtualNetworkId string = network.outputs.virtualNetworkId
output k8sSubnetId string = network.outputs.k8sSubnetId
output kubevirtSubnetId string = network.outputs.kubevirtSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
output masterNicId string = nic.outputs.masterNicId
output infraNicId string = nic.outputs.infraNicId
output workerNicId string = nic.outputs.workerNicId
output workerSecondaryNicId string = nic.outputs.workerSecondaryNicId
output masterVmId string = vm.outputs.masterVmId
output infraVmId string = vm.outputs.infraVmId
output workerVmId string = vm.outputs.workerVmId
output masterPrivateIpAddress string = masterPrivateIp
output infraPrivateIpAddress string = infraPrivateIp
output workerPrivateIpAddress string = workerPrivateIp
output workerSecondaryPrivateIpAddress string = workerSecondaryPrivateIp
output masterPublicIpAddress string = nic.outputs.masterPublicIpAddress
output infraPublicIpAddress string = nic.outputs.infraPublicIpAddress
output workerPublicIpAddress string = nic.outputs.workerPublicIpAddress
