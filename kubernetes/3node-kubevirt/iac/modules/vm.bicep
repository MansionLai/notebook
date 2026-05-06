targetScope = 'resourceGroup'

@description('Azure region for the VMs.')
param location string
@description('Admin username for all VMs.')
param adminUsername string
@description('Admin SSH public key for all VMs.')
param adminPublicKey string

@description('Master VM name.')
param masterVmName string
@description('Infra VM name.')
param infraVmName string
@description('Worker VM name.')
param workerVmName string

@description('Master VM size.')
param masterVmSize string
@description('Infra VM size.')
param infraVmSize string
@description('Worker VM size.')
param workerVmSize string

@description('Master NIC resource ID.')
param masterNicId string
@description('Infra NIC resource ID.')
param infraNicId string
@description('Worker primary NIC resource ID.')
param workerNicId string
@description('Worker secondary NIC resource ID.')
param workerSecondaryNicId string

var ubuntuImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-noble'
  sku: '24_04-lts-gen2'
  version: 'latest'
}

resource masterVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: masterVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: masterVmSize
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: masterVmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
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
      networkInterfaces: [
        {
          id: masterNicId
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource infraVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: infraVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: infraVmSize
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: infraVmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
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
      networkInterfaces: [
        {
          id: infraNicId
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource workerVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: workerVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: workerVmSize
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: workerVmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
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
      networkInterfaces: [
        {
          id: workerNicId
          properties: {
            primary: true
          }
        }
        {
          id: workerSecondaryNicId
          properties: {
            primary: false
          }
        }
      ]
    }
  }
}

output masterVmId string = masterVm.id
output infraVmId string = infraVm.id
output workerVmId string = workerVm.id
