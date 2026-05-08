targetScope = 'resourceGroup'

@description('Azure region for the VM.')
param location string
@description('Virtual machine name.')
param vmName string
@description('NIC resource IDs attached to the VM. The first NIC is primary.')
param nicIds array
@description('Administrator username for the Linux VM.')
param adminUsername string = 'ubuntu'
@description('SSH public key content for the Linux VM admin user.')
@secure()
param adminPublicKey string
@description('Azure Marketplace image publisher.')
param imagePublisher string
@description('Azure Marketplace image offer.')
param imageOffer string
@description('Azure Marketplace image SKU.')
param imageSku string
@description('Azure Marketplace image version.')
param imageVersion string = 'latest'
@description('VM size.')
param vmSize string

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [for (nicId, index) in nicIds: {
        id: nicId
        properties: {
          primary: index == 0
          deleteOption: 'Delete'
        }
      }]
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
