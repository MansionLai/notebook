AI agent 運行在我的mac mini上, 並且協助我一起維護 notebook-sync repo, agent主要focus on ceph這個folder.
AI agent 使用 ai/ceph branch進行修正, 確認沒問題後再merge回main branch
AI agent 請盡可能使用azure mcp來操作azure, 非必要不要使用az command

1. 3node-ceph
   - 透過azure cloud建立vm
     - resource group name = mansion_ceph_resource
     - 所有相關的resource name都幫我加上mansion-ceph- prefix作為識別
     - 如果是需要跟其他resource共用的物件, 請放在mansion-shared-resource下
   - VM Spec
     - 透過azure cloud建立三台 ubuntu 22.04 vm, 每台都有 MON + MGR + OSD
     - os public ip segment = 10.10.10.0/24 (希望跟我另個kubernetes專案中的三台vm是在同個segment下且互通)
     - cluster private network = 172.10.10.0/24 (僅需ceph vm可以互通即可)
     - 用以學習ceph installation + ceph trouble shooting
     - azure vm的user name = ubuntu, 不使用密碼ssh登入, 直接使用我mac mini上的 ssh key.
     - ceph node 1
       - Standard_D4s_v4 (4C/16G)
       - os ip: 10.10.10.21/24
       - ceph cluster ip: 172.10.10.21/24
       - 1 * 64G os disk + 2 * 64G osd disk
       - localtion label:
         - datacenter: dc1
         - room: room1
         - rack: rack1
     - ceph node 2
       - Standard_D4s_v4 (4C/16G)
       - os ip: 10.10.10.22/24
       - ceph cluster ip: 172.10.10.22/24
       - 1 * 64G os disk + 2 * 64G osd disk
       - localtion label:
         - datacenter: dc1
         - room: room1
         - rack: rack2
     - ceph node 3
       - Standard_D4s_v4 (4C/16G)
       - os ip: 10.10.10.23/24
       - ceph cluster ip: 172.10.10.23/24
       - 1 * 64G os disk + 2 * 64G osd disk
       - localtion label:
         - datacenter: dc1
         - room: room1
         - rack: rack3
   - Installation guide
     - ceph version = v19.2.2
     - 建立rbd pool, name=k8s_rbd_pool (size=3, min_size=1, pg_num=128, pgp_num=128)
     - 調整crush map, 依照ceph node location label, 並調整failure domain=rack
     - 需要安裝ceph-exporter + ceph-node-exporter將metrics推送到另個kubernetes專案中建立的prometheus
     - 需要安裝fluent-bit將log推送到個kubernetes專案中建立的opensearch
     - 將安裝方式寫成markdown file方便閱讀
   - ansible 
     - 產生 ansible playbook將ceph cluster安裝過程自動化
     - 將不同安裝phase拆成不同的role
     - host var定義在 inventory yaml內
     - group_vars內有兩份檔案
       - all.yml 儲存明碼的variable
       - encrypted.yml 儲存使用ansible vault加密過後的variable, 將secret性質的variable放在這份檔案

2. ceph-cross-dc-migration