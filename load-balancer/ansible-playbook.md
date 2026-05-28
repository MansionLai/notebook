---
title: Ansible Playbook
parent: Load Balancer
nav_order: 6
---

# Ansible Playbook 自動化部署

用 Ansible 一鍵完成 Keepalived、HAProxy 和 Docker Backend 的安裝與配置。

## 目錄結構

```
ansible/
├── inventory/
│   └── hosts.yml          # 定義 lb-master 和 lb-slave
├── group_vars/
│   └── all.yml            # 共用變數（VIP、認證密碼等）
├── host_vars/
│   ├── lb-master.yml      # Master 專屬變數（priority、state）
│   └── lb-slave.yml       # Slave 專屬變數
├── roles/
│   ├── keepalived/
│   │   ├── tasks/main.yml
│   │   ├── templates/keepalived.conf.j2
│   │   └── handlers/main.yml
│   ├── haproxy/
│   │   ├── tasks/main.yml
│   │   ├── templates/haproxy.cfg.j2
│   │   └── handlers/main.yml
│   └── docker_backend/
│       ├── tasks/main.yml
│       ├── templates/docker-compose.yml.j2
│       └── files/
│           └── api/app.py
└── site.yml               # 主 playbook
```

---

## 安裝 Ansible（在 Mac 上執行）

```bash
brew install ansible

# 確認版本
ansible --version
# ansible [core 2.x.x]
```

---

## Inventory 設定

### `inventory/hosts.yml`

```yaml
all:
  children:
    lb_nodes:
      hosts:
        lb-master:
          ansible_host: 192.168.50.211
          ansible_user: ubuntu
        lb-slave:
          ansible_host: 192.168.50.212
          ansible_user: ubuntu
```

### 設定 SSH 免密碼登入

```bash
# 產生 SSH key（若尚未有）
ssh-keygen -t ed25519 -C "ansible"

# 複製 public key 到兩台 VM
ssh-copy-id ubuntu@192.168.50.211
ssh-copy-id ubuntu@192.168.50.212

# 測試連線
ansible lb_nodes -i inventory/hosts.yml -m ping
# 預期：
# lb-master | SUCCESS => {"ping": "pong"}
# lb-slave  | SUCCESS => {"ping": "pong"}
```

---

## 變數設定

### `group_vars/all.yml`（兩台共用）

```yaml
# VIP 設定
vrrp_vip: "192.168.50.250"
vrrp_interface: "ens4"        # 橋接網卡名稱（請確認）
vrrp_router_id: 51
vrrp_advert_int: 1
vrrp_auth_pass: "LB2024secret"

# HAProxy
haproxy_stats_user: "admin"
haproxy_stats_pass: "admin123"
haproxy_web_port: 80
haproxy_api_port: 8081
haproxy_stats_port: 8404

# Backend 服務
backend_web_port: 8080
backend_api_port: 8081
backend_servers:
  - name: lb-master
    ip: "192.168.50.211"
  - name: lb-slave
    ip: "192.168.50.212"
```

### `host_vars/lb-master.yml`

```yaml
keepalived_state: "MASTER"
keepalived_priority: 100
keepalived_preempt: true
```

### `host_vars/lb-slave.yml`

```yaml
keepalived_state: "BACKUP"
keepalived_priority: 90
keepalived_preempt: false
```

---

## Keepalived Role

### `roles/keepalived/tasks/main.yml`

```yaml
- name: Install keepalived
  apt:
    name: keepalived
    state: present
    update_cache: yes
  become: true

- name: Deploy keepalived config
  template:
    src: keepalived.conf.j2
    dest: /etc/keepalived/keepalived.conf
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: Restart keepalived

- name: Enable and start keepalived
  systemd:
    name: keepalived
    enabled: true
    state: started
  become: true
```

### `roles/keepalived/templates/keepalived.conf.j2`

```jinja2
! Configuration File for keepalived - managed by Ansible

global_defs {
    router_id {{ inventory_hostname }}
    script_user root
    enable_script_security
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight -20
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state {{ keepalived_state }}
    interface {{ vrrp_interface }}
    virtual_router_id {{ vrrp_router_id }}
    priority {{ keepalived_priority }}
    advert_int {{ vrrp_advert_int }}
{% if keepalived_preempt %}
    preempt
{% else %}
    nopreempt
{% endif %}

    authentication {
        auth_type PASS
        auth_pass {{ vrrp_auth_pass }}
    }

    virtual_ipaddress {
        {{ vrrp_vip }}/24
    }

    track_script {
        chk_haproxy
    }
}
```

### `roles/keepalived/handlers/main.yml`

```yaml
- name: Restart keepalived
  systemd:
    name: keepalived
    state: restarted
  become: true
```

---

## HAProxy Role

### `roles/haproxy/tasks/main.yml`

```yaml
- name: Install haproxy
  apt:
    name: haproxy
    state: present
    update_cache: yes
  become: true

- name: Deploy haproxy config
  template:
    src: haproxy.cfg.j2
    dest: /etc/haproxy/haproxy.cfg
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: Restart haproxy

- name: Validate haproxy config
  command: haproxy -c -f /etc/haproxy/haproxy.cfg
  become: true
  changed_when: false

- name: Enable and start haproxy
  systemd:
    name: haproxy
    enabled: true
    state: started
  become: true
```

