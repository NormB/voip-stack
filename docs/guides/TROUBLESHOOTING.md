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

### libvirt Not Running

**Symptom**: `virsh` commands fail with connection errors

**Cause**: libvirt service not running

**Solution**:
```bash
# Check libvirt status
brew services list | grep libvirt

# Start libvirt if needed
brew services start libvirt

# Verify connection
virsh -c qemu:///session list --all
```

### socket_vmnet Not Running

**Symptom**: VMs start but have no network connectivity

**Cause**: socket_vmnet service not running

**Solution**:
```bash
# Check socket_vmnet sockets
ls -la /opt/homebrew/var/run/socket_vmnet*

# If missing, run setup script
cd ~/voip-stack/libvirt
sudo ./setup-socket-vmnet.sh

# Verify services
sudo launchctl list | grep socket_vmnet
```

### qemu-guest-agent Missing

**Symptom**: Can't get VM IP address

**Cause**: qemu-guest-agent not installed in VM

**Solution**:
```bash
# SSH to VM
ssh voip@192.168.64.10

# Install guest agent
sudo apt install -y qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

# Verify
sudo systemctl status qemu-guest-agent
```

---

## Network Configuration Issues

### Static IP Not Applied

**Symptom**: VM still has DHCP address after bootstrap

**Cause**: Network bootstrap failed or didn't run

**Solution**:
```bash
# Check if bootstrap ran
cd ~/voip-stack/ansible
ansible-playbook playbooks/bootstrap-network.yml -vv

# Manually verify static IP
ssh voip@192.168.64.10
ip addr show eth0
# Should show: inet 192.168.64.10/24
```

### Cannot SSH After Network Bootstrap

**Symptom**: SSH times out after static IP configuration

**Cause**: Static IP not configured or network restart failed

**Solution**:
```bash
# Check VM is running
virsh -c qemu:///session list --all

# Try pinging the static IP
ping 192.168.64.10

# If VM has console access, check IP
virsh -c qemu:///session console sip-1

# Inside VM, check network
ip addr show enp0s1
cat /etc/network/interfaces

# Restart networking manually
sudo systemctl restart networking
```

---

## VM Management Issues

### VM Definition Not Found

**Symptom**: `virsh` commands fail with "domain not found"

**Solution**:
```bash
# Check which VMs are defined
virsh -c qemu:///session list --all

# If VMs missing, recreate them
cd ~/voip-stack/libvirt
./create-vms.sh create
```

### VM Already Exists

**Symptom**: `create-vms.sh` fails because VM exists

**Solution**:
```bash
# Option 1: Delete and recreate
virsh -c qemu:///session destroy sip-1 2>/dev/null || true
virsh -c qemu:///session undefine sip-1 --remove-all-storage
cd ~/voip-stack/libvirt
./create-vms.sh create

# Option 2: Just start existing VMs
./create-vms.sh start
```

---

## Ansible Issues

### Cannot Connect to VMs

**Symptom**: Ansible fails with "Unreachable host"

**Solution**:
```bash
# Test SSH manually
ssh voip@192.168.64.10

# Check SSH keys
ssh-add -l

# Try with password auth
ssh -o PubkeyAuthentication=no voip@192.168.64.10

# Check Ansible inventory
cat ansible/inventory/development.yml
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
ssh voip@192.168.64.10 'ss -nlup | grep 5060'

# Disable native service if using Docker
ssh voip@192.168.64.10 'sudo systemctl disable opensips'
ssh voip@192.168.64.10 'sudo systemctl stop opensips'
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
# Test PostgreSQL connection from VM
ssh voip@192.168.64.10 'psql -h 192.168.64.1 -U opensips -d opensips -c "SELECT 1"'

# From Docker container
ssh voip@192.168.64.10 'docker exec opensips nc -z 192.168.64.1 5432'

# Check credentials in config
grep db_url /etc/opensips/opensips.cfg
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
ssh voip@192.168.64.20 'systemctl status rtpengine'

# Check connectivity from Asterisk
ssh voip@192.168.64.30 'nc -u -z 192.168.64.20 2223 && echo "RTPEngine OK"'

# Check PJSIP direct_media setting
grep direct_media /etc/asterisk/pjsip.conf
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
ssh voip@192.168.64.20 'find /lib/modules -name "xt_RTPENGINE*"'

# Check DKMS status
ssh voip@192.168.64.20 'dkms status'

# Rebuild if needed
ssh voip@192.168.64.20 'sudo dkms autoinstall'

# Manual load
ssh voip@192.168.64.20 'sudo modprobe xt_RTPENGINE'
```

