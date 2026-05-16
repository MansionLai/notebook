targetScope = 'resourceGroup'

@description('Name of the VNet.')
param vnetName string
@description('Name of the subnet.')
param subnetName string
@description('Address prefix for the subnet.')
param subnetPrefix string
@description('NSG resource ID (optional).')
param nsgId string = ''

// Reference the VNet in the current scope (will be called from shared RG context)
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

// Create subnet as child of the VNet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetPrefix
    networkSecurityGroup: empty(nsgId) ? null : { id: nsgId }
  }
}

output subnetId string = subnet.id
