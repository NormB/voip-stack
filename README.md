# voip-stack

> **Production-ready VoIP infrastructure for Apple Silicon Macs, powered by libvirt/QEMU virtualization**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon-lightgrey.svg)](https://www.apple.com/mac/)
[![libvirt](https://img.shields.io/badge/libvirt-9.0+-blue.svg)](https://libvirt.org/)
[![Ansible](https://img.shields.io/badge/ansible-2.10+-green.svg)](https://www.ansible.com/)

A complete, security-first VoIP platform featuring OpenSIPS, Asterisk, and RTPEngine. Designed for production deployments, development, learning, and as a reference architecture for enterprise VoIP infrastructure.

---

## Key Features

- **Complete VoIP Stack** - OpenSIPS (SIP proxy) + Asterisk (PBX) + RTPEngine (media)
- **Security-First** - TLS/SRTP encryption, HashiCorp Vault integration, network isolation
- **Apple Silicon Optimized** - Native ARM64 support via libvirt/QEMU virtualization
- **Infrastructure as Code** - Ansible-based provisioning and configuration
- **Comprehensive Testing** - SIPp scenarios, integration tests, functional tests
- **Full Observability** - Prometheus, Grafana, Loki, Homer SIP capture
- **Production-Grade** - High-availability architecture, designed for real deployments

## Quick Start

Get up and running in 15 minutes:

```bash
# 1. Install prerequisites
brew bundle --file=Brewfile

# 2. Clone and setup
git clone https://github.com/NormB/voip-stack.git ~/voip-stack
cd ~/voip-stack

# 3. Configure environment
cp .env.example .env
# Edit .env with your Vault address and network settings

# 4. Ensure devstack-core is running
cd ~/devstack-core && ./devstack start --profile standard

# 5. Create and start VoIP VMs
cd ~/voip-stack/libvirt
./create-vms.sh create
./create-vms.sh start

# 6. Provision VMs with Ansible
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms

# 7. Verify installation
./tests/run-phase1-tests.sh
```

**Access your services:**
- **SIP Proxy (OpenSIPS):** 192.168.64.10:5060 (UDP), 5061 (TLS)
- **PBX (Asterisk):** 192.168.64.30:5080 (internal only)
- **Media (RTPEngine):** 192.168.64.20:10000-20000 (RTP)
- **Homer SIP Capture:** http://localhost:9080

## Prerequisites

**Required:**
- macOS with Apple Silicon (M1/M2/M3/M4)
- 16GB+ RAM (8GB minimum)
- 100GB+ free disk space
- [devstack-core](https://github.com/NormB/devstack-core) running

**Software (auto-installed via Brewfile):**
- libvirt/QEMU (virtualization)
- socket_vmnet (VM networking)
- Ansible (provisioning)
- sngrep, sipsak (VoIP testing)

## Architecture

```
External SIP Clients
         |
         v
+---------------------------+
| sip-1 (192.168.64.10)     |
| +----------+ +---------+  |
| | OpenSIPS | | Kamailio|  |  <- Phase 1.5
| | :5060    | | :5070   |  |
| +----------+ +---------+  |
+------------|--------------+
             v
+---------------------------+
| pbx-1 (192.168.64.30)     |
| +----------+ +----------+ |
| | Asterisk | | FreeSWITCH| <- Phase 2.5
| | :5080    | | :5090    | |
| +----------+ +----------+ |
+------------|--------------+
             v
+---------------------------+
| media-1 (192.168.64.20)   |
| +----------------------+  |
| | RTPEngine            |  |
| | :10000-20000 (RTP)   |  |
| +----------------------+  |
+---------------------------+
             |
             v
+---------------------------+
| devstack-core (Mac host)  |
| - Vault (secrets, PKI)    |
| - PostgreSQL (databases)  |
| - Redis (caching)         |
| - RabbitMQ (messaging)    |
| - Prometheus/Grafana      |
| - Loki (logs)             |
| - Homer (SIP capture)     |
+---------------------------+
```

### Three-Tier Design

| Tier | VM | IP | Component | Network |
|------|----|----|-----------|---------|
| **SIP Proxy** | sip-1 | 192.168.64.10 | OpenSIPS 3.4+ | eth0 + eth1 |
| **PBX** | pbx-1 | 192.168.64.30 | Asterisk 20+ | eth0 only (isolated) |
| **Media** | media-1 | 192.168.64.20 | RTPEngine | eth0 + eth1 |

**Security Note:** The PBX VM has no external network interface, ensuring all external traffic passes through the SIP proxy.

## Roadmap

### Phase 1 (Current)
- OpenSIPS SIP proxy with registration
- Asterisk PBX with basic dialplan
- RTPEngine media proxy
- TLS/SRTP encryption
- Vault integration (AppRole auth)
- PostgreSQL databases
- Homer SIP capture
- Basic monitoring

### Phase 2 (Planned)
- High availability with failover
- Kamailio alternative SIP proxy
- FreeSWITCH alternative PBX
- Load balancing
- Multi-instance deployments

### Phase 3+ (Future)
- WebRTC with Janus gateway
- Prometheus alerting
- Real-time call dashboards
- Kubernetes deployment
- CI/CD pipelines

## Usage

### Management Commands

```bash
# Create and start VMs (libvirt)
cd libvirt && ./create-vms.sh create && ./create-vms.sh start && cd ..

# Run Ansible playbook
./scripts/ansible-run.sh provision-vms
./scripts/ansible-run.sh provision-vms --limit sip_proxies
./scripts/ansible-run.sh provision-vms --tags opensips

# Run tests
./tests/run-phase1-tests.sh
./tests/run-phase1-tests.sh --verbose

# libvirt VM management
cd libvirt
./create-vms.sh status
./create-vms.sh start
./create-vms.sh stop
virsh -c qemu:///session list --all
```

### Testing

```bash
# Run all Phase 1 tests
./tests/run-phase1-tests.sh

# Individual test categories
./tests/integration/test-vault-integration.sh
./tests/functional/test-basic-call.sh

# SIPp load testing
sipp 192.168.64.10:5060 -sf tests/sipp/scenarios/uac.xml -s 1002 -m 1
```

### SIP Debugging

```bash
# Monitor SIP traffic on Mac
sngrep -d any port 5060

# Monitor on VMs
ssh admin@192.168.64.10 'sngrep -d eth0 port 5060'

# Test registration
sipsak -U -C sip:test@192.168.64.10 -s sip:1001@192.168.64.10
```

## Documentation

### Getting Started
- **[Installation Guide](docs/guides/INSTALLATION.md)** - Complete setup instructions
- **[Phase 1 Implementation](docs/guides/PHASE_1_IMPLEMENTATION.md)** - Week-by-week roadmap
- **[Troubleshooting](docs/guides/TROUBLESHOOTING.md)** - Common issues and solutions

### Architecture
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design with diagrams
- **[Architecture Decisions](docs/ARCHITECTURE_DECISIONS.md)** - 17 ADRs with rationale
- **[Network Topology](docs/reference/NETWORK_TOPOLOGY.md)** - Network design

### Component Guides
- **[OpenSIPS Configuration](docs/reference/OPENSIPS.md)** - SIP proxy setup
- **[Asterisk Configuration](docs/reference/ASTERISK.md)** - PBX configuration
- **[RTPEngine Setup](docs/reference/RTPENGINE.md)** - Media proxy setup
- **[Vault Integration](docs/reference/VAULT_INTEGRATION.md)** - Secrets management

### Operations
- **[Testing Guide](docs/guides/TESTING.md)** - Test framework usage
- **[Security Best Practices](docs/guides/SECURITY.md)** - Security hardening

## Component Versions

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenSIPS | 3.4+ | SIP proxy, registration, routing |
| Asterisk | 20+ LTS | PBX, call processing, features |
| RTPEngine | Latest | Media proxy, NAT traversal, SRTP |
| Kamailio | 5.7+ | Alternative SIP proxy (Phase 1.5) |
| FreeSWITCH | Latest | Alternative PBX (Phase 2.5) |
| PostgreSQL | 16+ | Database with TimescaleDB |
| Vault | 1.15+ | Secrets and PKI management |

## Project Structure

```
voip-stack/
├── ansible/              # Infrastructure as Code
│   ├── roles/           # Component roles
│   ├── playbooks/       # Provisioning playbooks
│   └── inventory/       # VM inventory
├── configs/             # Configuration templates
│   └── templates/       # Jinja2 templates
├── docs/                # Documentation (8,000+ lines)
│   ├── guides/          # How-to guides
│   └── reference/       # Technical reference
├── scripts/             # Helper scripts
├── tests/               # Test framework
│   ├── integration/     # Connectivity tests
│   ├── functional/      # SIP flow tests
│   ├── security/        # TLS/auth tests
│   └── sipp/            # Load test scenarios
└── vms/                 # VM-specific configs
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](.github/CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit with conventional messages: `git commit -m 'feat: add amazing feature'`
5. Push to your fork: `git push origin feature/amazing-feature`
6. Open a Pull Request

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgements

Built with excellent open-source software:

- [OpenSIPS](https://opensips.org/) - High-performance SIP proxy
- [Asterisk](https://www.asterisk.org/) - Open source PBX
- [RTPEngine](https://github.com/sipwise/rtpengine) - Media proxy
- [Homer](https://sipcapture.org/) - SIP capture and troubleshooting
- [HashiCorp Vault](https://www.vaultproject.io/) - Secrets management
- [TimescaleDB](https://www.timescale.com/) - Time-series database
- [devstack-core](https://github.com/NormB/devstack-core) - Infrastructure services
- [libvirt](https://libvirt.org/) - Virtualization API
- [QEMU](https://www.qemu.org/) - Machine emulator

Special thanks to the VoIP open-source community.

## Development Philosophy

This project follows these principles:

- **Production-First** - Built for real-world deployments from day one
- **Security-First** - TLS/SRTP, Vault, least privilege, network isolation
- **Documentation-Driven** - Every decision documented with reasoning
- **Test-Driven** - Comprehensive testing at every layer
- **Mac-Friendly** - Optimized for Apple Silicon development
- **Open by Default** - Transparent development, public decisions

---

**Questions or feedback?** [Open an issue](https://github.com/NormB/voip-stack/issues)

**Development Platform:** macOS (Apple Silicon) with libvirt/QEMU virtualization
