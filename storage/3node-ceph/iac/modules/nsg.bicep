targetScope = 'resourceGroup'

@description('Azure region for the NSG.')
param location string
@description('Network security group name.')
param networkSecurityGroupName string
@description('External source CIDR allowed in.')
param allowedSourceCidr string
@description('Shared node subnet prefix for internal east-west traffic rules (10.10.10.0/24).')
param publicSubnetPrefix string
@description('Ceph cluster subnet prefix for internal replication traffic rules (172.10.10.0/24).')
param clusterSubnetPrefix string

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSourceCidr
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowMCP8000'
        properties: {
          priority: 210
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8000'
          sourceAddressPrefix: allowedSourceCidr
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowSharedNodeSubnetTraffic'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: publicSubnetPrefix
          destinationAddressPrefix: publicSubnetPrefix
        }
      }
      {
        name: 'AllowCephClusterSubnetTraffic'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: clusterSubnetPrefix
          destinationAddressPrefix: clusterSubnetPrefix
        }
      }
    ]
  }
}

output networkSecurityGroupId string = networkSecurityGroup.id
