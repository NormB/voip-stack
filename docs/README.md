# voip-stack Documentation

Welcome to the voip-stack documentation! This directory contains comprehensive guides, architecture documentation, and reference materials.

## Documentation Structure

```
docs/
├── README.md                           # This file (documentation index)
├── ARCHITECTURE.md                     # High-level architecture overview
├── ARCHITECTURE_DECISIONS.md           # 17 Architecture Decision Records
├── VM-CREDENTIALS.md                   # VM authentication and Vault integration
├── guides/                             # Step-by-step guides
│   ├── INSTALLATION.md                 # Complete installation guide
│   ├── ANSIBLE-PROVISIONING.md         # Ansible provisioning workflow
│   ├── TROUBLESHOOTING.md              # Common issues and solutions
│   ├── GIT_WORKFLOW.md                 # Git workflow strategy
│   └── FORGEJO-MIRRORS.md              # Forgejo mirror management
├── reference/                          # Technical reference materials
│   ├── DEVSTACK_PATTERNS.md            # DevStack Core integration patterns
│   ├── DEVSTACK_ENHANCEMENTS.md        # Required enhancements for voip-stack
│   ├── PRE_COMMIT_CHECKLIST.md         # Security checklist
│   └── SECURITY_AUDIT.md               # Security audit report
└── archive/                            # Historical documentation

ansible/roles/                          # Role-specific documentation
├── opensips/README.md                  # OpenSIPS role (Docker, source, package)
├── asterisk/README.md                  # Asterisk role (Docker)
└── rtpengine/README.md                 # RTPEngine role (native)
```

## Quick Links

### Getting Started
- **[Installation Guide](guides/INSTALLATION.md)** - Complete setup instructions
- **[Architecture Overview](ARCHITECTURE.md)** - Understand the system design
- **[VM Credentials](VM-CREDENTIALS.md)** - Authentication and Vault integration

### Ansible Provisioning
- **[Ansible Provisioning](guides/ANSIBLE-PROVISIONING.md)** - Provisioning workflow and optimization
- **[Troubleshooting](guides/TROUBLESHOOTING.md)** - Common issues and solutions

### Component Configuration
- **[OpenSIPS Role](../ansible/roles/opensips/README.md)** - SIP proxy (Docker/source/package)
- **[Asterisk Role](../ansible/roles/asterisk/README.md)** - PBX with PJSIP (Docker)
- **[RTPEngine Role](../ansible/roles/rtpengine/README.md)** - Media proxy (native)

### Reference
- **[Architecture Decisions](ARCHITECTURE_DECISIONS.md)** - 17 ADRs with rationale
- **[DevStack Core Patterns](reference/DEVSTACK_PATTERNS.md)** - Integration patterns

## Documentation by Role

### VoIP Engineer
1. [Architecture Overview](ARCHITECTURE.md) - Understand the design
2. [Architecture Decisions](ARCHITECTURE_DECISIONS.md) - 17 ADRs explaining choices
3. [OpenSIPS Role](../ansible/roles/opensips/README.md) - SIP proxy configuration
4. [Asterisk Role](../ansible/roles/asterisk/README.md) - PBX configuration
5. [RTPEngine Role](../ansible/roles/rtpengine/README.md) - Media proxy setup

### DevOps Engineer
1. [Installation Guide](guides/INSTALLATION.md) - Deploy the stack
2. [Ansible Provisioning](guides/ANSIBLE-PROVISIONING.md) - Ansible workflow
3. [Troubleshooting](guides/TROUBLESHOOTING.md) - Common issues
4. [DevStack Core Patterns](reference/DEVSTACK_PATTERNS.md) - Infrastructure patterns

### Developer
1. [Git Workflow](guides/GIT_WORKFLOW.md) - Development workflow
2. [Architecture Decisions](ARCHITECTURE_DECISIONS.md) - Design rationale
3. [DevStack Core Patterns](reference/DEVSTACK_PATTERNS.md) - Integration patterns
4. [Security Checklist](reference/PRE_COMMIT_CHECKLIST.md) - Pre-commit checks

## Component Overview

### VoIP Components

| Component | VM | Role README | Installation |
|-----------|-----|-------------|--------------|
| OpenSIPS 3.5 | sip-1 | [README](../ansible/roles/opensips/README.md) | Docker (default), Source, Package |
| Asterisk 20 | pbx-1 | [README](../ansible/roles/asterisk/README.md) | Docker (default) |
| RTPEngine | media-1 | [README](../ansible/roles/rtpengine/README.md) | Native (kernel module required) |

### Infrastructure Services (devstack-core)

| Service | Port | Purpose |
|---------|------|---------|
| Vault | 8200 | Secrets, PKI, AppRole auth |
| PostgreSQL | 5432 | Databases (per-component) |
| Redis | 6379 | Session state, caching |
| Prometheus | 9090 | Metrics collection |
| Grafana | 3001 | Dashboards |
| Homer | 9080 | SIP capture (HEP) |

## Key Features

