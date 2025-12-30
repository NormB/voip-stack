# Installation Guide

Complete setup instructions for voip-stack.

---

## Virtualization

voip-stack uses **libvirt/QEMU** for VM management, providing full CLI automation and CI/CD compatibility.

---

## Prerequisites

### System Requirements

- **macOS**: Apple Silicon (M1/M2/M3/M4)
- **RAM**: 16GB minimum, 32GB+ recommended
- **Storage**: 100GB+ free space
- **Homebrew**: Latest version

### Infrastructure Services

voip-stack requires [devstack-core](https://github.com/NormB/devstack-core) running:

```bash
# Clone and start devstack-core
cd ~/
git clone https://github.com/NormB/devstack-core
cd devstack-core
uv venv && uv pip install -r scripts/requirements.txt
cp .env.example .env
./devstack start --profile standard
./devstack vault-init
./devstack vault-bootstrap
```

**Services provided**:
- Vault (secrets management)
- PostgreSQL 16 + TimescaleDB
- Redis (session state)
- RabbitMQ (CDR publishing)
- Prometheus + Grafana
- Loki (logs)
- Homer (SIP capture)

---

## Installation Steps

Full CLI automation using libvirt, QEMU, and cloud-init.

### Step 1: Install Dependencies

```bash
# Install QEMU, libvirt, and socket_vmnet
brew install qemu libvirt socket_vmnet

# Verify installation
qemu-system-aarch64 --version
virsh --version
```

### Step 2: Setup Networking

socket_vmnet provides rootless vmnet.framework networking for QEMU.

```bash
cd ~/voip-stack/libvirt

# Install networking services (requires sudo)
sudo ./setup-socket-vmnet.sh

# Verify sockets are created
ls -la /opt/homebrew/var/run/socket_vmnet*
```

### Step 3: Create VMs

```bash
cd ~/voip-stack/libvirt

# Create all VMs (downloads Debian image, creates disks, defines VMs)
./create-vms.sh create
```

Or use Ansible:

```bash
cd ~/voip-stack/ansible
ansible-playbook playbooks/manage-libvirt-vms.yml -e action=create
```

### Step 4: Start VMs

```bash
# Start all VMs
./create-vms.sh start

# Or with Ansible
ansible-playbook playbooks/manage-libvirt-vms.yml -e action=start
```

### Step 5: Verify VM Access

```bash
# Wait 30-60 seconds for boot, then SSH
ssh debian@192.168.64.10  # sip-1
ssh debian@192.168.64.30  # pbx-1
ssh debian@192.168.64.20  # media-1
```

### Step 6: Deploy VoIP Components

```bash
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms
```

For detailed libvirt documentation, see: [libvirt/README.md](../../libvirt/README.md)

---

## Verification

### Check Services

```bash
# Check VMs are running
virsh -c qemu:///session list --all

# SSH to each VM
ssh debian@192.168.64.10  # sip-1
ssh debian@192.168.64.30  # pbx-1
ssh debian@192.168.64.20  # media-1

# Check service status
ssh debian@192.168.64.10 "systemctl status opensips"
ssh debian@192.168.64.30 "systemctl status asterisk"
ssh debian@192.168.64.20 "systemctl status rtpengine"
```

### Run Tests

```bash
cd ~/voip-stack
./tests/run-phase1-tests.sh
```

### Test SIP Registration

```bash
# Basic SIPp test
sipp 192.168.64.10:5060 -sf tests/sipp/scenarios/register.xml -m 1
```

---

## Next Steps

- [Testing Guide](TESTING.md) - Comprehensive testing procedures
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Architecture Overview](../ARCHITECTURE.md) - Understand the system design

---

## Troubleshooting Quick Reference

**VMs won't start**:
```bash
virsh -c qemu:///session list --all  # Check VM status
virsh -c qemu:///session start sip-1  # Try starting manually
ls /opt/homebrew/var/run/socket_vmnet*  # Check networking
```

**SSH connection refused**:
```bash
ping 192.168.64.10  # Test connectivity
# Wait 60-90 seconds for cloud-init to complete
```

**Ansible fails**:
```bash
# Check Vault is accessible
curl http://192.168.64.1:8200/v1/sys/health

# Check PostgreSQL
psql -h 192.168.64.1 -U postgres -l
```

**Full troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Document Status**: Complete
**Last Updated**: 2025-12-17
**Tested With**: macOS Sequoia 15.1, libvirt/QEMU, Debian 12 (Bookworm)
