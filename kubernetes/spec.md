AI agent 運行在我的mac mini上, 並且協助我一起維護 notebook-sync repo, agent主要focus on kubernetes這個folder.
AI agent 使用 ai/k8s branch進行修正, 確認沒問題後再merge回main branch
AI agent 請盡可能使用azure mcp來操作azure, 非必要不要使用az command

1. 3node-kubevirt
   - 透過azure cloud建立vm
     - resource group name = mansion-kubevirt-resource
     - 所有相關的resource name都幫我加上mansion-kubevirt prefix作為識別
     - 如果是需要跟其他resource共用的物件, 請放在mansion-shared-resource下 (ex. mansion-shared-vnet)
   - VM Spec
     - 透過azure cloud建立三台 ubuntu 22.04 vm, 分別是master node, infra node 以及worker node
     - 用以學習k8s & kubevirt installation + kubevirt vm provision
     - all node os ip segment = 10.10.10.0/24
     - worker node額外有一張網卡 for kubevirt vmnet專用 (multus), kubevirt vm ip segment = 10.10.100.0/24
     - azure vm的user name = ubuntu, 不使用密碼ssh登入, 直接使用我mac mini上的 ssh key.
     - Master node
       - Standard_D2s_v4 (2C/8G)
       - ip: 10.10.10.11/24
       - 承載 K8s 控制面.
     - Infra node
       - Standard_D4s_v4 (4C/16G)
       - ip: 10.10.10.12/24
       - 同時承載基礎設施服務與 KubeVirt control plane.
     - Worker node
       - Standard_D4s_v4 (4C/16G)
       - ip: 10.10.10.13/24
       - 負責 virt-handler、virt-launcher 與 VM workload
   - Installation guide
     - kubenetes version = v1.31
     - container runtime = cri-o
     - cni = cilium
     - 透過rook-ceph(v1.17)建立storageclass, volumesnapshotclass, 連線我自建的ceph cluster
     - 需要安裝prometheus & alertmanager (on infra node)
     - 需要安裝grafana dashboard串接prometheus (on infra node)
     - 需要安裝opensearch (on infra node)
     - 每個node上都要安裝node exporter + fluent-bit(負責將pod log送給opensearch)
     - 安裝Kubevirt version = v1.5.0

2. 3node-multipass
   - 使用 Mac Mini M4 本機，透過 Multipass 建立三台 Ubuntu 24.04 VM，橋接至 en0（192.168.50.x/24)
   - 搭建純 K8s 三節點 Lab，不包含 KubeVirt（Apple Silicon 無 nested virtualization 支援
   - 專注於 K8s 核心元件與基礎設施服務的學習
