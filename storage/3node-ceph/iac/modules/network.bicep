targetScope = 'resourceGroup'

@description('Shared virtual network name. This VNet is owned by the KubeVirt lab and consumed by the Ceph lab.')
param virtualNetworkName string
@description('Resource group that contains the shared VNet.')
param virtualNetworkResourceGroupName string
@description('Name of the shared node subnet that already exists in the shared VNet (e.g. shared-node-subnet, 10.10.10.0/24). Created by KubeVirt; referenced here as existing.')
param sharedNodeSubnetName string
@description('Name of the Ceph-dedicated cluster subnet to create inside the shared VNet (e.g. mansion-ceph-cluster-subnet, 172.10.10.0/24).')
param clusterSubnetName string
@description('CIDR for the Ceph cluster subnet.')
param clusterSubnetPrefix string

// Reference the existing shared VNet (owned by KubeVirt lab).
resource existingVNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroupName)
}

// Reference the existing shared node subnet (created by KubeVirt lab).
// Ceph public NICs attach to this subnet using IPs 10.10.10.21-23.
resource sharedNodeSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: existingVNet
  name: sharedNodeSubnetName
}

module clusterSubnetModule './cluster-subnet.bicep' = {
  name: 'clusterSubnetModule'
  scope: resourceGroup(virtualNetworkResourceGroupName)
  params: {
    virtualNetworkName: virtualNetworkName
    clusterSubnetName: clusterSubnetName
    clusterSubnetPrefix: clusterSubnetPrefix
  }
}

output virtualNetworkId string = existingVNet.id
output publicSubnetId string = sharedNodeSubnet.id
output clusterSubnetId string = clusterSubnetModule.outputs.clusterSubnetId
