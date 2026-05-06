targetScope = 'resourceGroup'

param location string = 'Japan East'
param resourceGroupName string
param virtualNetworkName string
param virtualNetworkAddressPrefix string
param k8sSubnetName string
param k8sSubnetPrefix string
param kubevirtSubnetName string
param kubevirtSubnetPrefix string
param networkSecurityGroupName string

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
  }
}

output targetResourceGroupName string = resourceGroupName
output virtualNetworkId string = network.outputs.virtualNetworkId
output k8sSubnetId string = network.outputs.k8sSubnetId
output kubevirtSubnetId string = network.outputs.kubevirtSubnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
