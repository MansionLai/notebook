targetScope = 'resourceGroup'

@description('Azure region for NIC and public IP resources.')
param location string
@description('Network security group resource ID shared by the NICs.')
param networkSecurityGroupId string
@description('Public subnet resource ID.')
param publicSubnetId string
@description('Cluster subnet resource ID.')
param clusterSubnetId string
@description('Public NIC name.')
param publicNicName string
@description('Cluster NIC name.')
param clusterNicName string
@description('Public IP name.')
param publicIpName string
@description('Public network private IP.')
param publicPrivateIp string
@description('Cluster network private IP.')
param clusterPrivateIp string

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

resource publicNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: publicNicName
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
          privateIPAddress: publicPrivateIp
          subnet: {
            id: publicSubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource clusterNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: clusterNicName
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
          privateIPAddress: clusterPrivateIp
          subnet: {
            id: clusterSubnetId
          }
        }
      }
    ]
  }
}

output publicNicId string = publicNic.id
output clusterNicId string = clusterNic.id
output publicIpAddress string = publicIp.properties.ipAddress
