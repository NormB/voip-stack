# VoIP Stack Developer Guide

A comprehensive guide for developers new to voip-stack. This document covers everything you need to know to be productive, including architecture, setup, daily workflows, and troubleshooting.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Ansible Playbooks Reference](#ansible-playbooks-reference)
6. [VM Services Reference](#vm-services-reference)
7. [Daily Development Workflow](#daily-development-workflow)
8. [Configuration Reference](#configuration-reference)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)
11. [Key File Locations](#key-file-locations)

---

## Overview

**voip-stack** is a production-ready VoIP infrastructure platform for Apple Silicon Macs using libvirt/QEMU virtualization. It provides a three-tier VoIP architecture with:

- **SIP Proxy** (OpenSIPS) - Call routing and registration
- **PBX** (Asterisk) - Call processing and dialplans
- **Media Proxy** (RTPEngine) - RTP/SRTP media handling

The stack integrates with **devstack-core** which provides supporting infrastructure (Vault, PostgreSQL, Redis, RabbitMQ, monitoring).

### Key Characteristics

| Aspect | Description |
|--------|-------------|
| **Version** | 0.1.0-alpha (Phase 1) |
| **Platform** | macOS with Apple Silicon (M1/M2/M3/M4) |
| **Virtualization** | libvirt/QEMU with socket_vmnet networking |
| **Provisioning** | Ansible (Infrastructure as Code) |
| **Security** | TLS/SRTP encryption, Vault for secrets |

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         macOS Host (Apple Silicon)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Colima (Docker)                               │    │
│  │  ┌─────────┐ ┌──────────┐ ┌───────┐ ┌──────────┐ ┌───────────┐ │    │
│  │  │  Vault  │ │PostgreSQL│ │ Redis │ │ RabbitMQ │ │ Prometheus│ │    │
│  │  │  :8200  │ │  :5432   │ │ :6379 │ │  :5672   │ │   :9090   │ │    │
│  │  └─────────┘ └──────────┘ └───────┘ └──────────┘ └───────────┘ │    │
│  │  ┌─────────┐ ┌──────────┐ ┌───────┐                            │    │
│  │  │ Grafana │ │   Loki   │ │ Homer │                            │    │
│  │  │  :3001  │ │  :3100   │ │ :9080 │   (devstack-core)          │    │
│  │  └─────────┘ └──────────┘ └───────┘                            │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                 libvirt VMs (socket_vmnet)                       │    │
│  │                                                                  │    │
│  │   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │    │
│  │   │    sip-1      │  │    pbx-1      │  │   media-1     │       │    │
│  │   │  OpenSIPS     │  │   Asterisk    │  │  RTPEngine    │       │    │
│  │   │ 192.168.64.10 │  │ 192.168.64.30 │  │ 192.168.64.20 │       │    │
│  │   │  eth0 + eth1  │  │   eth0 only   │  │  eth0 + eth1  │       │    │
│  │   └───────────────┘  └───────────────┘  └───────────────┘       │    │
│  │                         (voip-stack)                             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Network Architecture

| Network | Subnet | Purpose |
|---------|--------|---------|
| **Internal (eth0)** | 192.168.64.0/24 | VM-to-VM, VM-to-devstack, management |
| **External (eth1)** | Bridged to LAN | External SIP/RTP (sip-1 and media-1 only) |

**Security Note**: The PBX (pbx-1) intentionally has NO external network interface. All external traffic must pass through the SIP proxy.

---

## Prerequisites

### Hardware Requirements

- macOS with Apple Silicon (M1/M2/M3/M4)
- 16GB RAM minimum (32GB+ recommended)
- 100GB+ free disk space

### Software Requirements

Install via Homebrew:

```bash
cd ~/voip-stack
brew bundle --file=Brewfile
```

This installs:
- **qemu** - VM emulation
- **libvirt** - Virtualization API
- **socket_vmnet** - VM networking (vmnet.framework)
- **ansible** - Infrastructure provisioning
- **ansible-lint** - Playbook validation
- **sngrep** - SIP message visualization
- **sipsak** - SIP testing utility

### devstack-core (Required Dependency)

voip-stack requires devstack-core running on the host. Clone and set up:

```bash
cd ~
git clone https://github.com/NormB/devstack-core
cd devstack-core
uv venv && uv pip install -r scripts/requirements.txt
cp .env.example .env
```

---

## Quick Start

### 1. Start devstack-core Infrastructure

```bash
cd ~/devstack-core
./devstack start --profile standard
./devstack vault-init
./devstack vault-bootstrap
```

### 2. Setup VM Networking (One-Time)

```bash
cd ~/voip-stack/libvirt
sudo ./setup-socket-vmnet.sh
```

### 3. Create and Start VMs

```bash
./create-vms.sh create
./create-vms.sh start
```

### 4. Provision with Ansible

```bash
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms
```

### 5. Verify

```bash
./tests/run-phase1-tests.sh
```

### Quick Connectivity Test

```bash
# Ping VMs
ping -c 1 192.168.64.10  # sip-1
ping -c 1 192.168.64.20  # media-1
ping -c 1 192.168.64.30  # pbx-1

# SSH into VMs
ssh voip@192.168.64.10   # sip-1
ssh voip@192.168.64.30   # pbx-1
ssh voip@192.168.64.20   # media-1
```

---

## Ansible Playbooks Reference

### Playbook Locations

All playbooks are in: `/Users/gator/voip-stack/ansible/playbooks/`

| Playbook | File | Purpose |
|----------|------|---------|
| **VM Provisioning** | `provision-vms.yml` | Main provisioning orchestrator |
| **VM Lifecycle** | `manage-libvirt-vms.yml` | Create/start/stop/destroy VMs |

### provision-vms.yml

**Location**: `ansible/playbooks/provision-vms.yml`

The main provisioning playbook applies roles in this order:

```
All VMs (voip_vms group):
├── common          # Base system setup, packages, kernel tuning
├── vault-client    # Vault AppRole authentication
├── docker          # Docker runtime (optional)
├── fail2ban        # Intrusion prevention
└── monitoring      # node_exporter, Promtail

SIP Proxies (sip_proxies group):
├── opensips        # SIP proxy 3.5+
└── kamailio        # Alternative proxy (Phase 1.5)

PBX Servers (pbx_servers group):
├── asterisk        # PBX system 20+
├── freeswitch      # Alternative PBX (Phase 2.5)
└── nfs-client      # Recording storage mount

Media Servers (media_servers group):
└── rtpengine       # Media proxy with kernel module
```

**Usage**:

```bash
# Full provisioning
./scripts/ansible-run.sh provision-vms

# Target specific groups
./scripts/ansible-run.sh provision-vms --limit sip_proxies
./scripts/ansible-run.sh provision-vms --limit pbx_servers
./scripts/ansible-run.sh provision-vms --limit media_servers

# Target specific roles via tags
./scripts/ansible-run.sh provision-vms --tags opensips
./scripts/ansible-run.sh provision-vms --tags asterisk
./scripts/ansible-run.sh provision-vms --tags rtpengine

# Dry run (check mode)
./scripts/ansible-run.sh provision-vms --check

# Verbose output
./scripts/ansible-run.sh provision-vms -vv
```

### manage-libvirt-vms.yml

**Location**: `ansible/playbooks/manage-libvirt-vms.yml`

Manages VM lifecycle via libvirt:

```bash
# Create VMs (download image, create disks, define)
ansible-playbook ansible/playbooks/manage-libvirt-vms.yml -e action=create

# Start all VMs
ansible-playbook ansible/playbooks/manage-libvirt-vms.yml -e action=start

# Stop VMs gracefully
ansible-playbook ansible/playbooks/manage-libvirt-vms.yml -e action=stop

# Destroy VMs and delete disks
ansible-playbook ansible/playbooks/manage-libvirt-vms.yml -e action=destroy

# Check status
ansible-playbook ansible/playbooks/manage-libvirt-vms.yml -e action=status
```

### Ansible Roles Reference

**Location**: `ansible/roles/`

| Role | Purpose | Key Tasks |
|------|---------|-----------|
| **common** | Base system | Hostname, packages, NTP, kernel tuning |
| **vault-client** | Secrets | AppRole auth, credential fetching |
| **docker** | Containers | Docker runtime, registry config |
| **network-config** | Networking | Static IPs, interfaces, routing |
| **fail2ban** | Security | Rate limiting, SIP-specific rules |
| **monitoring** | Metrics | node_exporter, Promtail |
| **opensips** | SIP proxy | OpenSIPS 3.5+ compilation/config |
| **asterisk** | PBX | Asterisk 20+, PJSIP, dialplan |
| **rtpengine** | Media | RTPEngine, kernel module |
| **kamailio** | Alt SIP | Kamailio 5.7+ (Phase 1.5) |
| **freeswitch** | Alt PBX | FreeSWITCH (Phase 2.5) |
| **nfs-client** | Storage | Mount recordings from media-1 |
| **nfs-server** | Storage | Export recordings directory |

---

## VM Services Reference

### VM Specifications

| VM | Hostname | IP Address | RAM | vCPUs | Disk | Networks |
|----|----------|------------|-----|-------|------|----------|
| **sip-1** | sip-1.voip.local | 192.168.64.10 | 2GB | 2 | 20GB | eth0 + eth1 |
| **pbx-1** | pbx-1.voip.local | 192.168.64.30 | 4GB | 2 | 30GB | eth0 only |
| **media-1** | media-1.voip.local | 192.168.64.20 | 4GB | 4 | 30GB | eth0 + eth1 |

### sip-1 Services (SIP Proxy)

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| **OpenSIPS** | 5060 | UDP/TCP | SIP signaling |
| **OpenSIPS TLS** | 5061 | TLS | Secure SIP |
| **OpenSIPS WS** | 8080 | WebSocket | WebRTC signaling |
| **OpenSIPS WSS** | 8443 | WSS | Secure WebSocket |
| **node_exporter** | 9100 | HTTP | Prometheus metrics |

**Check service status**:
```bash
ssh voip@192.168.64.10 'systemctl status opensips'
ssh voip@192.168.64.10 'opensipsctl fifo get_statistics all'
```

### pbx-1 Services (PBX)

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| **Asterisk** | 5060 | UDP/TCP | Internal SIP |
| **AMI** | 5038 | TCP | Management interface |
| **ARI** | 8088 | HTTP | REST interface |
| **node_exporter** | 9100 | HTTP | Prometheus metrics |

**Check service status**:
```bash
ssh voip@192.168.64.30 'systemctl status asterisk'
ssh voip@192.168.64.30 'asterisk -rx "core show channels"'
ssh voip@192.168.64.30 'asterisk -rx "pjsip show endpoints"'
```

### media-1 Services (Media Proxy)

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| **RTPEngine** | 2223 | UDP | NG control protocol |
| **RTP Range** | 10000-20000 | UDP | Media ports |
| **NFS Server** | 2049 | TCP/UDP | Recording storage |
| **node_exporter** | 9100 | HTTP | Prometheus metrics |

**Check service status**:
```bash
ssh voip@192.168.64.20 'systemctl status rtpengine'
ssh voip@192.168.64.20 'lsmod | grep xt_RTPENGINE'
ssh voip@192.168.64.20 'rtpengine-ctl list sessions'
```

### Service Dependencies

```
External SIP Client
       │
       ▼
   ┌───────┐
   │ sip-1 │ ──────────────────┐
   │OpenSIPS│                  │
   └───┬───┘                   │
       │ SIP                   │ RTPEngine control
       ▼                       ▼
   ┌───────┐              ┌─────────┐
   │ pbx-1 │              │ media-1 │
   │Asterisk│             │RTPEngine│
   └───────┘              └─────────┘
       │                       │
       │ NFS mount             │
       └───────────────────────┘
              /mnt/recordings
```

---

## Daily Development Workflow

### Starting the Environment

```bash
# 1. Start devstack-core (if not running)
cd ~/devstack-core
./devstack start --profile standard

# 2. Start VoIP VMs
cd ~/voip-stack/libvirt
./create-vms.sh start

# 3. Verify connectivity
ping -c 1 192.168.64.10
```

### Making Configuration Changes

```bash
# Edit Ansible configuration
vim ansible/roles/opensips/templates/opensips.cfg.j2

# Apply changes to specific component
./scripts/ansible-run.sh provision-vms --limit sip_proxies --tags opensips

# Or apply to all VMs
./scripts/ansible-run.sh provision-vms
```

### Testing Changes

```bash
# Run all tests
./tests/run-phase1-tests.sh

# Run specific tests
./tests/integration/test-opensips-status.sh
./tests/functional/test-basic-call.sh

# Manual SIP testing
sipsak -U -C sip:test@192.168.64.10 -s sip:1001@192.168.64.10
```

### Monitoring and Debugging

```bash
# Watch SIP traffic in real-time
sngrep -d any port 5060

# View service logs
ssh voip@192.168.64.10 'journalctl -u opensips -f'
ssh voip@192.168.64.30 'journalctl -u asterisk -f'

# Access Grafana dashboards
open http://localhost:3001

# Access Homer SIP capture
open http://localhost:9080
```

### Stopping the Environment

```bash
# Stop VMs
cd ~/voip-stack/libvirt
./create-vms.sh stop

# Stop devstack-core (optional)
cd ~/devstack-core
./devstack stop
```

### Rebuilding VMs

```bash
cd ~/voip-stack/libvirt

# Destroy existing VMs
./create-vms.sh destroy

# Recreate from scratch
./create-vms.sh create
./create-vms.sh start

# Re-provision
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms
```

---

## Configuration Reference

### Environment Variables

**File**: `.env` (copy from `.env.example`)

Key variables:

```bash
# Vault Configuration
VAULT_ADDR=http://192.168.64.1:8200
VAULT_ROLE_ID=<from devstack-core>
VAULT_SECRET_ID=<from devstack-core>

# Database (via devstack-core)
POSTGRES_HOST=192.168.64.1
POSTGRES_PORT=5432

# Redis (via devstack-core)
REDIS_HOST=192.168.64.1
REDIS_PORT=6379

# SIP Configuration
SIP_DOMAIN=sip.local
SIP_PROXY_HOST=192.168.64.10

# RTPEngine
RTPENGINE_HOST=192.168.64.20
RTPENGINE_PORT=2223
RTP_PORT_MIN=10000
RTP_PORT_MAX=20000
```

### Ansible Inventory

**File**: `ansible/inventory/development.yml`

Defines:
- VM hostnames and IP addresses
- Group memberships (sip_proxies, pbx_servers, media_servers)
- Component enablement flags
- Network interface assignments

### Global Ansible Variables

**File**: `ansible/group_vars/all.yml`

Contains:
- devstack-core service endpoints
- Installation methods (docker vs package vs source)
- Database configuration per component
- Security settings
- Monitoring configuration

### VM Definitions

**Location**: `libvirt/domains/`

- `sip-1.xml` - SIP proxy VM definition
- `pbx-1.xml` - PBX VM definition
- `media-1.xml` - Media proxy VM definition

### Cloud-init Configuration

**Location**: `libvirt/cloud-init/`

- `user-data.yaml.tpl` - User setup, SSH keys, packages
- `meta-data.yaml.tpl` - Instance metadata
- `network-config-*.yaml` - Per-VM network configuration

---

## Testing

### Test Framework Location

**Directory**: `/Users/gator/voip-stack/tests/`

### Running Tests

```bash
# Run all Phase 1 tests
./tests/run-phase1-tests.sh

# Verbose output
./tests/run-phase1-tests.sh --verbose

# Test log location
# /tmp/voip-stack-tests-YYYYMMDD-HHMMSS.log
```

### Test Categories

| Category | Location | Purpose |
|----------|----------|---------|
| **Integration** | `tests/integration/` | Component connectivity, devstack integration |
| **Functional** | `tests/functional/` | SIP flows, call scenarios |
| **Security** | `tests/security/` | TLS, SRTP, authentication |
| **Load** | `tests/sipp/` | SIPp load testing scenarios |
| **Quality** | `tests/quality/` | Code style, linting |

### Individual Test Scripts

```bash
# Integration tests
./tests/integration/test-vault-integration.sh
./tests/integration/test-postgres-connectivity.sh
./tests/integration/test-redis-connectivity.sh
./tests/integration/test-opensips-status.sh
./tests/integration/test-asterisk-status.sh
./tests/integration/test-rtpengine-status.sh

# Functional tests
./tests/functional/test-basic-call.sh

# Security tests
./tests/security/test-tls-connectivity.sh
./tests/security/test-srtp.sh
```

### SIPp Load Testing

```bash
# Basic registration test
sipp 192.168.64.10:5060 -sf tests/sipp/scenarios/register.xml -m 10

# Basic call test
sipp 192.168.64.10:5060 -sf tests/sipp/scenarios/uac.xml -s 1002 -m 1
```

---

## Troubleshooting

### VM Won't Start

```bash
# Check VM status
virsh -c qemu:///session list --all

# Check socket_vmnet
ls -la /opt/homebrew/var/run/socket_vmnet*

# Restart socket_vmnet if needed
sudo launchctl unload /Library/LaunchDaemons/io.github.lima-vm.socket_vmnet.plist
sudo launchctl load /Library/LaunchDaemons/io.github.lima-vm.socket_vmnet.plist

# Check libvirt logs
cat ~/.local/share/libvirt/qemu/log/*
```

### Can't SSH to VM

```bash
# Check VM is running
virsh -c qemu:///session list

# Check IP assignment (via console)
virsh -c qemu:///session console sip-1
# Login and check: ip addr show

# Verify SSH key
ssh -v voip@192.168.64.10
```

### Service Not Running

```bash
# Check service status
ssh voip@192.168.64.10 'systemctl status opensips'

# View logs
ssh voip@192.168.64.10 'journalctl -u opensips -n 100'

# Re-run Ansible for specific service
./scripts/ansible-run.sh provision-vms --limit sip_proxies --tags opensips
```

### devstack-core Not Reachable

```bash
# Check devstack-core is running
cd ~/devstack-core
./devstack status

# Check Vault
curl http://localhost:8200/v1/sys/health

# Check PostgreSQL
psql -h localhost -U postgres -c "SELECT 1"
```

### SIP Registration Fails

```bash
# Monitor SIP traffic
sngrep -d any port 5060

# Test with sipsak
sipsak -U -C sip:test@192.168.64.10 -s sip:1001@192.168.64.10

# Check OpenSIPS logs
ssh voip@192.168.64.10 'journalctl -u opensips -f'

# Check Homer for SIP captures
open http://localhost:9080
```

### RTPEngine Kernel Module Not Loaded

```bash
# Check module
ssh voip@192.168.64.20 'lsmod | grep xt_RTPENGINE'

# Load module
ssh voip@192.168.64.20 'sudo modprobe xt_RTPENGINE'

# Rebuild if needed (re-run Ansible)
./scripts/ansible-run.sh provision-vms --limit media_servers --tags rtpengine
```

---

## Key File Locations

### Quick Reference

```
voip-stack/
├── ansible/
│   ├── ansible.cfg                    # Ansible configuration
│   ├── inventory/development.yml      # VM inventory
│   ├── group_vars/all.yml            # Global variables
│   ├── playbooks/
│   │   ├── provision-vms.yml         # Main provisioning
│   │   └── manage-libvirt-vms.yml    # VM lifecycle
│   └── roles/                        # 13 Ansible roles
│       ├── opensips/                 # SIP proxy role
│       ├── asterisk/                 # PBX role
│       └── rtpengine/                # Media role
├── libvirt/
│   ├── create-vms.sh                 # VM management script
│   ├── setup-socket-vmnet.sh         # Network setup
│   ├── domains/                      # VM XML definitions
│   │   ├── sip-1.xml
│   │   ├── pbx-1.xml
│   │   └── media-1.xml
│   └── cloud-init/                   # Cloud-init configs
├── scripts/
│   └── ansible-run.sh                # Ansible wrapper
├── tests/
│   ├── run-phase1-tests.sh           # Test orchestrator
│   ├── integration/                  # Integration tests
│   ├── functional/                   # Functional tests
│   └── sipp/                         # Load test scenarios
├── docs/                             # Documentation
├── .env.example                      # Environment template
└── Brewfile                          # Homebrew dependencies
```

### devstack-core Integration Points

| Service | Host:Port | Used By |
|---------|-----------|---------|
| Vault | 192.168.64.1:8200 | All VMs (secrets) |
| PostgreSQL | 192.168.64.1:5432 | OpenSIPS, Asterisk, Homer |
| Redis | 192.168.64.1:6379 | OpenSIPS (session state) |
| RabbitMQ | 192.168.64.1:5672 | Asterisk (CDRs) |
| Prometheus | 192.168.64.1:9090 | Metrics collection |
| Grafana | 192.168.64.1:3001 | Dashboards |
| Loki | 192.168.64.1:3100 | Log aggregation |
| Homer | 192.168.64.1:9080 | SIP capture |

---

## Next Steps

After completing this guide:

1. **Read the Architecture Documentation**: `docs/ARCHITECTURE.md` for deeper understanding
2. **Review Architecture Decisions**: `docs/ARCHITECTURE_DECISIONS.md` for design rationale
3. **Explore Example Configurations**: `examples/` directory
4. **Check Troubleshooting Guide**: `docs/guides/TROUBLESHOOTING.md` for detailed solutions

For questions or issues, consult the existing documentation in `docs/` or check the GitHub issues.
