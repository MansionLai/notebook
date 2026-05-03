---
title: Phase 6 - VM Workload
parent: 3-Node KubeVirt (Azure)
grand_parent: Kubernetes
nav_order: 16
---

# Phase 6 — VM Workload


### 架構說明

```
VM (10.10.100.100) → tap → k6t-bridge (pod內) → veth → vmbr0 → eth1 → Azure NAT GW → Internet
```

**關鍵限制：**
- Azure NIC 有 MAC filtering：只有已登記的 MAC+IP 組合才能通訊
- vmbr0 必須使用 eth1 的 registered MAC（`7c:1e:52:4d:3b:a4`）
- Azure NAT Gateway 不支援 ICMP（ping to internet 會失敗，TCP/UDP 正常）

---

### Step 6-1：建立 vmworkloads namespace

```bash
kubectl create namespace vmworkloads
```

---

### Step 6-2：VM YAML（ub24-01）

```yaml
# /tmp/ub24-01-vm.yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: ub24-01
  namespace: vmworkloads
spec:
  runStrategy: Always
  template:
    metadata:
      annotations:
        k8s.v1.cni.cncf.io/networks: vmnetwork/vmnet-100
    spec:
      domain:
        cpu:
          cores: 2
        memory:
          guest: 4Gi
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinit
              disk:
                bus: virtio
          interfaces:
            - name: vmnet100
              bridge: {}
      networks:
        - name: vmnet100
          multus:
            networkName: vmnetwork/vmnet-100
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/containerdisks/ubuntu:24.04
        - name: cloudinit
          cloudInitNoCloud:
            userData: |
              #cloud-config
              hostname: ub24-01
              ssh_pwauth: true
              chpasswd:
                expire: false
              users:
                - name: ubuntu
                  sudo: ALL=(ALL) NOPASSWD:ALL
                  shell: /bin/bash
                  lock_passwd: false
                  plain_text_passwd: ubuntu
              runcmd:
                # 設定 gateway static ARP（因為 vmbr0 bridge 無法回應 ARP）
                - ip neigh replace 10.10.100.12 lladdr 7c:1e:52:4d:3b:a4 dev enp1s0 nud permanent
                # 持久化（開機後自動執行）
                - mkdir -p /etc/networkd-dispatcher/routable.d
                - |
                  cat > /etc/networkd-dispatcher/routable.d/50-gw-arp.sh << 'SCRIPT'
                  #!/bin/bash
                  [ "$IFACE" = "enp1s0" ] && ip neigh replace 10.10.100.12 lladdr 7c:1e:52:4d:3b:a4 dev enp1s0 nud permanent
                  SCRIPT
                - chmod +x /etc/networkd-dispatcher/routable.d/50-gw-arp.sh
            networkData: |
              network:
                version: 2
                ethernets:
                  enp1s0:
                    dhcp4: false
                    addresses: [10.10.100.100/24]
                    gateway4: 10.10.100.12
                    nameservers:
                      addresses: [8.8.8.8, 1.1.1.1]
```

```bash
kubectl apply -f /tmp/ub24-01-vm.yaml
kubectl get vmi ub24-01 -n vmworkloads
```

---

### Step 6-3：Worker vmbr0 Policy Routing 設定

**問題根因分析：**

vmbr0 bridge 的網路流量有多個問題：
1. **vmbr0 不回應 ARP**（Azure MAC filtering 造成）→ VM 無法找到 gateway MAC
2. **Policy routing 造成 routing loop**（ICMP reply 被當成 forward packet）
3. **rp_filter 丟棄 asymmetric routing 封包**

**Worker 需要的完整設定（`/etc/networkd-dispatcher/routable.d/50-vmbr0-policy-routing`）：**

