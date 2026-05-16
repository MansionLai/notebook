---
published: false
---

# Ceph 3-Node Ansible Automation

This directory contains the Ansible-first workflow for `storage/3node-ceph/phase-1.md` through `phase-5.md`.

## Control node

- Run from the Mac mini
- SSH user: `ubuntu`
- Inventory is static and points at the three Azure VM public IPs created in Phase 0

## Layout

- `inventory/hosts.yml` — host groups
- `inventory/group_vars/all/main.yml` — shared non-secret variables
- `inventory/group_vars/all/encrypted.yml` — secret variables (ansible-vault, auto-loaded)
- `playbooks/phase-1.yml` ~ `phase-5.yml` — one playbook per phase
- `playbooks/site.yml` — full Phase 1-5 chain
- `roles/` — one primary role per phase

## Quickstart

```bash
cd storage/3node-ceph/ansible

ansible-inventory --graph
ansible-playbook playbooks/phase-1.yml
ansible-playbook playbooks/phase-2.yml
ansible-playbook playbooks/phase-3.yml
ansible-playbook playbooks/phase-4.yml
ansible-playbook playbooks/phase-5.yml
```

To run the full build in one shot:

```bash
ansible-playbook playbooks/site.yml
```

## Variables to review

Before running Phase 3 in a non-lab environment, review:

- `inventory/hosts.yml`
- `inventory/group_vars/all/encrypted.yml`
- `ceph_dashboard_password`
- `ceph_rbd_pool_name`
- `ceph_rbd_pool_min_size`
- `ceph_rbd_crush_rule_name`
- `prometheus_agent_remote_write_url`
- `fluent_bit_opensearch_*`
- `ceph_location.datacenter|room|rack` for each node
- `ceph_osd_devices` for each node

The inventory file is the source of truth for:

- `ansible_host`
- `ceph_public_ip`
- `ceph_cluster_ip`
- `ceph_location`
- `ceph_osd_devices`

## Notes

- Phase 0 remains Azure MCP + Bicep and is intentionally not handled here.
- This workflow is designed for the current Azure 3-node lab topology, not generic multi-environment discovery.
