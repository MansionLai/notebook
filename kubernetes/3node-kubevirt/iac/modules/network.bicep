targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string
@description('Virtual network name.')
param virtualNetworkName string
@description('Virtual network address range.')
param virtualNetworkAddressPrefix string
@description('Kubernetes subnet name.')
param k8sSubnetName string
@description('Kubernetes subnet range.')
param k8sSubnetPrefix string
@description('KubeVirt subnet name.')
param kubevirtSubnetName string
@description('KubeVirt subnet range.')
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
