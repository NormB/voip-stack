# Troubleshooting Guide

Common issues and solutions for voip-stack.

---

## Table of Contents

- [VM Creation Issues](#vm-creation-issues)
- [Network Configuration Issues](#network-configuration-issues)
- [VM Management Issues](#vm-management-issues)
- [Ansible Issues](#ansible-issues)
- [OpenSIPS Issues](#opensips-issues)
- [Asterisk Issues](#asterisk-issues)
- [RTPEngine Issues](#rtpengine-issues)
- [Fail2ban Issues](#fail2ban-issues)
- [Vault Issues](#vault-issues)
- [Database Issues](#database-issues)
- [Performance Issues](#performance-issues)
- [Recovery Procedures](#recovery-procedures)

---

## VM Creation Issues

### Lima VM Won't Start

**Symptom**: `limactl start` fails or hangs

**Solution**:
```bash
# Check VM status
limactl list

# Check for errors
limactl info sip-1

# View Lima logs
cat ~/.lima/sip-1/ha.stderr.log
cat ~/.lima/sip-1/serial.log

# Try stopping and restarting
limactl stop sip-1 --force
limactl start sip-1
```

### Lima VM Stuck in Starting State

**Symptom**: VM stays in "Starting" state

**Cause**: Image download or boot issue

**Solution**:
```bash
# Delete and recreate VM
limactl delete sip-1 --force
./scripts/lima-vms.sh create

# Check if Debian image downloaded correctly
ls -la ~/.cache/lima/download/
```

### Lima Configuration Error

**Symptom**: "error loading yaml" when creating VM

**Cause**: Invalid YAML in Lima config

**Solution**:
```bash
# Validate YAML syntax
cat lima/sip-1.yaml | python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)'

# Check Lima config format
limactl validate lima/sip-1.yaml
```

---

## Network Configuration Issues

### VM Can't Access Host Services

**Symptom**: VM can't reach devstack-core services

**Cause**: Lima networking issue

**Solution**:
```bash
# Check host.lima.internal resolves inside VM
limactl shell sip-1 -- getent hosts host.lima.internal

# Test connectivity to Vault
limactl shell sip-1 -- curl -s http://host.lima.internal:8200/v1/sys/health

# If needed, get host IP manually
limactl shell sip-1 -- ip route | grep default
```

### SSH Connection Timeout

**Symptom**: SSH to VM times out

**Cause**: VM not fully booted or SSH not ready

**Solution**:
```bash
# Check VM status
limactl list

# Wait for VM to be "Running"
# Then test SSH
ssh -v -F ~/.lima/sip-1/ssh.config lima-sip-1
```

---

## VM Management Issues

### VM Not Found

**Symptom**: `limactl shell` says VM not found

**Solution**:
```bash
# List all VMs
limactl list

# If VMs missing, recreate them
./scripts/lima-vms.sh create
```

### VM Already Exists

**Symptom**: `lima-vms.sh create` fails because VM exists

**Solution**:
```bash
# The script will skip existing VMs automatically
# To recreate, destroy first:
./scripts/lima-vms.sh destroy
./scripts/lima-vms.sh create
```

---

## Ansible Issues

### Cannot Connect to VMs

**Symptom**: Ansible fails with "Unreachable host"

**Solution**:
```bash
# Check VMs are running
limactl list

# Regenerate inventory
./scripts/lima-vms.sh inventory

# Test SSH manually
limactl shell sip-1

# Check inventory file
cat ansible/inventory/lima.yml
```

### Vault Connection Failed

**Symptom**: Ansible fails with "Cannot connect to Vault"

**Solution**:
```bash
# Check Vault is running
curl http://192.168.64.1:8200/v1/sys/health

# Check devstack-core
cd ~/devstack-core
./devstack status

# Restart if needed
./devstack restart vault
```

### Role Task Fails

**Symptom**: Specific Ansible task fails

**Solution**:
```bash
# Run playbook with verbose output
cd ~/voip-stack/ansible
ansible-playbook playbooks/provision-vms.yml -vv

# Run specific role only
ansible-playbook playbooks/provision-vms.yml --tags opensips

# Skip problematic role
ansible-playbook playbooks/provision-vms.yml --skip-tags asterisk
```

### Missing Template Error

**Symptom**: Task fails with "Could not find or access 'template.j2'"

**Cause**: Template file missing from role's templates directory

**Solution**:
```bash
# Check what templates exist
ls -la ansible/roles/[role_name]/templates/

# Check configure.yml for required templates
cat ansible/roles/[role_name]/tasks/configure.yml

# Create missing template or check git status
git status
```

---

## OpenSIPS Issues

### OpenSIPS Container Won't Start (Docker)

**Symptom**: Container continuously restarts, exit code 255

**Cause**: Deprecated `-E` flag in OpenSIPS 3.5

**Solution**:
The OpenSIPS 3.5 Docker image uses deprecated `-E` flag by default. Override with `-F`:
```yaml
# In docker-compose.yml
services:
  opensips:
    command: ["-F"]  # Use -F instead of deprecated -E
```

### Configuration Parse Errors

**Symptom**: `opensips -c` fails with syntax errors

**Cause**: OpenSIPS 3.5 deprecated several configuration parameters

**Common Fixes**:
```
# Old syntax (3.4 and earlier) → New syntax (3.5+)
children=4            → udp_workers=4
tcp_children=4        → tcp_workers=4
listen=udp:0.0.0.0:5060 → socket=udp:0.0.0.0:5060
log_stderror=yes      → stderror_enabled=yes
log_facility=LOG_LOCAL0 → syslog_facility=LOG_LOCAL0
```

**Required module** for UDP transport:
```
# Must be loaded explicitly in 3.5
loadmodule "proto_udp.so"
```

### Healthcheck Failing (Docker)

**Symptom**: Container shows unhealthy, healthcheck fails

**Cause**: Healthcheck using TCP for UDP service

**Solution**:
```yaml
# In docker-compose.yml - use UDP check
healthcheck:
  test: ["CMD", "nc", "-z", "-u", "{{ internal_ip }}", "5060"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### Native Service Conflicts with Docker

**Symptom**: Port 5060 already in use

**Cause**: Native systemd service running alongside Docker container

**Solution**:
```bash
# Check what's using port 5060
limactl shell sip-1 -- ss -nlup | grep 5060

# Disable native service if using Docker
limactl shell sip-1 -- sudo systemctl disable opensips
limactl shell sip-1 -- sudo systemctl stop opensips
```

### Module Path Issues

**Symptom**: "ERROR: cannot load module" in logs

**Cause**: Incorrect module path for deployment type

**Solution**:
```
# Docker container path
mpath="/lib64/opensips/modules/"

# Native/source installation path
mpath="/usr/local/lib64/opensips/modules/"
```

### Database Connection Issues

**Symptom**: "db_postgres: ERROR" in logs

**Solution**:
```bash
# Test PostgreSQL connection from VM (via host.lima.internal)
limactl shell sip-1 -- psql -h host.lima.internal -U opensips -d opensips -c "SELECT 1"

# Check connectivity
limactl shell sip-1 -- nc -z host.lima.internal 5432

# Check credentials in config
limactl shell sip-1 -- grep db_url /etc/opensips/opensips.cfg
```

---

## Asterisk Issues

### Missing Template Errors

**Symptom**: Ansible fails with missing template (pjsip.conf.j2, extensions.conf.j2)

**Cause**: Template files not created in role

**Solution**: Ensure all required templates exist in `ansible/roles/asterisk/templates/`:
- `pjsip.conf.j2`
- `extensions.conf.j2`
- `manager.conf.j2`
- `ari.conf.j2`
- `cdr.conf.j2`
- `voicemail.conf.j2`

### PJSIP Endpoint Not Loading

**Symptom**: `pjsip show endpoints` shows empty

**Solution**:
```bash
# Check PJSIP configuration
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show transports"'

# Check for config errors
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "config show pjsip.conf"'

# Enable PJSIP debug
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip set logger on"'
```

### No Audio in Calls

**Symptom**: Calls connect but no audio

**Cause**: RTPEngine not configured or unreachable

**Solution**:
```bash
# Check RTPEngine is running
limactl shell media-1 -- systemctl status rtpengine

# Check PJSIP direct_media setting
limactl shell pbx-1 -- grep direct_media /etc/asterisk/pjsip.conf
# Should be: direct_media=no
```

### Version Output Error in Check Mode

**Symptom**: Ansible check mode fails on "Display Asterisk version"

**Cause**: Variable not defined when command doesn't execute

**Solution**: Add condition to debug task:
```yaml
- name: Display Asterisk version
  ansible.builtin.debug:
    msg: "{{ asterisk_version_output.stdout }}"
  when: asterisk_version_output.stdout is defined
```

---

## RTPEngine Issues

### Kernel Module Not Loading

**Symptom**: `lsmod | grep xt_RTPENGINE` returns nothing

**Solution**:
```bash
# Check if module exists
limactl shell media-1 -- find /lib/modules -name "xt_RTPENGINE*"

# Check DKMS status
limactl shell media-1 -- dkms status

# Rebuild if needed
limactl shell media-1 -- sudo dkms autoinstall

# Manual load
limactl shell media-1 -- sudo modprobe xt_RTPENGINE
```

### Service Won't Start

**Symptom**: `systemctl status rtpengine` shows failed

**Solution**:
```bash
# Check logs
limactl shell media-1 -- journalctl -u rtpengine -n 50

# Verify configuration
limactl shell media-1 -- cat /etc/rtpengine/rtpengine.conf

# Check interface exists
limactl shell media-1 -- ip addr show
```

---

## Fail2ban Issues

### Socket Not Found

**Symptom**: "fail2ban.sock not found" errors

**Cause**: fail2ban service hasn't started or socket timing issue

**Solution**:
```bash
# Wait for socket creation
limactl shell sip-1 -- sleep 5 && ls -la /var/run/fail2ban/

# Restart fail2ban
limactl shell sip-1 -- sudo systemctl restart fail2ban

# Check status
limactl shell sip-1 -- sudo fail2ban-client status
```

### Jail Won't Start

**Symptom**: "Unable to find a corresponding log file"

**Cause**: Log file doesn't exist yet

**Solution**:
Create log file before enabling jail:
```bash
# Create log file
limactl shell sip-1 -- sudo touch /var/log/opensips/opensips.log
limactl shell sip-1 -- sudo chown opensips:opensips /var/log/opensips/opensips.log

# Restart fail2ban
limactl shell sip-1 -- sudo systemctl restart fail2ban
```

### Filter Syntax Errors

**Symptom**: Jail fails to start with regex errors

**Cause**: Invalid filter configuration

**Solution**:
```bash
# Test filter
limactl shell sip-1 -- sudo fail2ban-regex /var/log/opensips/opensips.log /etc/fail2ban/filter.d/opensips.conf

# Check filter file
limactl shell sip-1 -- cat /etc/fail2ban/filter.d/opensips.conf
```

---

## Vault Issues

### AppRole Credentials Missing

**Symptom**: Vault agent can't authenticate

**Cause**: AppRole not set up in Vault

**Solution**:
```bash
# Check Vault approle
curl -s http://192.168.64.1:8200/v1/sys/auth | jq '.["approle/"]'

# Check if role exists
export VAULT_ADDR=http://192.168.64.1:8200
vault read auth/approle/role/voip-stack

# Create if missing (via devstack-core)
cd ~/devstack-core
./devstack vault-setup-voip
```

### Wrong Binary Architecture

**Symptom**: "cannot execute binary file" on ARM64

**Cause**: x86 binary downloaded on ARM system

**Solution**:
Ensure correct binary URL:
```yaml
# For ARM64 (Apple Silicon)
vault_client_binary_url: "https://releases.hashicorp.com/vault/{{ vault_version }}/vault_{{ vault_version }}_linux_arm64.zip"
```

---

## Database Issues

### PostgreSQL Connection Failed

**Symptom**: Services can't connect to PostgreSQL

**Solution**:
```bash
# Test connection from VM (via host.lima.internal)
limactl shell sip-1 -- psql -h host.lima.internal -U opensips -d opensips

# Check devstack-core PostgreSQL
cd ~/devstack-core
./devstack logs postgres

# Restart if needed
./devstack restart postgres
```

### Database Migrations Failed

**Solution**:
```bash
# Check database exists
psql -h localhost -U postgres -l

# Run migrations manually inside VM
limactl shell sip-1
sudo -u opensips opensips-cli -x database create
```

---

## Performance Issues

### VM is Slow

**Solution**:
```bash
# Check CPU usage
limactl shell sip-1 -- top -bn1 | head -20

# Check disk I/O
limactl shell sip-1 -- iostat

# Check available RAM
limactl shell sip-1 -- free -h

# Check VM resources
limactl info sip-1 | grep -E "cpus|memory"
```

### High Memory Usage

**Solution**:
```bash
# Check what's using memory
limactl shell pbx-1 -- ps aux --sort=-%mem | head -20

# Restart services to clear memory
limactl shell pbx-1 -- sudo systemctl restart asterisk
```

### Ansible Slow Provisioning

**Causes and Solutions**:

1. **Redundant fact gathering**: Remove `gather_facts: yes` from subsequent plays
2. **Long SSH waits**: Reduce polling interval (5s → 2s)
3. **APT cache updates**: Add `cache_valid_time: 3600` to apt tasks
4. **Sequential execution**: Use `strategy: free` for independent hosts

See [ANSIBLE-PROVISIONING.md](ANSIBLE-PROVISIONING.md) for detailed performance optimization.

---

## Recovery Procedures

### Complete Reset

```bash
# Stop all VMs
./scripts/lima-vms.sh stop

# Destroy all VMs
./scripts/lima-vms.sh destroy

# Re-create VMs
./scripts/lima-vms.sh create

# Generate inventory and re-provision
./scripts/lima-vms.sh inventory
./scripts/ansible-run.sh provision-vms
```

### Reset Single VM

```bash
# Stop and delete single VM
limactl stop sip-1
limactl delete sip-1

# Recreate VM
limactl create --name=sip-1 lima/sip-1.yaml
limactl start sip-1

# Regenerate inventory
./scripts/lima-vms.sh inventory

# Re-run Ansible for this VM only
./scripts/ansible-run.sh provision-vms --limit sip-1
```

### Reset Services

```bash
# Restart service on VM
limactl shell sip-1 -- sudo systemctl restart opensips

# Check logs
limactl shell sip-1 -- journalctl -u opensips -n 50 --no-pager
```

---

## Getting Help

1. **Check Logs**:
   ```bash
   # VM system logs
   limactl shell sip-1 -- sudo journalctl -xe

   # Service logs
   limactl shell sip-1 -- journalctl -u opensips --no-pager

   # Lima VM logs
   cat ~/.lima/sip-1/ha.stderr.log

   # Ansible logs
   ./scripts/ansible-run.sh provision-vms -vvv > debug.log 2>&1
   ```

2. **Verify Prerequisites**:
   - devstack-core running
   - Lima VMs running (`limactl list`)
   - Sufficient disk space and RAM

3. **Community Support**:
   - GitHub Issues: https://github.com/NormB/voip-stack/issues
   - Check existing issues first
   - Include logs and error messages

---

**Document Status**: Complete
**Last Updated**: 2025-12-30
**VM Platform**: Lima with Debian 12 ARM64
