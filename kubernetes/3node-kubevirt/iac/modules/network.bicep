targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string
@description('Shared virtual network name. This VNet is created by the KubeVirt lab and shared with the Ceph lab.')
param virtualNetworkName string
@description('Virtual network primary address range (KubeVirt nodes/overlay, e.g. 10.10.0.0/16).')
param virtualNetworkAddressPrefix string
@description('Virtual network secondary address range for the Ceph cluster subnet (e.g. 172.10.0.0/16). Must be declared from day one so the Ceph cluster subnet 172.10.10.0/24 can exist within the same shared VNet.')
param clusterAddressPrefix string
@description('Shared node subnet name. KubeVirt K8s nodes use 10.10.10.10-12; Ceph nodes will later use 10.10.10.20-22.')
param k8sSubnetName string
@description('Shared node subnet range (10.10.10.0/24).')
param k8sSubnetPrefix string
@description('KubeVirt-exclusive secondary subnet name for VM overlay traffic (Worker eth1).')
param kubevirtSubnetName string
@description('KubeVirt secondary subnet range (10.10.100.0/24).')
param kubevirtSubnetPrefix string
@description('Ceph-dedicated cluster subnet name inside this VNet (e.g. ceph-cluster-subnet, 172.10.10.0/24). Declared here — and kept in every KubeVirt redeploy — so that ARM PUT semantics on the VNet resource never delete it.')
param cephClusterSubnetName string
@description('CIDR for the Ceph cluster subnet (must be within clusterAddressPrefix, e.g. 172.10.10.0/24).')
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
      // ceph-cluster-subnet is owned by KubeVirt (the VNet owner) to prevent ARM PUT semantics
      // from deleting it on every KubeVirt redeploy. The Ceph side references this subnet as
      // existing rather than re-creating it.
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