### Service Won't Start

**Symptom**: `systemctl status rtpengine` shows failed

**Solution**:
```bash
# Check logs
ssh voip@192.168.64.20 'journalctl -u rtpengine -n 50'

# Verify configuration
ssh voip@192.168.64.20 'cat /etc/rtpengine/rtpengine.conf'

# Check interface exists
ssh voip@192.168.64.20 'ip addr show'
```

---

## Fail2ban Issues

### Socket Not Found

**Symptom**: "fail2ban.sock not found" errors

**Cause**: fail2ban service hasn't started or socket timing issue

**Solution**:
```bash
# Wait for socket creation
ssh voip@192.168.64.10 'sleep 5 && ls -la /var/run/fail2ban/'

# Restart fail2ban
ssh voip@192.168.64.10 'sudo systemctl restart fail2ban'

# Check status
ssh voip@192.168.64.10 'sudo fail2ban-client status'
```

### Jail Won't Start

**Symptom**: "Unable to find a corresponding log file"

**Cause**: Log file doesn't exist yet

**Solution**:
Create log file before enabling jail:
```bash
# Create log file
ssh voip@192.168.64.10 'sudo touch /var/log/opensips/opensips.log'
ssh voip@192.168.64.10 'sudo chown opensips:opensips /var/log/opensips/opensips.log'

# Restart fail2ban
ssh voip@192.168.64.10 'sudo systemctl restart fail2ban'
```

### Filter Syntax Errors

**Symptom**: Jail fails to start with regex errors

**Cause**: Invalid filter configuration

**Solution**:
```bash
# Test filter
ssh voip@192.168.64.10 'sudo fail2ban-regex /var/log/opensips/opensips.log /etc/fail2ban/filter.d/opensips.conf'

# Check filter file
ssh voip@192.168.64.10 'cat /etc/fail2ban/filter.d/opensips.conf'
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
# Test connection from VM
ssh voip@192.168.64.10
psql -h 192.168.64.1 -U opensips -d opensips

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
psql -h 192.168.64.1 -U postgres -l

# Run migrations manually
ssh voip@192.168.64.10
sudo -u opensips opensips-cli -x database create
```

---

## Performance Issues

### VM is Slow

**Solution**:
```bash
# Check CPU usage
ssh voip@192.168.64.10 "top -bn1"

# Check disk I/O
ssh voip@192.168.64.10 "iostat"

# Check available RAM
ssh voip@192.168.64.10 "free -h"

# Consider increasing resources in template
```

### High Memory Usage

**Solution**:
```bash
# Check what's using memory
ssh voip@192.168.64.30 "ps aux --sort=-%mem | head -20"

# Restart services to clear memory
ssh voip@192.168.64.30 "sudo systemctl restart asterisk"
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
cd ~/voip-stack/libvirt
./create-vms.sh stop

# Delete all VMs
./create-vms.sh destroy

# Re-create and start VMs
./create-vms.sh create
./create-vms.sh start

# Wait for boot
sleep 60

# Re-provision
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms
```

### Reset Single VM

```bash
# Stop VM
virsh -c qemu:///session destroy sip-1 2>/dev/null || true

# Delete VM
virsh -c qemu:///session undefine sip-1 --remove-all-storage

# Recreate VM (regenerates cloud-init and disk)
cd ~/voip-stack/libvirt
./create-vms.sh create  # Will only create missing VMs

# Start VM
virsh -c qemu:///session start sip-1

# Wait for boot
sleep 60

# Re-run Ansible for this VM only
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms --limit sip-1
```

### Reset Docker Containers

```bash
# On specific VM
ssh voip@192.168.64.10

# Stop and remove containers
cd /opt/opensips
docker compose down

# Remove volumes (if needed)
docker compose down -v

# Restart
docker compose up -d
```

---

## Getting Help

1. **Check Logs**:
   ```bash
   # VM logs
   ssh voip@192.168.64.10 "sudo journalctl -xe"

   # Docker container logs
   ssh voip@192.168.64.10 "docker logs opensips --tail 100"

   # Ansible logs
   cd ~/voip-stack/ansible
   ansible-playbook playbooks/provision-vms.yml -vvv > debug.log 2>&1
   ```

2. **Verify Prerequisites**:
   - devstack-core running
   - VMs created with libvirt
   - Sufficient disk space and RAM

3. **Community Support**:
   - GitHub Issues: https://github.com/youruser/voip-stack/issues
   - Check existing issues first
   - Include logs and error messages

---

**Document Status**: Complete
**Last Updated**: 2025-12-18
