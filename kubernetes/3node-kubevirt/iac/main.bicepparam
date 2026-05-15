using './main.bicep'

param location = 'japaneast'
// Shared VNet — owned by KubeVirt lab, consumed by Ceph lab when it is provisioned.
param virtualNetworkName = 'mansion-shared-vnet'
// KubeVirt primary range: K8s nodes (10.10.10.x) and VM overlay (10.10.100.x).
param virtualNetworkAddressPrefix = '10.10.0.0/16'
// Ceph cluster subnet (172.10.10.0/24) lives in this range; declared from day one so the
// shared VNet already covers it when the Ceph lab is provisioned later.
param clusterAddressPrefix = '172.10.0.0/16'
// Shared node subnet: KubeVirt K8s nodes 10.10.10.10-12; Ceph nodes will use 10.10.10.20-22.
param k8sSubnetName = 'shared-node-subnet'
param k8sSubnetPrefix = '10.10.10.0/24'
// KubeVirt-exclusive secondary subnet for VM overlay traffic (Worker eth1).
param kubevirtSubnetName = 'kubevirt-subnet'
param kubevirtSubnetPrefix = '10.10.100.0/24'
param networkSecurityGroupName = 'k8s-nsg'
// Documentation placeholder; replace before deployment.
param allowedSourceCidr = '203.0.113.10/32'
param masterVmName = 'mansion-k8s-master'
param infraVmName = 'mansion-k8s-infra'
param workerVmName = 'mansion-k8s-worker'
param masterPublicIpName = 'mansion-k8s-master-pip'
param infraPublicIpName = 'mansion-k8s-infra-pip'
param workerPublicIpName = 'mansion-k8s-worker-pip'
param masterNicName = 'mansion-k8s-master-nic'
param infraNicName = 'mansion-k8s-infra-nic'
param workerNicName = 'mansion-k8s-worker-nic'
param workerSecondaryNicName = 'mansion-k8s-worker-nic2'
param masterPrivateIp = '10.10.10.10'
param infraPrivateIp = '10.10.10.11'
param workerPrivateIp = '10.10.10.12'
param workerSecondaryPrivateIp = '10.10.100.12'
param adminUsername = 'ubuntu'
param adminPublicKey = ''
param masterVmSize = 'Standard_D2s_v4'
param infraVmSize = 'Standard_D4s_v4'
param workerVmSize = 'Standard_D4s_v4'
param imagePublisher = 'Canonical'
param imageOffer = '0001-com-ubuntu-server-noble'
param imageSku = '24_04-lts-gen2'
param imageVersion = 'latest'
