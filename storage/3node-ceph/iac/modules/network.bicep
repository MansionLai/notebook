targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string
@description('Virtual network name.')
param virtualNetworkName string
@description('Virtual network address range.')
param virtualNetworkAddressPrefix string
@description('Cluster address space range for the virtual network.')
param clusterAddressPrefix string
@description('Public subnet name.')
param publicSubnetName string
@description('Public subnet range.')
param publicSubnetPrefix string
@description('Cluster subnet name.')
param clusterSubnetName string
@description('Cluster subnet range.')
param clusterSubnetPrefix string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
        clusterAddressPrefix
      ]
    }
    subnets: [
      {
        name: publicSubnetName
        properties: {
          addressPrefix: publicSubnetPrefix
        }
      }
      {
        name: clusterSubnetName
        properties: {
          addressPrefix: clusterSubnetPrefix
        }
      }
    ]
  }
}

output virtualNetworkId string = virtualNetwork.id
output publicSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, publicSubnetName)
output clusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, clusterSubnetName)
