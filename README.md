# voip-stack

> **Production-ready VoIP infrastructure for Apple Silicon Macs, powered by Lima/QEMU virtualization**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon-lightgrey.svg)](https://www.apple.com/mac/)
[![Lima](https://img.shields.io/badge/Lima-0.20+-blue.svg)](https://lima-vm.io/)
[![Ansible](https://img.shields.io/badge/ansible-2.10+-green.svg)](https://www.ansible.com/)

A complete, security-first VoIP platform featuring OpenSIPS, Asterisk, and RTPEngine. Designed for production deployments, development, learning, and as a reference architecture for enterprise VoIP infrastructure.

---

## Key Features

- **Complete VoIP Stack** - OpenSIPS (SIP proxy) + Asterisk (PBX) + RTPEngine (media)
- **Security-First** - TLS/SRTP encryption, HashiCorp Vault integration, network isolation
- **Apple Silicon Optimized** - Native ARM64 Debian 12 VMs via Lima/QEMU
- **Infrastructure as Code** - Ansible-based provisioning and configuration
- **Comprehensive Testing** - SIPp scenarios, integration tests, functional tests
- **Full Observability** - Prometheus, Grafana, Loki, Homer SIP capture
- **Production-Grade** - High-availability architecture, designed for real deployments

## Quick Start

Get up and running in 15 minutes:

```bash
# 1. Install prerequisites
brew install lima ansible

# 2. Clone and setup
git clone https://github.com/NormB/voip-stack.git ~/voip-stack
cd ~/voip-stack

# 3. Configure environment
cp .env.example .env
# Edit .env with your Vault address and network settings

# 4. Ensure devstack-core is running
cd ~/devstack-core && ./devstack start --profile standard

# 5. Create and start VoIP VMs (Debian 12 ARM64)
cd ~/voip-stack
./scripts/lima-vms.sh create

# 6. Generate Ansible inventory and provision
./scripts/lima-vms.sh inventory
./scripts/ansible-run.sh provision-vms

# 7. Verify installation
./tests/run-phase1-tests.sh
```

**Access your VMs:**
```bash
./scripts/lima-vms.sh status           # View VM status and SSH ports
./scripts/lima-vms.sh shell sip-1      # Shell into sip-1
./scripts/lima-vms.sh shell media-1    # Shell into media-1
./scripts/lima-vms.sh shell pbx-1      # Shell into pbx-1
```

**Services (inside VMs):**
- **SIP Proxy (OpenSIPS):** sip-1:5060 (UDP), 5061 (TLS)
- **PBX (Asterisk):** pbx-1:5080 (internal only)
- **Media (RTPEngine):** media-1:10000-20000 (RTP)
- **Homer SIP Capture:** http://localhost:9080 (on host)

## Prerequisites

**Required:**
- macOS with Apple Silicon (M1/M2/M3/M4)
- 16GB+ RAM (8GB minimum)
- 100GB+ free disk space
- [devstack-core](https://github.com/NormB/devstack-core) running

**Software:**
```bash
brew install lima ansible sngrep sipsak
```
- Lima (VM management with QEMU/HVF)
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

| Tier | VM | Resources | Component | Purpose |
|------|-----|-----------|-----------|---------|
| **SIP Proxy** | sip-1 | 2 CPU, 2GB RAM | OpenSIPS 3.4+ | Registration, routing |
| **Media** | media-1 | 4 CPU, 4GB RAM | RTPEngine | Media relay, NAT traversal |
| **PBX** | pbx-1 | 2 CPU, 4GB RAM | Asterisk 20+ | Call processing, features |

**VM Access:** All VMs run Debian 12 (Bookworm) ARM64 and are accessed via Lima's SSH tunneling. Use `./scripts/lima-vms.sh shell <vm>` or the generated SSH configs.

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

### VM Management (Lima)

```bash
# Create all VMs (downloads Debian 12 ARM64, starts VMs)
./scripts/lima-vms.sh create

# VM lifecycle
./scripts/lima-vms.sh status     # Show VM status and SSH ports
./scripts/lima-vms.sh start      # Start all VMs
./scripts/lima-vms.sh stop       # Stop all VMs
./scripts/lima-vms.sh destroy    # Destroy all VMs (with confirmation)

# Access VMs
./scripts/lima-vms.sh shell sip-1     # Shell into sip-1
./scripts/lima-vms.sh shell media-1   # Shell into media-1
./scripts/lima-vms.sh shell pbx-1     # Shell into pbx-1

# Generate Ansible inventory from running VMs
./scripts/lima-vms.sh inventory
```

### Ansible Provisioning

```bash
# Run full provisioning
./scripts/ansible-run.sh provision-vms

# Target specific groups
./scripts/ansible-run.sh provision-vms --limit sip_proxies
./scripts/ansible-run.sh provision-vms --limit media_servers

# Target specific roles
./scripts/ansible-run.sh provision-vms --tags opensips
./scripts/ansible-run.sh provision-vms --tags asterisk
```

### Running Tests

```bash
# Run all Phase 1 tests
./tests/run-phase1-tests.sh
./tests/run-phase1-tests.sh --verbose
```

### Testing

```bash
# Run all Phase 1 tests
./tests/run-phase1-tests.sh

# Individual test categories
./tests/integration/test-vault-integration.sh
./tests/functional/test-basic-call.sh
```

### SIP Debugging

```bash
# Monitor SIP traffic inside VM
./scripts/lima-vms.sh shell sip-1
sngrep -d eth0 port 5060

# Check service status
limactl shell sip-1 -- systemctl status opensips
limactl shell pbx-1 -- systemctl status asterisk
limactl shell media-1 -- systemctl status rtpengine
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
│   └── inventory/       # VM inventory (generated by lima-vms.sh)
├── configs/             # Configuration templates
│   └── templates/       # Jinja2 templates
├── docs/                # Documentation
│   ├── guides/          # How-to guides
│   └── reference/       # Technical reference
├── lima/                # Lima VM configurations (YAML)
│   ├── sip-1.yaml       # SIP proxy VM config
│   ├── media-1.yaml     # Media server VM config
│   └── pbx-1.yaml       # PBX VM config
├── scripts/             # Helper scripts
│   └── lima-vms.sh      # VM lifecycle management
├── tests/               # Test framework
│   ├── integration/     # Connectivity tests
│   ├── functional/      # SIP flow tests
│   ├── security/        # TLS/auth tests
│   └── sipp/            # Load test scenarios
└── archive/             # Archived implementations
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
- [Lima](https://lima-vm.io/) - Linux virtual machines on macOS
- [QEMU](https://www.qemu.org/) - Machine emulator with Apple HVF

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

**Development Platform:** macOS (Apple Silicon) with Lima/QEMU (Debian 12 ARM64 VMs)