### Docker Deployment (Default)
- Pre-built ARM64 images for fast deployment (~30 seconds per component)
- Easy updates and rollbacks
- Consistent environments

### OpenSIPS 3.5 Support
- Updated configuration syntax (udp_workers, socket, etc.)
- Docker healthchecks using UDP
- Handler-based service management

### Asterisk PJSIP Stack
- Comprehensive pjsip.conf.j2 template
- OpenSIPS trunk integration
- Extensions dialplan with voicemail

### RTPEngine Native Installation
- Kernel module for high-performance media relay
- DTLS/SRTP encryption support
- Homer/HEP integration

## Documentation by Phase

### Phase 1: Basic Calling (Current)
- [Ansible Provisioning](guides/ANSIBLE-PROVISIONING.md) - VM setup workflow
- [OpenSIPS Role](../ansible/roles/opensips/README.md) - SIP registration, routing
- [Asterisk Role](../ansible/roles/asterisk/README.md) - Call processing
- [RTPEngine Role](../ansible/roles/rtpengine/README.md) - Media relay
- [Troubleshooting](guides/TROUBLESHOOTING.md) - Common issues and solutions

### Future Phases
- **Phase 1.5**: Kamailio coexistence (planned)
- **Phase 2**: High Availability (planned)
- **Phase 2.5**: FreeSWITCH integration (planned)
- **Phase 3**: Advanced Monitoring (planned)
- **Phase 4**: Production Hardening (planned)

## Documentation Conventions

### Code Examples

All code examples are tested and verified:

```bash
# Bash commands - create VMs and provision
cd ~/voip-stack/libvirt && ./create-vms.sh create && ./create-vms.sh start
cd ~/voip-stack && ./scripts/ansible-run.sh provision-vms
```

```yaml
# YAML (Ansible, configs)
- name: Install OpenSIPS
  ansible.builtin.apt:
    name: opensips
    state: present
```

### Placeholders

Replace these with your actual values:
- `${VARIABLE}` - Environment variable
- `<your-value>` - Replace with your value
- `192.168.64.x` - Use your actual VM IP
- `sip.local` - Use your actual domain

### Markers

- **Warning** - Important caveats or potential issues
- **Note** - Additional information or tips
- **Security** - Security-related information

## External Resources

### VoIP Components
- [OpenSIPS 3.5 Docs](https://www.opensips.org/Documentation/Tutorials-3-5) - Official documentation
- [Asterisk Docs](https://docs.asterisk.org/) - Official documentation
- [RTPEngine GitHub](https://github.com/sipwise/rtpengine) - Repository and docs

### Infrastructure
- [devstack-core](https://github.com/NormB/devstack-core) - Infrastructure services
- [HashiCorp Vault](https://www.vaultproject.io/docs) - Secrets management
- [PostgreSQL Docs](https://www.postgresql.org/docs/) - Database

### Tools
- [Ansible Docs](https://docs.ansible.com/) - Configuration management
- [libvirt Documentation](https://libvirt.org/docs.html) - Virtualization API
- [SIPp Documentation](http://sipp.sourceforge.net/doc/) - SIP testing

## Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| **Core** |
| ARCHITECTURE.md | Complete | 2024-12 |
| ARCHITECTURE_DECISIONS.md | Complete | 2024-12 |
| VM-CREDENTIALS.md | Complete | 2024-12 |
| **Guides** |
| guides/INSTALLATION.md | In Progress | 2024-12 |
| guides/ANSIBLE-PROVISIONING.md | **Complete** | 2025-12-18 |
| guides/TROUBLESHOOTING.md | **Complete** | 2025-12-18 |
| guides/GIT_WORKFLOW.md | Complete | 2024-12 |
| guides/FORGEJO-MIRRORS.md | Complete | 2024-12 |
| **Role READMEs** |
| ansible/roles/opensips/README.md | **Complete** | 2025-12-18 |
| ansible/roles/asterisk/README.md | **Complete** | 2025-12-18 |
| ansible/roles/rtpengine/README.md | **Complete** | 2025-12-18 |
| **Reference** |
| reference/DEVSTACK_PATTERNS.md | Complete | 2024-12 |
| reference/DEVSTACK_ENHANCEMENTS.md | Complete | 2024-12 |
| reference/PRE_COMMIT_CHECKLIST.md | Complete | 2024-12 |

## Contributing

See [CONTRIBUTING.md](../.github/CONTRIBUTING.md) for documentation guidelines.

**Standards:**
- Markdown format (GitHub-flavored)
- Clear heading hierarchy
- Code examples for all procedures
- Relative links between docs
- Keep docs current with code changes

## Getting Help

- **Installation issues**: [TROUBLESHOOTING.md](guides/TROUBLESHOOTING.md)
- **Bugs**: [Open an issue](https://github.com/NormB/voip-stack/issues)
- **Questions**: [GitHub Discussions](https://github.com/NormB/voip-stack/discussions)

---

**Last Updated**: 2025-12-18

**Note**: This project is in active development (Phase 1). Documentation is updated continuously as features are implemented.