### `roles/haproxy/templates/haproxy.cfg.j2`

```jinja2
#---------------------------------------------------------------------
# Global - managed by Ansible
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 50000

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor except 127.0.0.0/8
    retries 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout check           10s

#---------------------------------------------------------------------
# Stats
#---------------------------------------------------------------------
frontend stats
    bind *:{{ haproxy_stats_port }}
    stats enable
    stats uri /stats
    stats refresh 10s
    stats show-node
    stats auth {{ haproxy_stats_user }}:{{ haproxy_stats_pass }}

#---------------------------------------------------------------------
# Web Frontend
#---------------------------------------------------------------------
frontend web_front
    bind *:{{ haproxy_web_port }}
    default_backend web_back

backend web_back
    balance roundrobin
    option httpchk GET /
{% for server in backend_servers %}
    server {{ server.name }} {{ server.ip }}:{{ backend_web_port }} check inter 5s fall 3 rise 2
{% endfor %}

#---------------------------------------------------------------------
# API Frontend
#---------------------------------------------------------------------
frontend api_front
    bind *:{{ haproxy_api_port }}
    default_backend api_back

backend api_back
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
{% for server in backend_servers %}
    server {{ server.name }} {{ server.ip }}:{{ backend_api_port }} check inter 5s fall 3 rise 2
{% endfor %}
```

### `roles/haproxy/handlers/main.yml`

```yaml
- name: Restart haproxy
  systemd:
    name: haproxy
    state: restarted
  become: true
```

---

## Docker Backend Role

### `roles/docker_backend/tasks/main.yml`

```yaml
- name: Install Docker
  shell: curl -fsSL https://get.docker.com | sudo sh
  args:
    creates: /usr/bin/docker
  become: true

- name: Add ubuntu user to docker group
  user:
    name: ubuntu
    groups: docker
    append: yes
  become: true

- name: Create backend directory
  file:
    path: /home/ubuntu/backend
    state: directory
    owner: ubuntu
    mode: '0755'

- name: Create web directory
  file:
    path: /home/ubuntu/backend/web
    state: directory
    owner: ubuntu

- name: Create api directory
  file:
    path: /home/ubuntu/backend/api
    state: directory
    owner: ubuntu

- name: Deploy index.html
  template:
    src: index.html.j2
    dest: /home/ubuntu/backend/web/index.html
    owner: ubuntu

- name: Deploy API server script
  copy:
    src: api/app.py
    dest: /home/ubuntu/backend/api/app.py
    owner: ubuntu

- name: Deploy docker-compose.yml
  template:
    src: docker-compose.yml.j2
    dest: /home/ubuntu/backend/docker-compose.yml
    owner: ubuntu

- name: Start backend services
  community.docker.docker_compose_v2:
    project_src: /home/ubuntu/backend
    state: present
  become: true
```

### `roles/docker_backend/templates/docker-compose.yml.j2`

```yaml
version: '3.8'

services:
  web-server:
    image: nginx:alpine
    container_name: web-server
    ports:
      - "{{ backend_web_port }}:80"
    volumes:
      - ./web/index.html:/usr/share/nginx/html/index.html:ro
    restart: unless-stopped

  api-server:
    image: python:3.11-alpine
    container_name: api-server
    ports:
      - "{{ backend_api_port }}:{{ backend_api_port }}"
    volumes:
      - ./api/app.py:/app/app.py:ro
    working_dir: /app
    command: python app.py
    restart: unless-stopped
```

---

## 主 Playbook

### `site.yml`

```yaml
---
- name: Deploy Load Balancer Stack
  hosts: lb_nodes
  gather_facts: true
  become: false

  roles:
    - role: docker_backend
      tags: [backend]

    - role: haproxy
      tags: [haproxy]

    - role: keepalived
      tags: [keepalived]
```

---

## 執行 Playbook

```bash
cd ansible/

# 先 dry-run 確認沒問題
ansible-playbook -i inventory/hosts.yml site.yml --check

# 正式執行
ansible-playbook -i inventory/hosts.yml site.yml

# 只執行特定 role
ansible-playbook -i inventory/hosts.yml site.yml --tags keepalived
ansible-playbook -i inventory/hosts.yml site.yml --tags haproxy
ansible-playbook -i inventory/hosts.yml site.yml --tags backend
```

預期輸出：
```
PLAY RECAP ******************************************
lb-master : ok=12  changed=8  unreachable=0  failed=0
lb-slave  : ok=12  changed=8  unreachable=0  failed=0
```

---

## 部署後驗證

```bash
# 確認 VIP 在 Master
ansible lb-master -i inventory/hosts.yml -m command \
  -a "ip addr show ens4" | grep inet

# 確認服務狀態
ansible lb_nodes -i inventory/hosts.yml -m command \
  -a "systemctl is-active keepalived haproxy"

# 從 Mac 測試 VIP
curl http://192.168.50.250        # Web
curl http://192.168.50.250:8081/api/info  # API
open http://192.168.50.250:8404/stats     # HAProxy Stats
```