```bash
#!/bin/bash
# KubeVirt vmbr0 policy routing for 10.10.100.0/24 subnet
[ "$IFACE" = "vmbr0" ] || exit 0

# Disable rp_filter（允許 asymmetric routing）
sysctl -w net.ipv4.conf.vmbr0.rp_filter=0
sysctl -w net.ipv4.conf.all.rp_filter=0

# Disable ICMP redirect
sysctl -w net.ipv4.conf.vmbr0.send_redirects=0
sysctl -w net.ipv4.conf.all.send_redirects=0

# Table 100 subnet route（確保 intra-subnet 封包不走 default route）
ip route add 10.10.100.0/24 dev vmbr0 table 100 2>/dev/null || true

# Policy routing rules:
# Rule 97: 先查 local table（確保 vmbr0 IP local delivery）
ip rule show | grep -q 'priority 97' || ip rule add from 10.10.100.0/24 lookup local priority 97
# Rule 98: intra-subnet → main table
ip rule show | grep -q 'priority 98' || ip rule add from 10.10.100.0/24 to 10.10.100.0/24 lookup main priority 98
# Rule 99: VM outbound → table 100 → default via 10.10.100.1
ip rule show | grep -q 'priority 99' || ip rule add from 10.10.100.0/24 lookup 100 priority 99
ip route show table 100 | grep -q 'default' || ip route add default via 10.10.100.1 dev vmbr0 table 100
```

```bash
chmod +x /etc/networkd-dispatcher/routable.d/50-vmbr0-policy-routing
```

**Sysctl 持久化（`/etc/sysctl.d/99-kubevirt-vmbr0.conf`）：**

```ini
net.ipv4.conf.vmbr0.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.vmbr0.send_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.ip_forward = 1
```

---

### Step 6-4：MASQUERADE（iptables 持久化）

```bash
# /etc/iptables/rules.v4 — 已由 netfilter-persistent 管理
# 加入 MASQUERADE rule：VM 流量出去 vmbr0 後 SNAT
sudo iptables -t nat -A POSTROUTING -s 10.10.100.0/24 ! -d 10.10.100.0/24 -o vmbr0 -j MASQUERADE
sudo netfilter-persistent save
```

---

### Step 6-5：驗證

```bash
# 從 master
virtctl console ub24-01 -n vmworkloads

# 從 worker ping VM
ping -c 3 10.10.100.100   # ✅

# SSH 進 VM（從 worker）
ssh ubuntu@10.10.100.100   # 密碼: ubuntu

# 在 VM 內確認外網（TCP 可通，ICMP 不通是正常的）
curl https://api.ipify.org   # 返回 public IP ✅
ping 8.8.8.8               # ❌ Azure NAT GW 不支援 ICMP（正常）
```

---

### 踩坑記錄（Phase 6）

| 問題 | 原因 | 解法 |
|------|------|------|
| VM 無法 ping gateway | vmbr0 bridge 不回應 ARP（bridge L2 forwarding 與 L3 ARP reply 衝突） | cloud-init runcmd 設 static ARP: `ip neigh replace 10.10.100.12 lladdr 7c:1e:52:4d:3b:a4 dev enp1s0 nud permanent` |
| VM ping gateway 的 ARP reply 不通 | ARP request 進 vmbr0 但 bridge 不回應（疑似 Azure kernel 或 Cilium 干擾） | ebtables nat PREROUTING arpreply rule（或 cloud-init static ARP 繞過） |
| Worker ping VM 100% packet loss | Policy routing rule 99 把 VM reply (src 10.10.100.0/24) forward 出去而非 local deliver | 加 rule 97: `from 10.10.100.0/24 lookup local priority 97`（先查 local table） |
| Worker vmbr0 MAC 不對 | vmbr0 bridge 預設 MAC ≠ eth1 registered MAC → Azure 不回 ARP | netplan 設 `macaddress: 7c:1e:52:4d:3b:a4` on vmbr0 |
| VM outbound 無法連外 | 10.10.100.0/24 subnet 未設定 NAT Gateway | Azure Portal → 建立 NAT Gateway + 關聯 subnet |
| ping 8.8.8.8 不通（VM 內） | Azure NAT Gateway 不支援 ICMP | 正常，改用 curl/TCP 驗證 |
