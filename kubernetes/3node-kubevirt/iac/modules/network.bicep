targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string
@description('mansion_kubevirt virtual network name.')
param virtualNetworkName string
@description('Virtual network primary address range (e.g. 10.10.0.0/16).')
param virtualNetworkAddressPrefix string
@description('Virtual network secondary address range (e.g. 172.10.0.0/16). Required to cover the ceph subnet declared below.')
param clusterAddressPrefix string
@description('mansion_kubevirt node subnet name (10.10.10.0/24).')
param k8sSubnetName string
@description('Node subnet range (10.10.10.0/24).')
param k8sSubnetPrefix string
@description('Secondary subnet name for VM overlay traffic (Worker eth1).')
param kubevirtSubnetName string
@description('VM overlay subnet range (10.10.100.0/24).')
param kubevirtSubnetPrefix string
@description('Ceph subnet name retained in this VNet so ARM PUT semantics never delete it on redeployment.')
param cephClusterSubnetName string
@description('CIDR for the ceph subnet (must be within clusterAddressPrefix, e.g. 172.10.10.0/24).')
param cephClusterSubnetPrefix string

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
      // mansion_kubevirt_ceph_subnet is retained in this VNet declaration so that ARM PUT semantics
      // on every redeployment never delete it.
      {
        name: cephClusterSubnetName
        properties: {
          addressPrefix: cephClusterSubnetPrefix
        }
      }
    ]
  }
}

output virtualNetworkId string = virtualNetwork.id
output k8sSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, k8sSubnetName)
output kubevirtSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, kubevirtSubnetName)
output cephClusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, cephClusterSubnetName)
