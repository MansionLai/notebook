---
title: NetBox Backup and Disaster Recovery
parent: Netbox
nav_order: 99
---

# NetBox Backup and Disaster Recovery

## 1. Backup Best Practices

### A. Database Backups
- Use `pg_dump` to back up the PostgreSQL database regularly.
- Automate backups (e.g., daily cron jobs).
- Store backups off-site and keep multiple recent copies.
- Example:
  ```bash
  pg_dump -U netbox -h localhost netbox > netbox_backup_$(date +%F).sql
  ```
- Regularly test restores in a separate environment.

### B. Media Files Backup
- Backup `/opt/netbox/netbox/media/` using `rsync`, `tar`, or snapshots.
- Store media backups with database dumps.

### C. Configuration Files Backup
- Include `configuration.py`, `extra.py`, and service files (Gunicorn, Nginx, systemd) in backups.
- Store configs in a private Git repo if possible.

### D. Application Code Backup
- Use version control (Git) for custom scripts, plugins, and template overrides.

## 2. Disaster Recovery

### A. Documentation
- Document the restore process, including dependencies and service startup.

### B. Recovery Testing
- Regularly test recovery in an isolated environment.
- Perform periodic "fire drills" to ensure full restoration is possible.

### C. Automation
- Use tools like Ansible or Terraform to automate server and app provisioning.

### D. Backup Redundancy
- Store backups off-site or in the cloud; use immutability features if available.

### E. Minimizing Downtime
- Consider PostgreSQL hot standby replication for high availability.
- For advanced setups, use Docker/Kubernetes with persistent storage and failover.

## 3. Additional Best Practices
- Encrypt backups, especially for off-site/cloud storage.
- Restrict access to backups and restore procedures.
- Monitor and alert on backup failures.

## References
- [NetBox Maintenance Docs](https://docs.netbox.dev/en/stable/administration/maintenance/)
- [PostgreSQL Backup Solutions](https://www.postgresql.org/docs/current/backup.html)
