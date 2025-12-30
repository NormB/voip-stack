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

**voip-stack** is a production-ready VoIP infrastructure platform for Apple Silicon Macs using Lima/QEMU virtualization with Debian 12 ARM64 VMs. It provides a three-tier VoIP architecture with:

- **SIP Proxy** (OpenSIPS) - Call routing and registration
- **PBX** (Asterisk) - Call processing and dialplans
- **Media Proxy** (RTPEngine) - RTP/SRTP media handling

The stack integrates with **devstack-core** which provides supporting infrastructure (Vault, PostgreSQL, Redis, RabbitMQ, monitoring).

### Key Characteristics

| Aspect | Description |
|--------|-------------|
| **Version** | 0.1.0-alpha (Phase 1) |
| **Platform** | macOS with Apple Silicon (M1/M2/M3/M4) |
| **Virtualization** | Lima with QEMU/HVF (Debian 12 ARM64) |
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
│  │                 Lima VMs (QEMU/HVF)                              │    │
│  │                 Debian 12 (Bookworm) ARM64                       │    │
│  │                                                                  │    │
│  │   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │    │
│  │   │    sip-1      │  │    pbx-1      │  │   media-1     │       │    │
│  │   │  OpenSIPS     │  │   Asterisk    │  │  RTPEngine    │       │    │
│  │   │ 2 CPU / 2GB   │  │ 2 CPU / 4GB   │  │ 4 CPU / 4GB   │       │    │
│  │   │ SSH: auto     │  │ SSH: auto     │  │ SSH: auto     │       │    │
│  │   └───────────────┘  └───────────────┘  └───────────────┘       │    │
│  │                         (voip-stack)                             │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Network Architecture

Lima uses user-mode networking (no sudo required):
- VMs access host services via `host.lima.internal`
- SSH access via auto-assigned localhost ports
- devstack-core services reachable from VMs

**Access VMs:**
```bash
./scripts/lima-vms.sh shell sip-1     # Shell into sip-1
limactl shell media-1                 # Alternative access
ssh -F ~/.lima/pbx-1/ssh.config lima-pbx-1  # Direct SSH
```

---

## Prerequisites

### Hardware Requirements

- macOS with Apple Silicon (M1/M2/M3/M4)
- 16GB RAM minimum (32GB+ recommended)
- 100GB+ free disk space

### Software Requirements

Install via Homebrew:

```bash
brew install lima ansible sngrep sipsak
```

This installs:
- **lima** - Linux VM manager with QEMU/HVF
- **ansible** - Infrastructure provisioning
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

### 2. Create VMs with Lima

```bash
cd ~/voip-stack
./scripts/lima-vms.sh create
```

### 3. Generate Ansible Inventory

```bash
./scripts/lima-vms.sh inventory
```

### 4. Provision with Ansible

```bash
./scripts/ansible-run.sh provision-vms
```

### 5. Verify

```bash
./tests/run-phase1-tests.sh
```

### Quick Connectivity Test

```bash
# Check VM status
./scripts/lima-vms.sh status

# Shell into VMs
./scripts/lima-vms.sh shell sip-1
./scripts/lima-vms.sh shell media-1
./scripts/lima-vms.sh shell pbx-1

# Or use limactl directly
limactl shell sip-1
```

---

## Ansible Playbooks Reference

### Playbook Locations

All playbooks are in: `~/voip-stack/ansible/playbooks/`

| Playbook | File | Purpose |
|----------|------|---------|
| **VM Provisioning** | `provision-vms.yml` | Main provisioning orchestrator |

**Note:** VM lifecycle is managed by Lima via `./scripts/lima-vms.sh`, not Ansible.

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

### Lima VM Management

VM lifecycle is managed by the Lima wrapper script:

