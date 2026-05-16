targetScope = 'resourceGroup'

@description('Azure region for deployment.')
param location string = 'japaneast'
@description('Name of the shared virtual network (in mansion-shared-resource).')
param sharedVnetName string = 'mansion-shared-vnet'
@description('Resource group containing the shared VNet.')
param sharedVnetResourceGroup string = 'mansion-shared-resource'
@description('Name of the new K8s node subnet.')
param k8sSubnetName string = 'mansion_kubevirt_node_subnet'
@description('CIDR for the K8s node subnet.')
param k8sSubnetPrefix string = '10.10.11.0/24'
@description('Name of the subnet for VM overlay traffic (Worker eth1).')
param kubevirtSubnetName string = 'mansion_kubevirt_vm_subnet'
@description('CIDR for the VM overlay subnet.')
param kubevirtSubnetPrefix string = '10.10.100.0/24'
@description('Name of the network security group.')
param networkSecurityGroupName string = 'mansion_kubevirt_nsg'
@description('Trusted source CIDR for inbound rules.')
param allowedSourceCidr string
@description('Master VM name.')
param masterVmName string
@description('Infra VM name.')
param infraVmName string
@description('Worker VM name.')
param workerVmName string
@description('Master public IP name.')
param masterPublicIpName string = '${masterVmName}-pip'
@description('Infra public IP name.')
param infraPublicIpName string = '${infraVmName}-pip'
@description('Worker public IP name.')
param workerPublicIpName string = '${workerVmName}-pip'
@description('Master NIC name.')
param masterNicName string = '${masterVmName}-nic'
@description('Infra NIC name.')
param infraNicName string = '${infraVmName}-nic'
@description('Worker primary NIC name.')
param workerNicName string = '${workerVmName}-nic'
@description('Worker secondary NIC name.')
param workerSecondaryNicName string = '${workerVmName}-nic2'
@description('Master private IP.')
param masterPrivateIp string = '10.10.11.11'
@description('Infra private IP.')
param infraPrivateIp string = '10.10.11.12'
@description('Worker private IP.')
param workerPrivateIp string = '10.10.11.13'
@description('Worker secondary private IP.')
param workerSecondaryPrivateIp string = '10.10.100.13'
@description('Administrator username for the Linux VMs.')
param adminUsername string = 'ubuntu'
@description('SSH public key content for the Linux VM admin user.')
param adminPublicKey string
@description('Master VM size.')
param masterVmSize string = 'Standard_D2s_v4'
@description('Infra VM size.')
param infraVmSize string = 'Standard_D4s_v4'
@description('Worker VM size.')
param workerVmSize string = 'Standard_D4s_v4'
@description('Ubuntu image publisher.')
param imagePublisher string = 'Canonical'
@description('Ubuntu image offer.')
param imageOffer string = '0001-com-ubuntu-server-jammy'
@description('Ubuntu image SKU.')
param imageSku string = '22_04-lts-gen2'
@description('Ubuntu image version.')
param imageVersion string = 'latest'

// Create K8s subnet in shared VNet using module (deployed to shared RG scope)
module k8sSubnetModule './modules/subnet.bicep' = {
  scope: resourceGroup(sharedVnetResourceGroup)
  name: 'k8sSubnet'
  params: {
    vnetName: sharedVnetName
    subnetName: k8sSubnetName
    subnetPrefix: k8sSubnetPrefix
    nsgId: nsg.outputs.networkSecurityGroupId
  }
}

// Create KubeVirt subnet in shared VNet using module
module kubevirtSubnetModule './modules/subnet.bicep' = {
  scope: resourceGroup(sharedVnetResourceGroup)
  name: 'kubevirtSubnet'
  params: {
    vnetName: sharedVnetName
    subnetName: kubevirtSubnetName
    subnetPrefix: kubevirtSubnetPrefix
    nsgId: '' // KubeVirt subnet doesn't need NSG (only primary subnet does)
  }
}

module nsg './modules/nsg.bicep' = {
  name: 'nsg'
  params: {
    location: location
    networkSecurityGroupName: networkSecurityGroupName
    allowedSourceCidr: allowedSourceCidr
    internalSourceCidr: '10.10.0.0/16'
  }
}

module masterNic './modules/nic.bicep' = {
  name: 'masterNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: k8sSubnetModule.outputs.subnetId
    nicName: masterNicName
    publicIpName: masterPublicIpName
    privateIp: masterPrivateIp
  }
}

module infraNic './modules/nic.bicep' = {
  name: 'infraNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: k8sSubnetModule.outputs.subnetId
    nicName: infraNicName
    publicIpName: infraPublicIpName
    privateIp: infraPrivateIp
  }
}

module workerNic './modules/nic.bicep' = {
  name: 'workerNic'
  params: {
    location: location
    networkSecurityGroupId: nsg.outputs.networkSecurityGroupId
    subnetId: k8sSubnetModule.outputs.subnetId
    nicName: workerNicName
    publicIpName: workerPublicIpName
    privateIp: workerPrivateIp
    createSecondaryNic: true
    secondaryNicName: workerSecondaryNicName
    secondarySubnetId: kubevirtSubnetModule.outputs.subnetId
    secondaryPrivateIp: workerSecondaryPrivateIp
  }
}

module masterVm './modules/vm.bicep' = {
  name: 'masterVm'
  params: {
    location: location
    vmName: masterVmName
    nicIds: [
      masterNic.outputs.nicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: masterVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

module infraVm './modules/vm.bicep' = {
  name: 'infraVm'
  params: {
    location: location
    vmName: infraVmName
    nicIds: [
      infraNic.outputs.nicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: infraVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

module workerVm './modules/vm.bicep' = {
  name: 'workerVm'
  params: {
    location: location
    vmName: workerVmName
    nicIds: [
      workerNic.outputs.nicId
      workerNic.outputs.secondaryNicId
    ]
    adminUsername: adminUsername
    adminPublicKey: adminPublicKey
    vmSize: workerVmSize
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    imageVersion: imageVersion
  }
}

output targetResourceGroupName string = resourceGroup().name
output k8sSubnetId string = k8sSubnetModule.outputs.subnetId
output kubevirtSubnetId string = kubevirtSubnetModule.outputs.subnetId
output networkSecurityGroupId string = nsg.outputs.networkSecurityGroupId
