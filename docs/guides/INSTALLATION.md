# Installation Guide

Complete setup instructions for voip-stack using Lima VMs on Apple Silicon.

---

## Overview

voip-stack uses **Lima** for VM management, providing native Debian 12 ARM64 virtual machines with QEMU and Apple's Hypervisor Framework (HVF) for near-native performance.

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

### Step 1: Install Lima and Dependencies

```bash
# Install Lima and other tools
brew install lima ansible sngrep sipsak

# Verify installation
limactl --version
ansible --version
```

### Step 2: Clone voip-stack

```bash
cd ~
git clone https://github.com/NormB/voip-stack.git
cd voip-stack
```

### Step 3: Create VMs

```bash
# Create all VoIP VMs (downloads Debian 12 ARM64 image)
./scripts/lima-vms.sh create
```

This creates three Debian 12 (Bookworm) ARM64 VMs:

| VM | CPUs | Memory | Disk | Purpose |
|----|------|--------|------|---------|
| sip-1 | 2 | 2GB | 20GB | OpenSIPS SIP proxy |
| media-1 | 4 | 4GB | 20GB | RTPEngine media server |
| pbx-1 | 2 | 4GB | 20GB | Asterisk PBX |

### Step 4: Verify VM Status

```bash
./scripts/lima-vms.sh status
```

Expected output:
```
═══ voip-stack VM Status (Lima/Debian) ═══

NAME       STATUS     SSH                CPUS    MEMORY    DISK
media-1    Running    127.0.0.1:53569    4       4GiB      20GiB
pbx-1      Running    127.0.0.1:53712    2       4GiB      20GiB
sip-1      Running    127.0.0.1:53319    2       2GiB      20GiB
```

### Step 5: Generate Ansible Inventory

```bash
./scripts/lima-vms.sh inventory
```

This generates `ansible/inventory/lima.yml` with SSH configuration for each VM.

### Step 6: Provision with Ansible

```bash
./scripts/ansible-run.sh provision-vms
```

This installs and configures:
- OpenSIPS on sip-1
- RTPEngine on media-1
- Asterisk on pbx-1

---

## Verification

### Check VM Access

```bash
# Shell into VMs
./scripts/lima-vms.sh shell sip-1
./scripts/lima-vms.sh shell media-1
./scripts/lima-vms.sh shell pbx-1

# Or use limactl directly
limactl shell sip-1
```

### Check Services

```bash
# OpenSIPS status
limactl shell sip-1 -- systemctl status opensips

# RTPEngine status
limactl shell media-1 -- systemctl status rtpengine

# Asterisk status
limactl shell pbx-1 -- systemctl status asterisk
```

### Run Tests

```bash
./tests/run-phase1-tests.sh
```

---

## VM Management Commands

```bash
# Status
./scripts/lima-vms.sh status

# Start/Stop
./scripts/lima-vms.sh start
./scripts/lima-vms.sh stop

# Shell access
./scripts/lima-vms.sh shell <vm-name>

# Generate Ansible inventory
./scripts/lima-vms.sh inventory

# Destroy VMs (with confirmation)
./scripts/lima-vms.sh destroy
```

---

## SSH Access

Lima provides SSH access through auto-assigned ports. Access VMs using:

```bash
# Using lima-vms.sh wrapper
./scripts/lima-vms.sh shell sip-1

# Using limactl directly
limactl shell sip-1

# Using SSH with generated config
ssh -F ~/.lima/sip-1/ssh.config lima-sip-1
```

---

## Network Configuration

Lima VMs use user-mode networking (no sudo required):

- VMs can access the host via `host.lima.internal`
- Host services (devstack-core) are accessible from VMs
- VMs communicate with each other via the host network

---

## Next Steps

- [Ansible Provisioning](ANSIBLE-PROVISIONING.md) - Detailed provisioning guide
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Architecture Overview](../ARCHITECTURE.md) - Understand the system design

---

## Troubleshooting Quick Reference

**VM won't start**:
```bash
limactl list                        # Check VM status
limactl stop sip-1 && limactl start sip-1  # Restart VM
```

**SSH connection issues**:
```bash
# Check SSH port
limactl list | grep sip-1

# Test SSH directly
ssh -F ~/.lima/sip-1/ssh.config lima-sip-1
```

**Ansible fails**:
```bash
# Regenerate inventory
./scripts/lima-vms.sh inventory

# Check Vault is accessible
curl http://localhost:8200/v1/sys/health
```

**Full troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Document Status**: Complete
**Last Updated**: 2025-12-30
**Tested With**: macOS Sequoia 15.2, Lima 0.24+, Debian 12 (Bookworm) ARM64
