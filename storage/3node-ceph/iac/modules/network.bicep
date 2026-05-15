targetScope = 'resourceGroup'

@description('Shared virtual network name. This VNet is owned by the KubeVirt lab and consumed by the Ceph lab.')
param virtualNetworkName string
@description('Name of the shared node subnet that already exists in the shared VNet (e.g. shared-node-subnet, 10.10.10.0/24). Created by KubeVirt; referenced here as existing.')
param sharedNodeSubnetName string
@description('Name of the Ceph-dedicated cluster subnet to create inside the shared VNet (e.g. ceph-cluster-subnet, 172.10.10.0/24).')
param clusterSubnetName string
@description('CIDR for the Ceph cluster subnet.')
param clusterSubnetPrefix string

// Reference the existing shared VNet (owned by KubeVirt lab).
resource existingVNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: virtualNetworkName
}

// Reference the existing shared node subnet (created by KubeVirt lab).
// Ceph public NICs attach to this subnet using IPs 10.10.10.20-22.
resource sharedNodeSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: existingVNet
  name: sharedNodeSubnetName
}

// Create the Ceph-dedicated cluster subnet inside the shared VNet.
// The 172.10.0.0/16 address space was pre-declared by the KubeVirt VNet deployment
// so this subnet can be added without any destructive VNet address-space update.
resource clusterSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: existingVNet
  name: clusterSubnetName
  properties: {
    addressPrefix: clusterSubnetPrefix
  }
}

output virtualNetworkId string = existingVNet.id
output publicSubnetId string = sharedNodeSubnet.id
output clusterSubnetId string = clusterSubnet.id
