targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string
@description('Shared virtual network name. This VNet is created by the KubeVirt lab and shared with the Ceph lab.')
param virtualNetworkName string
@description('Virtual network address range.')
param virtualNetworkAddressPrefix string
@description('Shared node subnet name. KubeVirt K8s nodes use 10.10.10.10-12; Ceph nodes will later use 10.10.10.20-22.')
param k8sSubnetName string
@description('Shared node subnet range (10.10.10.0/24).')
param k8sSubnetPrefix string
@description('KubeVirt-exclusive secondary subnet name for VM overlay traffic (Worker eth1).')
param kubevirtSubnetName string
@description('KubeVirt secondary subnet range (10.10.100.0/24).')
param kubevirtSubnetPrefix string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: k8sSubnetName
        properties: {
          addressPrefix: k8sSubnetPrefix
        }
      }
      {
        name: kubevirtSubnetName
        properties: {
          addressPrefix: kubevirtSubnetPrefix
        }
      }
    ]
  }
}

output virtualNetworkId string = virtualNetwork.id
output k8sSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, k8sSubnetName)
output kubevirtSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, kubevirtSubnetName)
