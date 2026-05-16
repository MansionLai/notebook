using './main.bicep'

// Deploy to resource group: mansion_kubevirt_resource
param location = 'japaneast'
// mansion_kubevirt VNet — K8s nodes (10.10.10.x) and VM overlay (10.10.100.x).
param virtualNetworkName = 'mansion_kubevirt_vnet'
// Primary address range: K8s nodes and VM overlay traffic.
param virtualNetworkAddressPrefix = '10.10.0.0/16'
// Secondary address range reserved for the ceph subnet declared below (ARM PUT safety).
param clusterAddressPrefix = '172.10.0.0/16'
// mansion_kubevirt node subnet: K8s nodes 10.10.10.11 (master), .12 (infra), .13 (worker).
param k8sSubnetName = 'mansion_kubevirt_node_subnet'
param k8sSubnetPrefix = '10.10.10.0/24'
// Secondary subnet for VM overlay traffic (Worker eth1 / KubeVirt VMs).
param kubevirtSubnetName = 'mansion_kubevirt_vm_subnet'
param kubevirtSubnetPrefix = '10.10.100.0/24'
// Retained in VNet declaration so ARM PUT on VNet redeployment never deletes it.
param cephClusterSubnetName = 'mansion_kubevirt_ceph_subnet'
param cephClusterSubnetPrefix = '172.10.10.0/24'
param networkSecurityGroupName = 'mansion_kubevirt_nsg'
// Documentation placeholder; replace before deployment.
param allowedSourceCidr = '203.0.113.10/32'
param masterVmName = 'mansion_kubevirt_master'
param infraVmName = 'mansion_kubevirt_infra'
param workerVmName = 'mansion_kubevirt_worker'
param masterPublicIpName = 'mansion_kubevirt_master_pip'
param infraPublicIpName = 'mansion_kubevirt_infra_pip'
param workerPublicIpName = 'mansion_kubevirt_worker_pip'
param masterNicName = 'mansion_kubevirt_master_nic'
param infraNicName = 'mansion_kubevirt_infra_nic'
param workerNicName = 'mansion_kubevirt_worker_nic'
param workerSecondaryNicName = 'mansion_kubevirt_worker_nic2'
param masterPrivateIp = '10.10.10.11'
param infraPrivateIp = '10.10.10.12'
param workerPrivateIp = '10.10.10.13'
param workerSecondaryPrivateIp = '10.10.100.13'
param adminUsername = 'ubuntu'
param adminPublicKey = ''
param masterVmSize = 'Standard_D2s_v4'
param infraVmSize = 'Standard_D4s_v4'
param workerVmSize = 'Standard_D4s_v4'
param imagePublisher = 'Canonical'
param imageOffer = '0001-com-ubuntu-server-jammy'
param imageSku = '22_04-lts-gen2'
param imageVersion = 'latest'
