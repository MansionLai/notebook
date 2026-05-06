targetScope = 'resourceGroup'

@description('Azure region for NIC and public IP resources.')
param location string
@description('Network security group resource ID shared by all NICs.')
param networkSecurityGroupId string
@description('Kubernetes subnet resource ID.')
param k8sSubnetId string
@description('KubeVirt subnet resource ID.')
param kubevirtSubnetId string

@description('Master NIC name.')
param masterNicName string
@description('Infra NIC name.')
param infraNicName string
@description('Worker primary NIC name.')
param workerNicName string
@description('Worker secondary NIC name.')
param workerSecondaryNicName string

@description('Master Public IP name.')
param masterPublicIpName string
@description('Infra Public IP name.')
param infraPublicIpName string
@description('Worker Public IP name.')
param workerPublicIpName string

@description('Master private IP.')
param masterPrivateIp string
@description('Infra private IP.')
param infraPrivateIp string
@description('Worker private IP.')
param workerPrivateIp string
@description('Worker secondary private IP.')
param workerSecondaryPrivateIp string

resource masterPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: masterPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource infraPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: infraPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource workerPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: workerPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource masterNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: masterNicName
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
          privateIPAddress: masterPrivateIp
          subnet: {
            id: k8sSubnetId
          }
          publicIPAddress: {
            id: masterPublicIp.id
          }
        }
      }
    ]
  }
}

resource infraNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: infraNicName
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
          privateIPAddress: infraPrivateIp
          subnet: {
            id: k8sSubnetId
          }
          publicIPAddress: {
            id: infraPublicIp.id
          }
        }
      }
    ]
  }
}

resource workerNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: workerNicName
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
          privateIPAddress: workerPrivateIp
          subnet: {
            id: k8sSubnetId
          }
          publicIPAddress: {
            id: workerPublicIp.id
          }
        }
      }
    ]
  }
}

resource workerSecondaryNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: workerSecondaryNicName
  location: location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: networkSecurityGroupId
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: workerSecondaryPrivateIp
          subnet: {
            id: kubevirtSubnetId
          }
        }
      }
    ]
  }
}

output masterNicId string = masterNic.id
output infraNicId string = infraNic.id
output workerNicId string = workerNic.id
output workerSecondaryNicId string = workerSecondaryNic.id

output masterPublicIpId string = masterPublicIp.id
output infraPublicIpId string = infraPublicIp.id
output workerPublicIpId string = workerPublicIp.id

output masterPublicIpAddress string = masterPublicIp.properties.ipAddress
output infraPublicIpAddress string = infraPublicIp.properties.ipAddress
output workerPublicIpAddress string = workerPublicIp.properties.ipAddress
