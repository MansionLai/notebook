targetScope = 'resourceGroup'

@description('Azure region for the NSG.')
param location string
@description('Network security group name.')
param networkSecurityGroupName string
@description('External source CIDR allowed in.')
param allowedSourceCidr string
@description('Internal source CIDR allowed in.')
param internalSourceCidr string

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
        name: 'AllowKubernetesApi'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefix: allowedSourceCidr
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowNodePort'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '30000-32767'
          sourceAddressPrefix: allowedSourceCidr
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowInternalTraffic'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: internalSourceCidr
          destinationAddressPrefix: internalSourceCidr
        }
      }
    ]
  }
}

output networkSecurityGroupId string = networkSecurityGroup.id