```bash
# Create VMs (downloads Debian 12 ARM64, creates VMs)
./scripts/lima-vms.sh create

# Start/stop VMs
./scripts/lima-vms.sh start
./scripts/lima-vms.sh stop

# Check status
./scripts/lima-vms.sh status

# Shell into VM
./scripts/lima-vms.sh shell sip-1

# Generate Ansible inventory
./scripts/lima-vms.sh inventory

# Destroy VMs (with confirmation)
./scripts/lima-vms.sh destroy
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

All VMs run Debian 12 (Bookworm) ARM64 via Lima:

| VM | Hostname | CPUs | RAM | Disk | Purpose |
|----|----------|------|-----|------|---------|
| **sip-1** | sip-1 | 2 | 2GB | 20GB | OpenSIPS SIP proxy |
| **media-1** | media-1 | 4 | 4GB | 20GB | RTPEngine media server |
| **pbx-1** | pbx-1 | 2 | 4GB | 20GB | Asterisk PBX |

**Access:** `./scripts/lima-vms.sh shell <vm-name>` or `limactl shell <vm-name>`

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
limactl shell sip-1 -- systemctl status opensips
limactl shell sip-1 -- opensipsctl fifo get_statistics all
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
limactl shell pbx-1 -- systemctl status asterisk
limactl shell pbx-1 -- asterisk -rx "core show channels"
limactl shell pbx-1 -- asterisk -rx "pjsip show endpoints"
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
limactl shell media-1 -- systemctl status rtpengine
limactl shell media-1 -- lsmod | grep xt_RTPENGINE
limactl shell media-1 -- rtpengine-ctl list sessions
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
cd ~/voip-stack
./scripts/lima-vms.sh start

# 3. Verify VMs are running
./scripts/lima-vms.sh status
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
# Watch SIP traffic inside VM
./scripts/lima-vms.sh shell sip-1
sngrep -d eth0 port 5060

# View service logs
limactl shell sip-1 -- journalctl -u opensips -f
limactl shell pbx-1 -- journalctl -u asterisk -f

# Access Grafana dashboards
open http://localhost:3001

# Access Homer SIP capture
open http://localhost:9080
```

### Stopping the Environment

```bash
# Stop VMs
./scripts/lima-vms.sh stop

# Stop devstack-core (optional)
cd ~/devstack-core
./devstack stop
```

### Rebuilding VMs

```bash
# Destroy existing VMs
./scripts/lima-vms.sh destroy

# Recreate from scratch
./scripts/lima-vms.sh create

# Re-provision
./scripts/lima-vms.sh inventory
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

**File**: `ansible/inventory/lima.yml` (generated by `./scripts/lima-vms.sh inventory`)

Defines:
- VM hostnames and SSH configurations
- Group memberships (sip_proxies, pbx_servers, media_servers)
- Component enablement flags

### Global Ansible Variables

**File**: `ansible/group_vars/all.yml`

Contains:
- devstack-core service endpoints
- Installation methods (docker vs package vs source)
- Database configuration per component
- Security settings
- Monitoring configuration

### Lima VM Configurations

**Location**: `lima/`

- `sip-1.yaml` - SIP proxy VM config (2 CPU, 2GB RAM)
- `media-1.yaml` - Media server VM config (4 CPU, 4GB RAM)
- `pbx-1.yaml` - PBX VM config (2 CPU, 4GB RAM)

Each YAML file defines:
- Debian 12 ARM64 cloud image
- Resource allocation (CPU, memory, disk)
- Provisioning script (packages, hostname)
- SSH access configuration

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
limactl list

# Check specific VM
limactl info sip-1

# Stop and restart VM
limactl stop sip-1
limactl start sip-1

# Check Lima logs
cat ~/.lima/sip-1/ha.stderr.log
```

### Can't Access VM

```bash
# Check VM is running
limactl list

# Try shell access
limactl shell sip-1

# Check SSH config
cat ~/.lima/sip-1/ssh.config

# Direct SSH with verbose
ssh -v -F ~/.lima/sip-1/ssh.config lima-sip-1
```

### Service Not Running

```bash
# Check service status
limactl shell sip-1 -- systemctl status opensips

# View logs
limactl shell sip-1 -- journalctl -u opensips -n 100

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
# Monitor SIP traffic inside VM
limactl shell sip-1
sngrep -d eth0 port 5060

# Check OpenSIPS logs
limactl shell sip-1 -- journalctl -u opensips -f

# Check Homer for SIP captures
open http://localhost:9080
```

### RTPEngine Kernel Module Not Loaded

```bash
# Check module
limactl shell media-1 -- lsmod | grep xt_RTPENGINE

# Load module
limactl shell media-1 -- sudo modprobe xt_RTPENGINE

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
│   ├── inventory/lima.yml             # VM inventory (generated)
│   ├── group_vars/all.yml            # Global variables
│   ├── playbooks/
│   │   └── provision-vms.yml         # Main provisioning
│   └── roles/                        # Ansible roles
│       ├── opensips/                 # SIP proxy role
│       ├── asterisk/                 # PBX role
│       └── rtpengine/                # Media role
├── lima/                             # Lima VM configurations
│   ├── sip-1.yaml                    # SIP proxy VM
│   ├── media-1.yaml                  # Media server VM
│   └── pbx-1.yaml                    # PBX VM
├── scripts/
│   ├── lima-vms.sh                   # VM lifecycle management
│   └── ansible-run.sh                # Ansible wrapper
├── tests/
│   ├── run-phase1-tests.sh           # Test orchestrator
│   ├── integration/                  # Integration tests
│   ├── functional/                   # Functional tests
│   └── sipp/                         # Load test scenarios
├── docs/                             # Documentation
├── archive/                          # Archived implementations
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
