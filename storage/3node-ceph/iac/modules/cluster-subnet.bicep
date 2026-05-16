targetScope = 'resourceGroup'

@description('Shared virtual network name where cluster subnet will be created.')
param virtualNetworkName string
@description('Ceph cluster subnet name.')
param clusterSubnetName string
@description('CIDR for the Ceph cluster subnet.')
param clusterSubnetPrefix string

resource existingVNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: virtualNetworkName
}

resource clusterSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: existingVNet
  name: clusterSubnetName
  properties: {
    addressPrefix: clusterSubnetPrefix
  }
}

output clusterSubnetId string = clusterSubnet.id
