# voip-stack Architecture

**Version**: 1.0
**Date**: October 29, 2025
**Status**: Phase 1 - Alpha

---

## Table of Contents

- [Overview](#overview)
- [Design Principles](#design-principles)
- [System Architecture](#system-architecture)
- [Component Overview](#component-overview)
- [Network Architecture](#network-architecture)
- [Data Flow](#data-flow)
- [Security Architecture](#security-architecture)
- [High Availability](#high-availability)
- [Monitoring and Observability](#monitoring-and-observability)

---

## Overview

voip-stack is a production-ready VoIP infrastructure designed to run on macOS Apple Silicon using Lima/QEMU virtualization with Debian 12 ARM64 VMs, integrating with [devstack-core](https://github.com/NormB/devstack-core) for infrastructure dependencies.

### Key Characteristics

- **Production-Ready**: Designed for real-world deployments
- **Modular**: Components can be scaled independently
- **Secure**: TLS/SRTP, Vault integration, principle of least privilege
- **Observable**: Comprehensive monitoring, logging, and tracing
- **Flexible**: Support for multiple SIP proxies and PBXs

### Target Use Cases

1. **Development**: Build and test VoIP applications
2. **Testing**: Validate SIP scenarios and call flows
3. **Learning**: Understand VoIP architecture hands-on
4. **Reference**: Template for production deployments

---

## Design Principles

### 1. Security by Default

- **All secrets in Vault**: No hardcoded credentials
- **TLS/SRTP mandatory**: Encryption for all calls
- **Network isolation**: PBX has no external access
- **Least privilege**: Component-specific Vault policies

### 2. Observability First

- **Comprehensive metrics**: Prometheus scrapes all components
- **Centralized logging**: Loki aggregates all logs
- **SIP capture**: Homer records all SIP traffic
- **Distributed tracing**: (Phase 3)

### 3. Operational Excellence

- **Infrastructure as Code**: Ansible for all provisioning
- **Automated testing**: Integration, functional, security tests
- **Zero-downtime updates**: (Phase 2)
- **Disaster recovery**: Backup and restore procedures

### 4. Developer Experience

- **Mac-native**: Runs on Apple Silicon
- **Fast iteration**: Docker containers where possible
- **Clear documentation**: Comprehensive guides
- **Easy debugging**: Homer, logs, metrics

---

## System Architecture

### Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    External Network                          │
│              (Internet / Local Network)                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ eth1 (bridged)
                     │
┌────────────────────▼─────────────┐  ┌──────────────────────┐
│      SIP Proxy Tier              │  │   Media Tier         │
│  ┌──────────────────────────┐    │  │  ┌────────────────┐  │
│  │ OpenSIPS (5060/5061)     │    │  │  │ RTPEngine      │  │
│  │ - Registration           │◄───┼──┼──┤ - Media proxy  │  │
│  │ - Call routing           │    │  │  │ - NAT traversal│  │
│  │ - Load balancing         │    │  │  │ - Recording    │  │
│  └──────────────────────────┘    │  │  └────────────────┘  │
│  ┌──────────────────────────┐    │  │                      │
│  │ Kamailio (5070/5071)     │    │  │  eth0: Internal     │
│  │ - Alternative proxy      │    │  │  eth1: External     │
│  │ - Same features          │    │  └──────────────────────┘
│  └──────────────────────────┘    │           │
│                                   │           │
│  eth0: Internal                   │           │
│  eth1: External                   │           │
└───────────────┬───────────────────┘           │
                │                               │
                │      192.168.64.0/24          │
                │      (Internal Network)       │
                │                               │
┌───────────────▼───────────────────────────────▼─────────────┐
│                    PBX Tier                                  │
│  ┌────────────────────────────┐  ┌────────────────────────┐ │
│  │ Asterisk (internal only)   │  │ FreeSWITCH (Phase 2.5) │ │
│  │ - Extensions               │  │ - Extensions           │ │
│  │ - Dialplan                 │  │ - Dialplan             │ │
│  │ - Features (voicemail, etc)│  │ - Features             │ │
│  │ - AMI/ARI APIs             │  │ - ESL API              │ │
│  └────────────────────────────┘  └────────────────────────┘ │
│                                                              │
│  eth0: Internal ONLY (no eth1)                              │
└──────────────────────────────────────────────────────────────┘
```

### Infrastructure Services (devstack-core)

```
┌─────────────────────────────────────────────────────────────┐
│              devstack-core (Docker/Colima)                   │
│  Running on Mac Host (192.168.64.1)                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Vault        │  │ PostgreSQL   │  │ Redis        │      │
│  │ :8200        │  │ :5432        │  │ :6379        │      │
│  │ - Secrets    │  │ - SIP users  │  │ - Sessions   │      │
│  │ - PKI        │  │ - CDRs       │  │ - Cache      │      │
│  │ - AppRole    │  │ - Homer      │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Prometheus   │  │ Grafana      │  │ Loki         │      │
│  │ :9090        │  │ :3001        │  │ :3100        │      │
│  │ - Metrics    │  │ - Dashboards │  │ - Logs       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Homer        │  │ RabbitMQ     │  │ Forgejo      │      │
│  │ :9080        │  │ :5672        │  │ :3000        │      │
│  │ - SIP trace  │  │ - CDR queue  │  │ - Git        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### VM Specifications

VMs run Debian 12 (Bookworm) ARM64 via Lima with QEMU/HVF:

| VM Name | Role | vCPUs | RAM | Disk | OS | Access |
|---------|------|-------|-----|------|-----|--------|
| sip-1 | SIP Proxy | 2 | 2GB | 20GB | Debian 12 ARM64 | `limactl shell sip-1` |
| media-1 | Media Proxy | 4 | 4GB | 20GB | Debian 12 ARM64 | `limactl shell media-1` |
| pbx-1 | PBX | 2 | 4GB | 20GB | Debian 12 ARM64 | `limactl shell pbx-1` |

Lima provides user-mode networking (no sudo required) with VMs accessing host services via `host.lima.internal`.

---

## Component Overview

### SIP Proxy Layer

**OpenSIPS 3.4+**
- **Role**: SIP registrar, proxy, load balancer
- **Ports**: 5060 (UDP/TCP), 5061 (TLS), 8080 (WS), 8443 (WSS)
- **Features**:
  - User registration and authentication
  - Call routing and load balancing
  - RTPEngine integration
  - Homer HEP capture
  - Dispatcher module (RTPEngine failover)

**Kamailio 5.7+** (Phase 1.5)
- **Role**: Alternative SIP proxy (coexists with OpenSIPS)
- **Ports**: 5070 (UDP/TCP), 5071 (TLS), 8090 (WS), 8444 (WSS)
- **Features**: Same as OpenSIPS, different implementation

### PBX Layer

**Asterisk 20+**
- **Role**: PBX features, extensions, dialplan
- **APIs**: AMI (5038), ARI (8088)
- **Features**:
  - Extension management
  - Dialplan execution
  - Voicemail (Phase 2)
  - Call recording
  - Conference bridges (Phase 2)
  - Music on hold

**FreeSWITCH** (Phase 2.5)
- **Role**: Alternative PBX (coexists with Asterisk)
- **API**: ESL (8021)
- **Features**: Similar to Asterisk, different architecture

### Media Layer

**RTPEngine**
- **Role**: Media proxy and relay
- **Features**:
  - RTP/SRTP bridging
  - NAT traversal
  - Recording to disk
  - ICE support (Phase 2)
  - Load balancing (multiple instances, Phase 2)
- **Why Native**: Requires kernel module (xt_RTPENGINE) for performance

### Infrastructure Services

**HashiCorp Vault**
- Secrets management (database passwords, API keys)
- PKI for TLS certificates
- AppRole authentication for VMs

**PostgreSQL 16 with TimescaleDB**
- Separate databases per component
- TimescaleDB for CDR time-series data
- Connection pooling

**Redis Cluster**
- Session state (registration data)
- Caching (dialplan, routing)

**RabbitMQ**
- CDR publishing from Asterisk/FreeSWITCH
- Event bus (Phase 3)

**Homer**
- SIP capture via HEP protocol
- Web UI for troubleshooting
- Call trace analysis

**Prometheus + Grafana**
- Metrics collection (OpenSIPS, Asterisk, node exporter)
- Pre-built dashboards
- Alerting (Phase 3)

**Loki**
- Log aggregation
- Correlation with metrics

---

## Network Architecture

### Network Topology

```
                    Internet / External Network
                              │
                    ┌─────────┴──────────┐
                    │  Bridged Adapter   │
                    │  (eth1 on VMs)     │
                    └─────────┬──────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼─────┐         ┌────▼─────┐              │
   │  sip-1   │         │ media-1  │              │
   │ .64.10   │         │ .64.20   │              │
   │ eth1     │         │ eth1     │              │
   └────┬─────┘         └────┬─────┘              │
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    ┌─────────┴──────────┐
                    │ VM Shared Network  │
                    │ 192.168.64.0/24    │
                    │ (eth0 on all VMs)  │
                    └─────────┬──────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼─────┐         ┌────▼─────┐         ┌─────▼────┐
   │  sip-1   │         │  pbx-1   │         │ media-1  │
   │ .64.10   │         │ .64.30   │         │ .64.20   │
   │ eth0     │         │ eth0     │         │ eth0     │
   └────┬─────┘         └────┬─────┘         └────┬─────┘
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Mac Host         │
                    │   192.168.64.1     │
                    │   devstack-core    │
                    └────────────────────┘
```

### Interface Assignment

**eth0 (Internal - 192.168.64.0/24)**
- All VMs have eth0
- Communication with devstack-core (Vault, PostgreSQL, etc.)
- Inter-VM communication (SIP proxy ↔ PBX ↔ Media)
- Management traffic

**eth1 (External - Bridged)**
- Only sip-1 and media-1 have eth1
- Inbound SIP traffic from external clients
- Outbound RTP media to external clients
- pbx-1 has NO eth1 (security: no direct external access)

### Port Allocation

See [NETWORK_TOPOLOGY.md](reference/NETWORK_TOPOLOGY.md) for complete port mapping.

---

## Data Flow

### Registration Flow

```
1. Client → sip-1 (eth1): REGISTER
2. sip-1 → Vault: Fetch credentials
3. sip-1 → PostgreSQL: Query subscriber
4. sip-1 → Client: 200 OK
5. sip-1 → Redis: Store location
6. sip-1 → Homer: HEP capture
```

### Call Setup Flow (Extension to Extension)

```
1. Client A → sip-1: INVITE (1001 calls 1002)
2. sip-1 → Redis: Lookup 1002 location
3. sip-1 → pbx-1: INVITE (route to Asterisk)
4. pbx-1 → media-1: Allocate RTP (via RTPEngine)
5. pbx-1 → Client B: INVITE (find 1002)
6. Client B → pbx-1: 200 OK (answers)
7. pbx-1 → sip-1: 200 OK
8. sip-1 → Client A: 200 OK
9. media-1: RTP/SRTP media flows (Client A ↔ Client B)
10. Homer: Records all SIP messages
```

### CDR Flow

```
1. pbx-1 (Asterisk): Call ends
2. pbx-1 → RabbitMQ: Publish CDR
3. RabbitMQ → PostgreSQL: CDR consumer writes to TimescaleDB
4. Grafana: Query CDRs for analytics
```

---

## Security Architecture

### Defense in Depth

**Layer 1: Network**
- Network segmentation (internal/external)
- Firewall rules per VM (Phase 2)
- No direct PBX external access

**Layer 2: Transport**
- TLS for SIP signaling (mandatory)
- SRTP for media (mandatory)
- Vault PKI for certificate management

**Layer 3: Application**
- Authentication for all registrations
- Authorization for all calls
- Input validation

**Layer 4: Data**
- All secrets in Vault
- Encrypted database connections
- No secrets in configs or code

### Vault Integration

**Authentication**
- VMs use AppRole (role_id + secret_id)
- Per-VM policies (least privilege)

**Secrets**
- Database passwords
- API credentials (AMI, ARI, ESL)
- Admin passwords

**PKI**
- Certificate authority in Vault
- Automatic cert issuance and renewal
- Per-component certificates

### Secret Rotation

- Database passwords: 90 days
- TLS certificates: 2 years (configurable)
- API credentials: 180 days
- Zero-downtime rotation (Phase 2)

---

## High Availability

### Phase 1: Single Instance
- Single VM per role
- Acceptable for development/testing
- Backup and restore procedures

### Phase 2: High Availability
- Multiple SIP proxies (active-active)
- Multiple PBXs (load balanced)
- Multiple RTPEngine instances (dispatcher failover)
- Keepalived for VIP
- No single point of failure

### Phase 3: Geographic Distribution
- Multi-site deployment (future)
- GeoDNS for global routing (future)

---

## Monitoring and Observability

### Metrics (Prometheus)

**Infrastructure**
- Node exporter on all VMs (CPU, RAM, disk, network)

**Application**
- OpenSIPS: Registrations, calls, dialogs
- Asterisk: Channels, calls, queue stats
- RTPEngine: Media sessions, packet loss, jitter

### Logs (Loki)

- Centralized log aggregation
- Component-specific log streams
- Correlation with metrics

### Tracing (Homer)

- SIP message capture (HEP protocol)
- Call flow visualization
- Troubleshooting tool

### Dashboards (Grafana)

- System overview
- Per-component dashboards
- CDR analytics (Phase 3)

### Alerting (Phase 3)

- Failed calls threshold
- High load
- Service down
- Certificate expiry

---

## Deployment Model

### Infrastructure

- **Host**: Mac with Apple Silicon
- **Virtualization**: Lima with QEMU/HVF (Hypervisor.framework)
- **Guest OS**: Debian 12 (Bookworm) ARM64
- **Containers**: Docker (via devstack-core/Colima)
- **Provisioning**: Ansible

### Automation

- **VM Creation**: Lima with cloud-init provisioning
- **Software Install**: Ansible roles
- **Configuration**: Jinja2 templates
- **Testing**: Automated test suite

### VM Management

```bash
./scripts/lima-vms.sh create     # Create VMs
./scripts/lima-vms.sh status     # Check status
./scripts/lima-vms.sh shell <vm> # Access VM
./scripts/lima-vms.sh inventory  # Generate Ansible inventory
./scripts/lima-vms.sh destroy    # Destroy VMs
```

### Phases

1. **Phase 1 (Weeks 1-6)**: Basic calling, OpenSIPS + Asterisk
2. **Phase 1.5 (Weeks 7-8)**: Add Kamailio
3. **Phase 2 (Weeks 9-16)**: HA, load balancing, production features
4. **Phase 2.5 (Weeks 17-18)**: Add FreeSWITCH
5. **Phase 3 (Weeks 19-26)**: Advanced monitoring, analytics
6. **Phase 4 (Weeks 27-32)**: Production hardening, CI/CD

---

## Design Decisions

For detailed rationale behind all architecture decisions, see:
- [ARCHITECTURE_DECISIONS.md](ARCHITECTURE_DECISIONS.md) - Complete ADRs

Key decisions include:
- Why separate repository
- Why consolidated VMs
- Why mixed Docker/native deployment
- Why dual interface design
- Why PostgreSQL over MySQL
- Why AppRole over Token auth
- And 11 more...

---

## Next Steps

1. Review [Installation Guide](guides/INSTALLATION.md)
2. Set up [devstack-core](https://github.com/NormB/devstack-core)
3. Follow [Phase 1 Implementation](guides/PHASE_1_IMPLEMENTATION.md)
4. Run [tests](guides/TESTING.md) to verify

---

**Document Status**: Complete
**Last Updated**: 2025-12-30
**Phase**: 1 (Alpha)
**Virtualization**: Lima/QEMU with Debian 12 ARM64
