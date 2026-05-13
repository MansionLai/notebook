targetScope = 'resourceGroup'

@description('Azure region for the NSG.')
param location string
@description('Network security group name.')
param networkSecurityGroupName string
@description('External source CIDR allowed in.')
param allowedSourceCidr string
@description('Public subnet prefix for internal traffic rules.')
param publicSubnetPrefix string
@description('Cluster subnet prefix for internal traffic rules.')
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
        name: 'AllowPublicSubnetTraffic'
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
        name: 'AllowClusterSubnetTraffic'
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
