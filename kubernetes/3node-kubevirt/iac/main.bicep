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

// NSG is created here and later attached to NICs in Task 2.
output targetResourceGroupName string = resourceGroup().name
output virtualNetworkId string = network.outputs.virtualNetworkId
output k8sSubnetId string = network.outputs.k8sSubnetId
output kubevirtSubnetId string = network.outputs.kubevirtSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
