targetScope = 'resourceGroup'

@description('Azure region for NIC and public IP resources.')
param location string
@description('Network security group resource ID shared by the NICs.')
param networkSecurityGroupId string
@description('Primary subnet resource ID.')
param subnetId string
@description('Primary NIC name.')
param nicName string
@description('Primary public IP name.')
param publicIpName string
@description('Primary private IP.')
param privateIp string
@description('Whether to create a secondary NIC.')
param createSecondaryNic bool = false
@description('Required when createSecondaryNic is true.')
param secondaryNicName string = 'unset'
@description('Required when createSecondaryNic is true.')
param secondarySubnetId string = 'unset'
@description('Required when createSecondaryNic is true.')
param secondaryPrivateIp string = 'unset'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  properties: {
    enableIPForwarding: false
    networkSecurityGroup: {
      id: networkSecurityGroupId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIp
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource secondaryNic 'Microsoft.Network/networkInterfaces@2023-11-01' = if (createSecondaryNic) {
  name: secondaryNicName
  location: location
  properties: {
    // Secondary NIC must forward traffic for the kubevirt workload.
    enableIPForwarding: true
    networkSecurityGroup: {
      id: networkSecurityGroupId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: secondaryPrivateIp
          subnet: {
            id: secondarySubnetId
          }
        }
      }
    ]
  }
}

output nicId string = nic.id
@description('Returns an empty string when createSecondaryNic is false.')
output secondaryNicId string = createSecondaryNic ? secondaryNic.id : ''
output publicIpAddress string = publicIp.properties.ipAddress
