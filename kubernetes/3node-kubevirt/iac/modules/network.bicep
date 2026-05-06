targetScope = 'resourceGroup'

param location string
param virtualNetworkName string
param virtualNetworkAddressPrefix string
param k8sSubnetName string
param k8sSubnetPrefix string
param kubevirtSubnetName string
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
