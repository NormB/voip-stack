# Architecture Decision Records (ADR)

**Document Version**: 1.0
**Date**: October 29, 2025
**Status**: Finalized for Phase 1 Implementation

This document captures all architecture decisions made during the planning phase, including the reasoning behind each choice. This ensures decisions are documented, traceable, and can be revisited as the project evolves.

---

## Table of Contents

- [Decision Process](#decision-process)
- [ADR-001: Separate Repository Strategy](#adr-001-separate-repository-strategy)
- [ADR-002: VM Allocation Strategy](#adr-002-vm-allocation-strategy)
- [ADR-003: Component Selection and Phasing](#adr-003-component-selection-and-phasing)
- [ADR-004: Containerization Strategy](#adr-004-containerization-strategy)
- [ADR-005: Network Architecture](#adr-005-network-architecture)
- [ADR-006: Database Strategy](#adr-006-database-strategy)
- [ADR-007: CDR and SIP Message Storage](#adr-007-cdr-and-sip-message-storage)
- [ADR-008: Call Recording](#adr-008-call-recording)
- [ADR-009: Metrics and Monitoring](#adr-009-metrics-and-monitoring)
- [ADR-010: Security and Encryption](#adr-010-security-and-encryption)
- [ADR-011: Vault Authentication](#adr-011-vault-authentication)
- [ADR-012: Secret Rotation](#adr-012-secret-rotation)
- [ADR-013: Provisioning Automation](#adr-013-provisioning-automation)
- [ADR-014: Testing Strategy](#adr-014-testing-strategy)
- [ADR-015: Public Repository Strategy](#adr-015-public-repository-strategy)
- [ADR-016: Phased Implementation Timeline](#adr-016-phased-implementation-timeline)
- [ADR-017: RTPEngine Failover Strategy](#adr-017-rtpengine-failover-strategy)

---

## Decision Process

All architecture decisions were made through collaborative discussion, considering:
1. **Production viability**: Will this work in real production environments?
2. **Development pragmatism**: Can we build this on a Mac with UTM?
3. **Security-first**: Is this approach secure by default?
4. **Scalability**: Can this grow from dev to production?
5. **Community value**: Will this help others building VoIP systems?
6. **Technical debt**: Are we making decisions we'll regret later?

---

## ADR-001: Separate Repository Strategy

### Decision
Create a **separate repository** (`voip-stack`) instead of integrating VoIP services into the existing `devstack-core` repository.

### Context
The `devstack-core` repository provides infrastructure services (Vault, PostgreSQL, Redis, RabbitMQ, Prometheus, Grafana, Loki) primarily for development and reference applications. The question was whether to add VoIP components to that repository or create a new one.

### Reasoning

**Separate Repository Chosen Because:**

1. **Architecture Philosophy Already Established**
   - devstack-core CLAUDE.md explicitly states: "Separate UTM VM: Production VoIP services"
   - The existing architecture already anticipates separation

2. **Different Technology Domains**
   - **devstack-core**: Docker Compose, containerized services, development infrastructure
   - **voip-stack**: libvirt/QEMU VMs, Debian-based, production-grade, mixed containers + native services

3. **Different Operational Models**
   - **devstack-core**: Ephemeral dev environment, can be destroyed/rebuilt
   - **voip-stack**: Stateful production environment with call data, CDRs, persistent recordings

4. **Different Resource Requirements**
   - **devstack-core**: 8GB RAM, 4 CPUs
   - **voip-stack**: 16-32GB RAM, 8+ CPUs (real-time media processing)

5. **Different Testing Approaches**
   - **devstack-core**: Unit tests, integration tests, parity tests
   - **voip-stack**: SIPp testing, RTP validation, call quality metrics, load testing

6. **Independent Evolution**
   - Each repository can evolve without affecting the other
   - Different release cycles and versioning

7. **Reusability**
   - devstack-core can serve multiple consumers
   - voip-stack can be used independently (with any infrastructure services)

8. **Documentation Clarity**
   - Each repo has focused, relevant documentation
   - Easier for newcomers to understand scope

9. **Public Release Strategy**
   - voip-stack will be public from Week 6
   - devstack-core remains separate project
   - Clear separation of concerns for community

### Consequences

**Positive:**
- Clear separation of concerns
- Independent versioning and releases
- Focused documentation per project
- devstack-core remains clean development infrastructure
- voip-stack can reference devstack-core as a dependency

**Negative:**
- Two repositories to maintain
- Need to document integration between them
- Users must set up both (though devstack-core is prerequisite)

### Status
**Accepted** - Implemented with separate `voip-stack` repository

---

## ADR-002: VM Allocation Strategy

### Decision
Use **consolidated VMs** (Option B): 3 VMs in Phase 1, 6 VMs in Phase 2

**Phase 1 VMs:**
- `sip-1`: OpenSIPS + Kamailio (both services, different ports)
- `pbx-1`: Asterisk + FreeSWITCH (both services, different ports)
- `media-1`: RTPEngine (native) + Janus (deferred to Phase 3)

**Phase 2 adds:**
- `sip-2`, `pbx-2`, `media-2`, `media-3` for HA

### Context
Needed to decide between:
- **Option A**: One VM per component (6+ VMs, better isolation)
- **Option B**: Consolidated VMs (3 VMs, easier management)
- **Option C**: Hybrid approach

### Reasoning

**Consolidated VMs Chosen Because:**

1. **Resource Efficiency**
   - Running on Mac (M-series), need to conserve resources
   - Fewer OS instances = less memory/CPU overhead
   - 3 VMs manageable on 16GB Mac, 6+ VMs challenging

2. **Simplified Management**
   - Fewer VMs to provision, update, monitor
   - Easier network configuration
   - Less complexity for initial learning/development

3. **Service Co-location Makes Sense**
   - OpenSIPS + Kamailio: Same role (SIP proxy), can run on different ports
   - Asterisk + FreeSWITCH: Same role (PBX), can run on different ports
   - Allows easy comparison and switching between alternatives

4. **Development/Production-like Balance**
   - Not going overboard with VMs for a Mac-based dev environment
   - Still provides production patterns (multi-tier architecture)
   - Can scale to proper separation in Phase 4 (dedicated servers)

5. **Testing Flexibility**
   - Can test both OpenSIPS and Kamailio without rebuilding VMs
   - Same for Asterisk vs FreeSWITCH
   - Configuration flag determines which gets port 5060

### Naming Convention

**Important Decision**: Simplified VM names (not `debian-sip`, just `sip-1`)
- Cleaner, more professional
- Platform-agnostic (Debian is implementation detail)
- Easier to reference in docs and code

**Also**: Renamed `debian-media` → `media` and `debian-pbx` → `pbx`
- More accurate terminology (Asterisk/FreeSWITCH are PBXs, not just media servers)
- RTPEngine is the actual media server

### Consequences

**Positive:**
- Lower resource usage (critical for Mac development)
- Faster to provision and test
- Easier for newcomers to set up
- Can test multiple components without VM sprawl

**Negative:**
- Less isolation between components
- If VM crashes, multiple services down
- May need to refactor for true production (1 component per VM)

**Mitigation:**
- Docker containers provide some isolation
- Phase 2 adds redundancy (HA VMs)
- Phase 4 can split to dedicated VMs/servers if needed

### Status
**Accepted** - Implemented with 3 consolidated VMs in Phase 1

---

## ADR-003: Component Selection and Phasing

### Decision
**Phase 1**: OpenSIPS + Asterisk ONLY
**Phase 1.5**: Add Kamailio alternative
**Phase 2.5**: Add FreeSWITCH alternative

### Context
All VMs will have both alternatives installed (OpenSIPS+Kamailio, Asterisk+FreeSWITCH), but need to decide which to prioritize for initial implementation and documentation.

### Reasoning

**OpenSIPS + Asterisk First Because:**

1. **Clearer Documentation Path**
   - Don't confuse users with "choose OpenSIPS OR Kamailio"
   - Single, focused getting-started guide
   - Easier for newcomers: "Here's how to build a VoIP stack"

2. **Faster to Working System**
   - Half the components to configure initially
   - Half the testing surface area
   - Can reach "first call working" milestone faster

3. **Better Initial Testing**
   - Thoroughly validate one stack before adding alternatives
   - Prove architecture works with one path
   - Build confidence and reliability

4. **Simpler Initial Codebase**
   - Cleaner Ansible roles (no complex conditionals yet)
   - Easier for contributors to understand
   - Less branching logic in configs

5. **Natural Evolution Story**
   - Week 6: "Here's a working VoIP stack (OpenSIPS+Asterisk)"
   - Phase 1.5: "Want alternatives? We added Kamailio"
   - Phase 2.5: "We added FreeSWITCH too"
   - Shows active development and project maturity

6. **Public Repository Implications**
   - Clear, opinionated starting point
   - "Just works" experience for first-time users
   - Can add alternatives as enhancements (shows growth)

### OpenSIPS vs Kamailio Choice

**Why OpenSIPS first:**
- Slightly simpler configuration syntax for beginners
- Good module ecosystem
- Strong PostgreSQL support
- Both are excellent, but had to pick one for initial focus

### Asterisk vs FreeSWITCH Choice

**Why Asterisk first:**
- Larger community and documentation
- More familiar to most VoIP developers
- Excellent ARI (Asterisk REST Interface) for app development
- Better suited for "production template" primary use case

**Note**: FreeSWITCH is equally capable and will be added as alternative

### Component Versions

**Selected Versions:**
- OpenSIPS 3.4+ (latest stable)
- Asterisk 20+ (LTS - Long Term Support)
- RTPEngine: Latest from GitHub (actively developed)

### Consequences

**Positive:**
- Clear, focused Phase 1 implementation
- Faster path to working system
- Better documentation quality
- Less overwhelming for contributors
- Shows project evolution over time

**Negative:**
- Kamailio/FreeSWITCH users wait for their preferred stack
- Some duplication when adding alternatives later

**Mitigation:**
- Document roadmap clearly (alternatives coming in Phase 1.5/2.5)
- Both alternatives still installed, just not primary focus
- Can be used immediately by advanced users who read configs

### Status
**Accepted** - OpenSIPS + Asterisk for Phase 1, alternatives in subsequent phases

---

## ADR-004: Containerization Strategy

### Decision
**Mixed deployment model:**
- **Docker containers**: OpenSIPS, Kamailio, Asterisk, FreeSWITCH, Janus
- **Native (VM-level)**: RTPEngine only

### Context
Needed to decide between:
- All services in Docker containers (consistency)
- All services native (maximum performance)
- Mixed approach (pragmatic)

### Reasoning

**RTPEngine Native Because:**

1. **Kernel Module Requirement**
   - RTPEngine uses `xt_RTPENGINE` kernel module for high-performance packet forwarding
   - Kernel module provides 10-100x better performance than userspace
   - Critical for real-time media with low latency

2. **Performance is Critical**
   - RTP packets need microsecond-level processing
   - Kernel module: ~1-5μs latency
   - Userspace (container): ~50-500μs latency
   - Production VoIP requires kernel module performance

3. **Privileged Container Complexity**
   - Could run RTPEngine in privileged container with kernel module
   - Adds significant complexity
   - Breaks "containers for isolation" model
   - Native is simpler and more reliable

**Other Services in Docker Because:**

1. **Easier Management**
   - Consistent deployment pattern
   - Easy to update (pull new image)
   - Version control via tags
   - Rollback capability

2. **Isolation**
   - Containers provide process isolation
   - Resource limits (CPU, memory)
   - Network namespace separation

3. **Portability**
   - Same containers work in dev and production
   - Can move to Kubernetes in Phase 4
   - Docker Compose for simple orchestration

4. **Consistency with Modern Practices**
   - Industry standard for microservices
   - Good documentation and tooling
   - Community container images available

### Scaling Strategy

**RTPEngine Scaling:**
- New VM instances required for additional RTPEngine instances
- Acceptable for dev/test (2-3 instances max)
- For production scale (10+ instances), would deploy on dedicated servers

**Containerized Services:**
- Can scale horizontally by adding containers
- Load balancing handled by OpenSIPS dispatcher module

### Consequences

**Positive:**
- Best performance where it matters (RTPEngine)
- Easier management for application services
- Production-grade architecture
- Proven pattern in VoIP industry

**Negative:**
- Mixed deployment model (some container, some native)
- RTPEngine scaling requires new VMs
- Need to manage kernel modules

**Mitigation:**
- Clear documentation on why RTPEngine is native
- Ansible automates kernel module installation
- VM provisioning automated with Ansible

### Status
**Accepted** - Mixed deployment: containers for apps, native for RTPEngine

---

## ADR-005: Network Architecture

### Decision
**Dual network interface architecture** with consistent naming:
- **eth0**: Internal (always present, 192.168.64.0/24)
- **eth1**: External (optional, only on VMs needing internet/public access)

**VM Network Assignments:**
- `sip-1`: eth0 (internal) + eth1 (external)
- `pbx-1`: eth0 (internal) only
- `media-1`: eth0 (internal) + eth1 (external)

### Context
Needed to decide:
1. Number of interfaces (1, 2, or 3)
2. Which VMs get which interfaces
3. Interface naming convention

### Reasoning

**Dual Interface Architecture Chosen Because:**

1. **Security Separation**
   - Internal network (eth0) isolated from internet
   - External network (eth1) for SIP clients and trunk providers
   - devstack-core never exposed to public network
   - Follows NIST SP 800-58 VoIP security guidelines

2. **devstack-core Isolation**
   - Vault, PostgreSQL, Redis, RabbitMQ only on internal network
   - No public exposure of infrastructure services
   - Database traffic segregated from SIP traffic

3. **PBX Security**
   - pbx-1 has NO external interface
   - Can only be reached via sip-1 (SIP proxy acts as firewall)
   - Classic "defense in depth" pattern
   - Asterisk/FreeSWITCH never directly exposed

4. **RTPEngine as Media Boundary**
   - Handles NAT traversal for external clients
   - Proxies between external RTP (eth1) and internal RTP (eth0)
   - PBX can use unencrypted internal RTP (trusted network)
   - External RTP uses SRTP (encryption)

**Why NOT 3 Interfaces:**
- 3-interface (Internal, External, Management) is for large enterprise
- Management can use internal interface (already secure)
- Adds complexity without significant security benefit for dev/test
- 2 interfaces is sweet spot for production-like environment

**Interface Naming Convention:**

**Critical Decision**: eth0 = Internal, eth1 = External (not reversed)

**Reasoning:**
- Consistent across all VMs
- pbx-1 only has eth0 (no confusing gap where eth1 would be)
- Clear semantic meaning: eth0 is "primary" (internal, always present)
- eth1 is "optional" (external, only if needed)

### IP Address Allocation

| VM | eth0 (Internal) | eth1 (External) | Future Phase 2 |
|----|-----------------|-----------------|----------------|
| sip-1 | 192.168.64.10 | DHCP/Bridge | sip-2: .11 |
| pbx-1 | 192.168.64.30 | (none) | pbx-2: .31 |
| media-1 | 192.168.64.20 | DHCP/Bridge | media-2: .21, media-3: .22 |

**Internal Network**: 192.168.64.0/24 (shared with devstack-core at .1)
**External Network**: Bridged to Mac's LAN interface (DHCP or static)

### Call Flow Network Path

```
External SIP Phone
    ↓ (eth1 - external)
sip-1 (OpenSIPS)
    ↓ (eth0 - internal)
pbx-1 (Asterisk) [internal only]
    ↓ (eth0 - internal RTP)
media-1 (RTPEngine eth0)
    ↓ (transcoded to eth1)
media-1 (RTPEngine eth1 - external)
    ↓ (eth1 - external)
External SIP Phone
```

**Security Benefit**: PBX never sees external traffic directly

### Port Exposure Strategy

**Phase 1**: All clients on Mac LAN (simple)
- Softphones connect via Mac's IP
- SIPp testing from Mac
- WebRTC from Mac browser

**Phase 2+**: External clients (complex, separate project)
- Requires DNS configuration
- NAT traversal setup
- Firewall port forwarding
- STUN/TURN needed

### Consequences

**Positive:**
- Excellent security posture (PBX isolated)
- Clear separation of traffic types
- Production-grade network design
- Scalable to real deployments

**Negative:**
- More complex than single interface
- Need to configure routing between interfaces
- More firewall rules to manage

**Mitigation:**
- Ansible automates all network configuration
- Clear documentation with diagrams
- Firewall rules templated and tested

### Status
**Accepted** - Dual interface with eth0=internal, eth1=external

---

## ADR-006: Database Strategy

### Decision
**Separate PostgreSQL databases** per component, all hosted in devstack-core PostgreSQL instance:

```
Database: opensips    → User: opensips
Database: kamailio    → User: kamailio
Database: asterisk    → User: asterisk
Database: freeswitch  → User: freeswitch
Database: cdr         → User: cdr_writer (shared)
Database: homer       → User: homer
```

**Database Engine**: PostgreSQL (not MySQL)

### Context
Needed to decide:
- Single database vs separate databases
- PostgreSQL vs MySQL
- Where to host (devstack-core vs dedicated VM)

### Reasoning

**Separate Databases Chosen Because:**

1. **Isolation**
   - Each component has own schema
   - No table name collisions
   - Independent migrations
   - Can drop/recreate one database without affecting others

2. **Security (Least Privilege)**
   - Each user only has access to their database
   - opensips user can't read asterisk tables
   - Limits blast radius of SQL injection
   - Vault policies can be granular

3. **Operational Flexibility**
   - Can backup databases independently
   - Different retention policies per database
   - Easy to migrate one component to different DB later

4. **Debugging**
   - Easier to see which component is using database
   - Connection pooling per database
   - Performance monitoring per component

**PostgreSQL Over MySQL Because:**

1. **Native Support**
   - OpenSIPS: PostgreSQL module mature and well-tested
   - Kamailio: Excellent PostgreSQL support
   - Asterisk: Realtime works great with PostgreSQL
   - FreeSWITCH: ODBC works perfectly with PostgreSQL

2. **TimescaleDB Integration**
   - TimescaleDB is PostgreSQL extension (used for CDRs)
   - No need for separate time-series database
   - Same connection pooling and tools

3. **Advanced Features**
   - Better JSONB support (useful for flexible schemas)
   - Excellent performance with proper indexing
   - Row-level security if needed
   - Native UUID support

4. **devstack-core Consistency**
   - devstack-core already uses PostgreSQL
   - One database engine to manage
   - Consistent tooling and backups

**Hosted in devstack-core Because:**

1. **Simplifies Architecture**
   - No separate database VM needed
   - Fewer moving parts
   - devstack-core already provides PostgreSQL

2. **Resource Efficiency**
   - Don't need to allocate RAM/CPU for separate DB VM
   - PostgreSQL in devstack-core can handle load

3. **Integration**
   - Same Vault integration pattern
   - Same backup procedures
   - Same monitoring (Prometheus PostgreSQL exporter)

### Database Connection Pattern

**From VoIP VMs:**
```
Host: 192.168.64.1 (devstack-core)
Port: 5432
Database: <component-name>
User: <component-name>
Password: <from-vault>
SSL: Optional (internal network is trusted)
```

### Consequences

**Positive:**
- Clean separation per component
- PostgreSQL's advanced features available
- Easy to manage and backup
- Vault integration for credentials
- TimescaleDB for CDRs in same engine

**Negative:**
- More databases to manage (vs single shared DB)
- More Vault secrets (one per component)
- Need to create all databases during setup

**Mitigation:**
- Ansible playbook automates all database creation
- Vault dynamic secrets reduce manual credential management
- Clear documentation of database schema

### Status
**Accepted** - Separate PostgreSQL databases per component in devstack-core

---

## ADR-007: CDR and SIP Message Storage

### Decision
**CDR Storage**: TimescaleDB (PostgreSQL extension) in devstack-core
**SIP Message Storage**: Homer (captures to PostgreSQL)

**Two separate concerns:**
- CDRs = Business data (call metadata, billing)
- SIP messages = Debug data (protocol troubleshooting)

### Context
Needed to decide:
- Where to store CDRs (PostgreSQL, InfluxDB, flat files, etc.)
- Whether to implement Homer for SIP capture
- Retention policies for each

### Reasoning

**TimescaleDB for CDRs Because:**

1. **Production VoIP CDR Requirements**
   - Time-series data (calls are time-based events)
   - High write volume (every call generates CDR)
   - Complex queries needed (by time range, caller, callee, duration, cost)
   - Long retention (90+ days, potentially years)

2. **TimescaleDB Advantages**
   - PostgreSQL-native (same connection, drivers, tooling)
   - Full SQL support (unlike Loki which is for logs)
   - Automatic partitioning by time (daily/weekly chunks)
   - Compression (90%+ storage reduction for old data)
   - Automatic retention policies (drop old data)
   - Fast queries on time ranges

3. **Real-World Use Cases Supported**
   ```sql
   -- Call volume by hour
   SELECT time_bucket('1 hour', time) AS hour, COUNT(*)
   FROM cdr WHERE time > NOW() - INTERVAL '24 hours'
   GROUP BY hour;

   -- Top callers this month
   SELECT caller, COUNT(*) as calls, SUM(duration) as minutes
   FROM cdr WHERE time > date_trunc('month', NOW())
   GROUP BY caller ORDER BY calls DESC LIMIT 10;

   -- Average call duration trend
   SELECT date_trunc('day', time) as day, AVG(duration)
   FROM cdr WHERE time > NOW() - INTERVAL '30 days'
   GROUP BY day ORDER BY day;
   ```

4. **Production Pattern**
   - Industry standard for telecom CDRs
   - Used by major VoIP providers
   - Proven at scale

**Homer for SIP Capture Because:**

1. **Different Purpose Than CDRs**
   - CDRs: What happened (call metadata)
   - Homer: How it happened (SIP protocol messages)

2. **Essential for VoIP Debugging**
   - Visual SIP ladder diagrams
   - Search by Call-ID, From, To
   - See exact SIP messages exchanged
   - Troubleshoot call failures

3. **HEP Protocol Integration**
   - OpenSIPS and Kamailio natively support HEP (Homer Encapsulation Protocol)
   - Minimal overhead to capture SIP messages
   - Real-time capture without tcpdump

4. **Short Retention**
   - SIP messages: 7-30 days (debug data)
   - CDRs: 90+ days (business data)
   - Different retention policies = different storage

### Data Flow Architecture

```
Call Ends in Asterisk/FreeSWITCH
    ↓
┌───────────────┴──────────────┐
│                              │
↓                              ↓
RabbitMQ Queue              Homer (HEP)
(cdr.call.end)             (SIP messages)
    ↓                              ↓
CDR Writer Service         PostgreSQL
(Python/Go)                (homer DB)
    ↓                              ↓
TimescaleDB                Homer UI
(cdr table)                (SIP ladder)
    ↓
Grafana Dashboards
(Analytics)
```

### CDR Schema (TimescaleDB)

```sql
CREATE TABLE cdr (
  time          TIMESTAMPTZ NOT NULL,  -- Hypertable dimension
  call_id       VARCHAR(255) NOT NULL,
  caller        VARCHAR(50),
  callee        VARCHAR(50),
  duration      INTEGER,  -- seconds
  billsec       INTEGER,  -- billable seconds
  disposition   VARCHAR(20),  -- ANSWERED, NO ANSWER, BUSY, FAILED
  codec         VARCHAR(20),
  src_ip        INET,
  dst_ip        INET,
  cost          DECIMAL(10,4),
  PRIMARY KEY (time, call_id)
);

SELECT create_hypertable('cdr', 'time');
SELECT add_retention_policy('cdr', INTERVAL '90 days');
SELECT add_compression_policy('cdr', INTERVAL '7 days');
```

### Consequences

**Positive:**
- Production-grade CDR analytics
- SQL queryable (vs Loki logs)
- Automatic retention and compression
- Homer provides essential SIP debugging
- Clear separation: business data vs debug data

**Negative:**
- Two storage systems to manage (TimescaleDB + Homer)
- Need to implement CDR writer service

**Mitigation:**
- Both use PostgreSQL (same engine, tooling)
- Ansible automates all setup
- CDR writer can be simple Python/Go script

### Status
**Accepted** - TimescaleDB for CDRs, Homer for SIP capture

---

## ADR-008: Call Recording

### Decision
**Phase 1**: UTM Shared Folder → Mac host filesystem
**Phase 2**: MinIO (S3-compatible) in devstack-core

**Recording Features:**
- Selective recording (criteria-based or on-demand via star code *1)
- Configurable format per extension (WAV, MP3, Opus)
- Configurable retention period
- Format configuration stored in PostgreSQL (NOT AstDB)

### Context
Needed to decide:
- Where to store recordings
- Whether to use MinIO, GlusterFS, or simple file storage
- When to implement (Phase 1 or defer)
- How to configure recording preferences

### Reasoning

**Phase 1: Shared Folder Because:**

1. **Simplicity**
   - UTM can share folders with Mac host
   - No additional services needed
   - Immediate access to recordings on Mac
   - Easy to play back, archive, etc.

2. **Good Enough for 3 VMs**
   - No HA in Phase 1
   - Only pbx-1 writing recordings
   - Simple retention via cron job

3. **Phase 1 Focus**
   - Get calls working first
   - Recording is feature, not core architecture
   - Can migrate to MinIO later without disruption

**Phase 2: MinIO Because:**

1. **HA-Ready**
   - Multiple PBX instances (pbx-1, pbx-2) can write to same storage
   - No split storage problem
   - Centralized recording repository

2. **S3-Compatible**
   - Industry standard API
   - Many tools support S3 (upload, analyze, transcribe)
   - Production-grade pattern

3. **Built-in Features**
   - Retention policies (lifecycle management)
   - Access control (per-bucket permissions)
   - Web UI for browsing
   - Versioning, encryption

4. **Scalable**
   - Can add storage capacity easily
   - Works with multiple PBX instances
   - Can offload to external S3 if needed

**PostgreSQL for Config (Not AstDB) Because:**

1. **FreeSWITCH Compatibility**
   - FreeSWITCH doesn't have AstDB
   - PostgreSQL works for both Asterisk and FreeSWITCH
   - Shared configuration database

2. **Centralized Management**
   - Single source of truth
   - Can query/update via SQL
   - Web UI can modify settings easily

3. **Example Schema**
   ```sql
   CREATE TABLE recording_config (
     extension VARCHAR(50) PRIMARY KEY,
     format VARCHAR(10) DEFAULT 'wav',  -- wav, mp3, opus
     enabled BOOLEAN DEFAULT false,
     retention_days INTEGER DEFAULT 90,
     updated_at TIMESTAMP DEFAULT NOW()
   );
   ```

### Recording Triggers

**Criteria-based**: Dialplan logic
```
; Record if extension has recording enabled
exten => s,1,Set(REC_ENABLED=${ODBC_SQL(SELECT enabled FROM recording_config WHERE extension='${CALLERID(num)}')})
exten => s,n,GotoIf($["${REC_ENABLED}" = "1"]?record:norecord)
exten => s,n(record),MixMonitor(${UNIQUEID}.${REC_FORMAT})
```

**On-demand**: Star code *1
```
; Toggle recording during call
exten => *1,1,GotoIf($["${RECORDING}" = "1"]?stop:start)
exten => *1,n(start),MixMonitor(${UNIQUEID}.wav)
exten => *1,n,Set(RECORDING=1)
exten => *1,n,Playback(beep)
exten => *1,n(stop),StopMixMonitor()
exten => *1,n,Set(RECORDING=0)
```

### Storage Paths

**Phase 1**:
```
pbx-1: /var/spool/asterisk/monitor/
    └── Shared to Mac: ~/voip-recordings/asterisk/
```

**Phase 2**:
```
pbx-1/pbx-2 → Local temp → Upload to MinIO
MinIO: s3://recordings/YYYY/MM/DD/call-id.wav
```

### Consequences

**Positive:**
- Phase 1: Simple, works immediately
- Phase 2: Production-grade, HA-ready
- Clear migration path
- Flexible format configuration
- Compatible with both Asterisk and FreeSWITCH

**Negative:**
- Need to implement migration from Phase 1 to Phase 2
- Two storage methods to document

**Mitigation:**
- Clear documentation for both phases
- Migration script provided
- Both methods tested

### Status
**Accepted** - Shared folder (Phase 1), MinIO (Phase 2)

---

## ADR-009: Metrics and Monitoring

### Decision
**Metrics Storage**: Prometheus (NOT PostgreSQL)
**Log Aggregation**: Loki in devstack-core
**Dashboards**: Grafana in devstack-core

**All 9 metric types collected:**
1. Registration count
2. Active call count
3. Call setup time
4. Call success/failure rate
5. Trunk status
6. Codec distribution
7. Media quality (jitter, packet loss, MOS)
8. Queue statistics
9. System resources (CPU, memory, network)

**Alerting**: Phase 3
**Real-time Call Monitoring**: Phase 3

### Context
Needed to decide:
- Where to store metrics (Prometheus vs PostgreSQL)
- What metrics to collect
- When to implement alerting and real-time monitoring

### Reasoning

**Prometheus for Metrics Because:**

1. **Purpose-Built for Metrics**
   - Time-series database optimized for metrics
   - Efficient storage and querying
   - Industry standard for monitoring

2. **Pull Model**
   - Prometheus scrapes metrics from exporters
   - No need to push metrics
   - Service discovery built-in

3. **Integration**
   - Grafana native support
   - Excellent for dashboards
   - Alertmanager for alerting (Phase 3)

4. **Existing Infrastructure**
   - devstack-core already has Prometheus
   - Just need to add scrape targets for VoIP VMs

**PostgreSQL NOT Used for Metrics Because:**
- Metrics are ephemeral (15-30 day retention)
- CDRs are long-term business data (90+ days)
- Different query patterns (time-series vs relational)
- Prometheus more efficient for high-frequency metrics

**Loki for Logs Because:**

1. **Centralized Logging**
   - All VM logs in one place
   - Unified search across services
   - Grafana integration (logs + metrics in one UI)

2. **Already Available**
   - devstack-core has Loki
   - Just need Promtail on each VM

3. **Cost-Effective**
   - Labels-based indexing (not full-text)
   - Lower storage requirements than ElasticSearch
   - Good enough for dev/test scale

### Metrics Collection Architecture

```
┌─────────────────────────────────────────────┐
│ sip-1                                       │
│ - node_exporter:9100 (system metrics)      │
│ - opensips_exporter:9434 (SIP metrics)     │
│ - Promtail → Loki (logs)                   │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ devstack-core (Mac)                       │
│                                             │
│ Prometheus (scrapes all exporters)         │
│     ↓                                       │
│ Grafana (dashboards)                        │
│     - SIP proxy metrics                     │
│     - PBX metrics                           │
│     - Media quality                         │
│     - System resources                      │
│                                             │
│ Loki (log aggregation)                      │
│     ↓                                       │
│ Grafana (log viewer)                        │
└─────────────────────────────────────────────┘
```

### Phase 3 Additions

**Alerting**:
- Critical: Service down, all calls failing
- High: Trunk down, high failure rate
- Medium: High resource usage, poor quality
- Low: Registration failures

**Real-time Call Monitoring**:
- Asterisk ARI WebSocket events
- FreeSWITCH ESL event socket
- Live dashboard showing active calls
- Per-call quality metrics

### Consequences

**Positive:**
- Industry-standard monitoring stack
- Efficient metrics storage
- Unified observability (metrics + logs)
- Scalable to production

**Negative:**
- Multiple systems (Prometheus, Loki)
- Need to learn PromQL query language

**Mitigation:**
- devstack-core already provides both
- Example dashboards and queries provided
- Clear documentation

### Status
**Accepted** - Prometheus/Loki for observability, alerting/real-time in Phase 3

---

## ADR-010: Security and Encryption

### Decision
**TLS/SRTP**: Mandatory in Phase 1
**Certificate Source**: Vault PKI
**Encryption Scope**:
- External connections: TLS + SRTP (encrypted)
- Internal connections: TCP/UDP + RTP (unencrypted, trusted network)

**Mixed Mode Support**:
- Can handle encrypted AND unencrypted calls
- External clients should use TLS/SRTP
- Internal infrastructure can use unencrypted (192.168.64.x is trusted)

### Context
Needed to decide:
- Whether TLS/SRTP is mandatory or optional
- When to implement (Phase 1 or later)
- Encryption for all traffic or just external
- Certificate management approach

### Reasoning

**TLS/SRTP Mandatory Because:**

1. **Production-like Environment**
   - Real production systems require encryption
   - Can't test encryption if we don't implement it
   - Security should be default, not optional

2. **Regulatory Compliance**
   - Many industries require encrypted voice (HIPAA, PCI, etc.)
   - Better to build with encryption from start
   - Harder to add later

3. **Reference Architecture**
   - Teaching others to build VoIP stacks
   - Should demonstrate security best practices
   - "Secure by default" philosophy

**External vs Internal Encryption:**

**External (Required)**:
- Crosses untrusted networks (internet, LAN)
- SIP clients → sip-1 (TLS port 5061)
- RTP media → media-1 (SRTP)
- SIP trunk providers (TLS)

**Internal (Optional)**:
- Stays within 192.168.64.0/24 (VM private network)
- sip-1 ↔ pbx-1 (can use plain TCP/UDP)
- pbx-1 ↔ media-1 RTP (can use plain RTP)
- Performance benefit (no encryption overhead)

**Rationale**:
- Internal network is isolated (no external access)
- Trade-off: Performance vs security
- Can enable internal encryption if needed (configurable)

**Vault PKI Chosen Because:**

1. **Automated Certificate Management**
   - Vault generates certificates on-demand
   - Automatic renewal
   - Zero-downtime rotation

2. **Integration with Existing Infrastructure**
   - devstack-core already uses Vault for PKI
   - Same CA for all services
   - Consistent certificate management

3. **Production Pattern**
   - Industry best practice
   - Better than self-signed certificates
   - Can integrate with external CA if needed

### Certificate Issuance

```bash
# OpenSIPS requests certificate from Vault
vault write -format=json pki_int/issue/opensips-role \
  common_name=sip.local \
  ttl=2160h  # 90 days

# Returns: certificate, private_key, ca_chain
# OpenSIPS uses for TLS listeners
```

### Port Configuration

**SIP Ports:**
- 5060: UDP/TCP (unencrypted, for testing/internal)
- 5061: TLS (encrypted, for production clients)

**Clients can choose**:
- Production: Use port 5061 (TLS)
- Testing: Use port 5060 (UDP)
- Both work simultaneously

### RTPEngine Encryption Modes

**SRTP ↔ RTP Transcoding:**
```
External Client (SRTP) → media-1:eth1 (SRTP)
                              ↓
                    RTPEngine (transcodes)
                              ↓
                      media-1:eth0 (RTP)
                              ↓
                      pbx-1 (plain RTP)
```

**Benefit**: External encryption without performance hit on PBX

### Consequences

**Positive:**
- Security-first architecture
- Production-ready from day 1
- Demonstrates best practices
- Vault integration provides automation

**Negative:**
- More complex initial setup
- Need to manage certificates
- Some performance overhead (external connections)

**Mitigation:**
- Vault automates certificate management
- Internal traffic can stay unencrypted (performance)
- Clear documentation on TLS/SRTP setup

### Status
**Accepted** - TLS/SRTP mandatory, Vault PKI, external encrypted / internal optional

---

## ADR-011: Vault Authentication

### Decision
**AppRole authentication** for all VoIP VMs (not token-based)

**AppRole Structure:**
- `sip-vm-role`: For sip-1, sip-2
- `pbx-vm-role`: For pbx-1, pbx-2
- `media-vm-role`: For media-1, media-2, media-3

**Vault Policies (Per-VM, not per-component):**
- `sip-vm-policy`: OpenSIPS + Kamailio secrets, PKI roles
- `pbx-vm-policy`: Asterisk + FreeSWITCH secrets, database access
- `media-vm-policy`: RTPEngine secrets, Redis access

### Context
Needed to decide:
- AppRole vs token-based authentication
- Granularity of policies (per-VM vs per-component vs shared)
- When to implement (Phase 1 or later)

### Reasoning

**AppRole Over Tokens Because:**

1. **Production-Grade Authentication**
   - Automated authentication (no manual token distribution)
   - Role-based access control
   - Token renewal/rotation
   - Audit logging

2. **Security Benefits**
   - Tokens expire and renew automatically
   - Can revoke role without affecting other VMs
   - Each VM has unique identity
   - Least privilege principle

3. **Operational Benefits**
   - No need to manually distribute tokens
   - Ansible can bootstrap AppRole
   - Easier to automate VM provisioning

4. **Phase 1 Implementation**
   - Better to build with AppRole from start
   - Harder to migrate from tokens later
   - Production-like from day 1

**Per-VM Policies (Not Per-Component) Because:**

1. **Good Security**
   - sip-1 can access OpenSIPS and Kamailio secrets (both on that VM)
   - pbx-1 can access Asterisk and FreeSWITCH secrets (both on that VM)
   - Cross-VM access denied

2. **Manageable Complexity**
   - 3 policies instead of 5-6 (per-component) or 1 (shared)
   - Middle ground between security and complexity
   - Matches VM architecture

3. **Scalability**
   - When adding sip-2, uses same sip-vm-role
   - No need to create new policies for each VM instance

**Not Per-Component Because:**
- Would need opensips-policy, kamailio-policy, asterisk-policy, etc.
- More complex to manage (5-6 policies)
- Over-engineered for dev/test environment
- Can refine in Phase 4 if needed

**Not Shared Policy Because:**
- pbx-1 doesn't need access to OpenSIPS secrets
- media-1 doesn't need access to Asterisk secrets
- Over-permissioned (security risk)

### AppRole Bootstrap Process

```bash
# 1. Create AppRole (run from devstack-core)
vault auth enable approle

vault write auth/approle/role/sip-vm-role \
  token_ttl=24h \
  token_max_ttl=48h \
  token_policies="sip-vm-policy"

# 2. Get RoleID and SecretID
role_id=$(vault read -field=role_id auth/approle/role/sip-vm-role/role-id)
secret_id=$(vault write -field=secret_id -f auth/approle/role/sip-vm-role/secret-id)

# 3. Provision to VM (Ansible)
# - Store RoleID and SecretID on VM
# - VM authenticates to Vault
vault write auth/approle/login \
  role_id=$role_id \
  secret_id=$secret_id

# Returns VAULT_TOKEN
# Token used to access secrets
```

### Example Policy

```hcl
# sip-vm-policy
path "secret/data/opensips" {
  capabilities = ["read"]
}

path "secret/data/kamailio" {
  capabilities = ["read"]
}

path "pki_int/issue/opensips-role" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/kamailio-role" {
  capabilities = ["create", "update"]
}

path "secret/data/postgres" {
  capabilities = ["read"]
}
```

### Consequences

**Positive:**
- Production-grade authentication
- Automated, no manual token management
- Good security (per-VM policies)
- Scalable to HA (Phase 2)

**Negative:**
- More complex than simple tokens
- Need to manage AppRole bootstrap

**Mitigation:**
- Ansible automates all AppRole setup
- Clear documentation with examples
- Tested bootstrap process

### Status
**Accepted** - AppRole authentication with per-VM policies

---

## ADR-012: Secret Rotation

### Decision
**Configurable rotation with zero-downtime**:

**Default Rotation Periods:**
- Database passwords: 30 days
- TLS certificates: 90 days
- AppRole tokens: 24 hours (auto-renewed)

**Testing Mode** (fast rotation):
- Database passwords: 1 hour
- TLS certificates: 1-2 hours
- For testing rotation mechanisms

**Force Rotation**: On-demand via Ansible or Vault CLI

**Zero-Downtime**: Required (hot reload, connection draining)

### Context
Needed to decide:
- How often to rotate secrets
- Whether rotation is configurable
- Whether zero-downtime is required
- How to test rotation

### Reasoning

**Configurable Rotation Because:**

1. **Different Environments Have Different Needs**
   - Testing: Want fast rotation (hourly) to test mechanisms
   - Development: Medium rotation (weekly) for convenience
   - Production: Slower rotation (monthly) for stability

2. **Environment Variables**
   ```yaml
   # environments/production.yml
   vault_rotation:
     database_ttl: "720h"  # 30 days
     cert_ttl: "2160h"     # 90 days

   # environments/testing.yml
   vault_rotation:
     database_ttl: "1h"    # 1 hour
     cert_ttl: "2h"        # 2 hours
   ```

**30 Days for Database Passwords Because:**
- Industry best practice
- Frequent enough for security
- Not so frequent to cause operational burden
- Can force rotation anytime if needed

**90 Days for TLS Certificates Because:**
- Industry standard (Let's Encrypt uses 90 days)
- Automatic renewal at 60 days (2/3 lifetime)
- Forces regular rotation testing
- Short enough to limit exposure

**Zero-Downtime Required Because:**

1. **Production-Like Environment**
   - Can't drop calls during secret rotation
   - Must test zero-downtime in dev before prod
   - Demonstrates best practices

2. **Implementation**
   - **Database**: Connection pool draining
     ```
     1. Get new credentials from Vault
     2. Establish new connection pool
     3. Drain old connection pool (wait for queries to finish)
     4. Close old connections
     5. Revoke old credentials
     ```

   - **TLS Certificates**: Hot reload
     ```
     1. Fetch new cert from Vault (background)
     2. Write new cert to disk (different filename)
     3. Send SIGHUP to OpenSIPS/Kamailio (reload config)
     4. Service picks up new cert without dropping calls
     5. Remove old cert
     ```

**Force Rotation Because:**

1. **Security Incidents**
   - If credentials compromised, need immediate rotation
   - Can't wait for scheduled rotation

2. **Testing**
   - Need to test rotation mechanisms
   - Validate zero-downtime claims

3. **Implementation**
   ```bash
   # Force rotation via Ansible
   ansible-playbook vault-rotate.yml \
     -e "force_rotation=true" \
     -e "target_vm=sip-1"

   # Or via Vault CLI
   vault lease revoke -prefix database/creds/opensips
   # Service automatically gets new creds
   ```

### Vault Dynamic Secrets

**Used for Database Credentials:**
```bash
# Create dynamic database role
vault write database/roles/opensips \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" ..." \
  default_ttl="720h" \
  max_ttl="8760h"

# Get temporary credentials (TTL: 30 days)
vault read database/creds/opensips
# Returns: username, password, lease_id

# Credentials auto-revoked after 30 days
```

**Benefits:**
- Automatic rotation (Vault manages lifecycle)
- No need to manually rotate
- Can revoke anytime

### Monitoring Rotation

**Prometheus Metrics:**
```
vault_secret_age_seconds{secret="database/opensips"} 2592000
vault_cert_expiry_days{cert="opensips"} 45
```

**Grafana Alerts:**
- Warn if cert expires in < 7 days
- Alert if secret rotation fails

### Consequences

**Positive:**
- Configurable for different environments
- Zero-downtime rotation (production-ready)
- Can test rotation mechanisms (fast mode)
- Force rotation for security incidents

**Negative:**
- Complex rotation implementation
- Need to test thoroughly

**Mitigation:**
- Ansible automates rotation
- Testing mode validates rotation works
- Clear documentation on rotation procedures

### Status
**Accepted** - Configurable rotation with zero-downtime, testing mode supported

---

## ADR-013: Provisioning Automation

### Decision
**Ansible** for all provisioning and configuration management

**Not using:**
- Terraform (overkill for local UTM VMs)
- Shell scripts (harder to maintain)
- Manual provisioning (not repeatable)

### Context
Needed to decide:
- Automation tool (Ansible, Terraform, scripts, manual)
- Scope of automation
- Structure of Ansible code

### Reasoning

**Ansible Chosen Because:**

1. **Matches devstack-core Pattern**
   - Consistency across projects
   - Already familiar with Ansible
   - Same tooling and practices

2. **Declarative and Idempotent**
   - Can run playbook multiple times safely
   - Describes desired state, not commands
   - Easy to understand what will happen

3. **VoIP-Specific Modules**
   - PostgreSQL module (create databases, users)
   - Docker module (manage containers)
   - Template module (config files with variables)
   - File module (permissions, ownership)

4. **Community Roles Available**
   - Can use existing roles for common tasks
   - VoIP-specific roles exist (though may need customization)

5. **Production-Grade**
   - Used in enterprise for infrastructure automation
   - Well-documented, large community
   - Good for both dev and production

**Not Terraform Because:**
- Terraform is for infrastructure provisioning (cloud VMs, networks)
- UTM VMs are manually created (no Terraform provider)
- Ansible better for configuration management
- Would need Terraform + Ansible (more complexity)

**Note**: Phase 4 may use Terraform for cloud/server provisioning

**Not Shell Scripts Because:**
- Harder to maintain as project grows
- No idempotency guarantees
- More error-prone
- Less readable for contributors

### Ansible Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Ansible Galaxy dependencies
│
├── inventory/
│   ├── development.yml      # Dev inventory
│   ├── production.yml       # Prod inventory (Phase 4)
│   └── localhost.yml        # For Mac host tasks
│
├── group_vars/
│   ├── all.yml             # Global variables
│   ├── sip_proxies.yml     # SIP proxy variables
│   ├── pbx_servers.yml     # PBX variables
│   └── media_servers.yml   # Media server variables
│
├── host_vars/
│   ├── sip-1.yml           # sip-1 specific vars
│   ├── pbx-1.yml           # pbx-1 specific vars
│   └── media-1.yml         # media-1 specific vars
│
├── playbooks/
│   ├── site.yml            # Main playbook (all VMs)
│   ├── sip.yml             # SIP VMs only
│   ├── pbx.yml             # PBX VMs only
│   ├── media.yml           # Media VMs only
│   └── vault-rotate.yml    # Secret rotation
│
└── roles/
    ├── common/             # Base OS setup
    ├── vault-client/       # Vault AppRole client
    ├── opensips/           # OpenSIPS installation
    ├── kamailio/           # Kamailio installation (Phase 1.5)
    ├── asterisk/           # Asterisk installation
    ├── freeswitch/         # FreeSWITCH installation (Phase 2.5)
    ├── rtpengine/          # RTPEngine installation
    ├── monitoring/         # Prometheus exporters, Promtail
    └── docker/             # Docker installation
```

### Playbook Example

```yaml
# playbooks/site.yml
---
- name: Provision all VoIP VMs
  hosts: all
  become: yes

  roles:
    - common
    - vault-client
    - docker

- name: Provision SIP proxies
  hosts: sip_proxies
  become: yes

  roles:
    - opensips
    # - kamailio  # Phase 1.5

- name: Provision PBX servers
  hosts: pbx_servers
  become: yes

  roles:
    - asterisk
    # - freeswitch  # Phase 2.5

- name: Provision media servers
  hosts: media_servers
  become: yes

  roles:
    - rtpengine
```

### Consequences

**Positive:**
- Repeatable, automated provisioning
- Matches devstack-core pattern
- Idempotent (safe to re-run)
- Good documentation and community

**Negative:**
- Need to learn Ansible (if not familiar)
- YAML can be verbose

**Mitigation:**
- Clear examples and documentation
- Start simple, add complexity as needed
- Can test playbooks easily (check mode)

### Status
**Accepted** - Ansible for all provisioning and configuration

---

## ADR-014: Testing Strategy

### Decision
**Phased testing approach** with all test types mandatory:

**Phase 1 Priority:**
1. Integration Testing (FIRST - foundation)
2. Functional Testing (SECOND - core VoIP)
3. Security Testing (THIRD - TLS, auth)
4. Call Quality Testing (FOURTH - media validation)

**Phase 2:**
5. Failover Testing (requires HA VMs)
6. Performance Testing (better with HA)

**Test Framework**: Mix of all approaches
- SIPp (XML scenarios) - UAC + UAS
- Shell scripts (wrappers, integration tests)
- GUI tools (Zoiper for manual testing)

### Context
Needed to decide:
- Priority order of test types
- Which tests in Phase 1 vs Phase 2
- Testing tools and approach

### Reasoning

**Integration Tests First Because:**

1. **Nothing Works Without Foundation**
   - Vault connectivity must work
   - Database access must work
   - Redis connectivity must work
   - Certificate retrieval must work

2. **Blocking for Everything Else**
   - Can't test SIP registration without database
   - Can't test TLS without Vault certificates
   - Can't test calls without RTPEngine

3. **Week 1-2 Focus**
   - Get infrastructure working
   - Validate devstack-core integration
   - Prove architecture before building features

**Functional Tests Second Because:**

1. **Core VoIP Functionality**
   - Registration, calls, features
   - What users care about
   - Validates the stack actually works

2. **Week 3-6 Focus**
   - Build on working infrastructure
   - Incremental feature testing
   - Path to "first call working" milestone

**Security Tests Third Because:**

1. **Mandatory for Production-Like**
   - TLS/SRTP must work
   - Authentication must work
   - Rate limiting must work

2. **Week 4-7 Focus**
   - After basic calls work
   - Validate security hardening
   - Essential for Week 6 public release

**Call Quality Fourth Because:**

1. **Ensures Good User Experience**
   - No jitter, packet loss
   - Good MOS scores
   - One-way audio detection

2. **Week 6-8 Focus**
   - After features work
   - Fine-tuning media quality
   - Validates RTPEngine performance

**Failover Phase 2 Because:**

1. **Requires HA Infrastructure**
   - Can't test failover with only 3 VMs
   - Need sip-2, pbx-2, media-2, media-3
   - Week 9+ when HA VMs exist

**Performance Phase 2 Because:**

1. **Better with HA Setup**
   - Load balancing across instances
   - More realistic capacity testing
   - Week 15-16 focus

### SIPp Testing Approach

**Multiple SIPp Instances:**

**UAC (User Agent Client)** - Caller
```bash
# Docker container on Mac
docker run --network host \
  ctaloi/sipp \
  -sf uac-invite.xml \
  -s 1001 \
  192.168.64.10:5060
```

**UAS (User Agent Server)** - Callee
```bash
# Separate Docker container
docker run --network host \
  ctaloi/sipp \
  -sf uas-answer.xml \
  -p 5070
```

**Why Multiple Instances:**
- Need caller and callee for full call test
- UAC generates INVITE
- UAS answers call
- Tests end-to-end call flow

### Test Suite Structure

```
tests/
├── run-phase1-tests.sh      # Master test runner
│
├── integration/
│   ├── test-vault-integration.sh
│   ├── test-database-connectivity.sh
│   ├── test-redis-connectivity.sh
│   └── test-vault-pki-certs.sh
│
├── functional/
│   ├── test-registration.sh
│   ├── test-basic-call.sh
│   ├── test-call-transfer.sh
│   └── test-voicemail.sh
│
├── security/
│   ├── test-tls-encryption.sh
│   ├── test-srtp-encryption.sh
│   ├── test-auth-failures.sh
│   └── test-rate-limiting.sh
│
├── quality/
│   ├── test-rtp-flow.sh
│   ├── test-jitter-packet-loss.sh
│   └── test-codec-negotiation.sh
│
└── sipp/
    ├── scenarios/
    │   ├── uac-register.xml
    │   ├── uac-invite.xml
    │   ├── uas-answer.xml
    │   └── load-test.xml
    └── scripts/
        ├── run-register-test.sh
        ├── run-call-test.sh
        └── run-load-test.sh
```

### Test Execution Order

```bash
# Day 1: Integration tests (must pass first)
./tests/integration/test-vault-integration.sh
./tests/integration/test-database-connectivity.sh

# Day 2-3: Functional tests (core features)
./tests/functional/test-registration.sh
./tests/functional/test-basic-call.sh

# Day 4: Security tests
./tests/security/test-tls-encryption.sh
./tests/security/test-srtp-encryption.sh

# Day 5: Quality tests
./tests/quality/test-rtp-flow.sh
./tests/quality/test-jitter-packet-loss.sh

# Run all Phase 1 tests
./tests/run-phase1-tests.sh
```

### Consequences

**Positive:**
- Logical test progression (foundation → features → quality)
- Clear pass/fail criteria
- Automated test execution
- All test types covered (eventually)

**Negative:**
- Need to build comprehensive test suite
- Requires SIPp knowledge
- Time investment in test development

**Mitigation:**
- Tests developed incrementally
- SIPp scenarios provided
- Shell wrappers make tests easier to run
- Documentation for each test

### Status
**Accepted** - Phased testing, all types mandatory, mix of tools

---

## ADR-015: Public Repository Strategy

### Decision
**Repository Name**: `voip-stack` (not `utm-voip-stack`)

**Go Public**: Week 6 (first call working) with v0.1.0-alpha

**Initial Stack**: OpenSIPS + Asterisk only (add Kamailio/FreeSWITCH later)

**License**: MIT

**Develop in Public**: Yes, from first commit (Week 6)

### Context
Needed to decide:
- Repository naming
- When to go public (now, Week 6, Week 8, or later)
- What to include in first public commit
- Which components to document first

### Reasoning

**Name: `voip-stack` Because:**

1. **Platform-Agnostic**
   - Not tied to UTM (Phase 4 moves to servers/K8s)
   - Works on any platform (UTM, KVM, Proxmox, cloud)
   - Broader appeal and applicability

2. **Simple and Memorable**
   - Easy to say, easy to remember
   - Professional name
   - Good SEO/searchability

3. **Future-Proof**
   - Doesn't limit to specific tech (UTM, VMs, etc.)
   - Can evolve to Kubernetes without name change
   - Platform is implementation detail

**Week 6 Public Release Because:**

1. **Sweet Spot Timing**
   - Too early (Week 1): Nothing works, vaporware reputation
   - Too late (Week 16): Missed community feedback opportunity
   - Week 6: First calls working, real credibility

2. **Credibility**
   - "Here's a working VoIP stack" > "Coming soon"
   - Users can try it immediately
   - Demonstrates competence
   - Attracts serious contributors

3. **Feedback Opportunity**
   - Get community input early enough to course-correct
   - Still in active development (can incorporate suggestions)
   - Week 6-8 can address early feedback

**OpenSIPS + Asterisk First Because:**

1. **Clearer Documentation**
   - Single path: "Here's how to build a VoIP stack"
   - Not: "Choose OpenSIPS OR Kamailio, choose Asterisk OR FreeSWITCH"
   - Less overwhelming for newcomers

2. **Faster to Working System**
   - Half the components = faster implementation
   - Can reach Week 6 milestone with quality
   - Better to have one stack working well than two half-working

3. **Natural Evolution**
   - v0.1.0: OpenSIPS + Asterisk
   - v0.2.0: Add Kamailio alternative (Phase 1.5)
   - v0.3.0: Add FreeSWITCH alternative (Phase 2.5)
   - Shows active development

**MIT License Because:**

1. **Most Permissive**
   - Allows commercial use
   - Allows modifications
   - Minimal restrictions

2. **Community Friendly**
   - Encourages adoption
   - Businesses can use without legal concerns
   - Good for reference architecture

3. **Matches devstack-core**
   - Consistency across related projects
   - Same licensing model

**First Public Commit (Week 6) Includes:**

```
✅ Working code (not just structure)
✅ OpenSIPS + Asterisk + RTPEngine
✅ Extension-to-extension calls working
✅ TLS/SRTP encryption working
✅ Vault integration working
✅ Installation guide (tested)
✅ Basic tests passing
✅ Documentation
✅ Example configs
✅ Alpha/Early Access label
```

**README v0.1.0-alpha:**
```markdown
# voip-stack

⚠️ **Alpha Release** - Core features working, documentation in progress

## What Works (v0.1.0-alpha)
- ✅ Extension-to-extension calling
- ✅ TLS/SRTP encryption
- ✅ Vault integration

## In Progress
- ⏳ Call recording
- ⏳ Voicemail
- ⏳ Complete documentation

## Roadmap
- Phase 1: Core stack (current)
- Phase 1.5: Kamailio alternative
- Phase 2: High Availability
```

### Sanitization Strategy

**What NEVER Goes Public:**
- Real credentials (use .env.example with placeholders)
- Business logic (use generic examples)
- Company info (use example.com, 555 numbers)
- Internal IPs (use 192.168.64.x in examples)

**What Goes Public:**
- Generic architecture
- Ansible roles (parameterized)
- Configuration templates (variables, not hardcoded)
- Example configs (fictitious data)
- Documentation (vendor-neutral)

### Consequences

**Positive:**
- Professional, platform-agnostic name
- Week 6: Credibility with working system
- Clear, focused initial release
- Can evolve publicly with community input

**Negative:**
- 6 weeks of private development (no early feedback)
- Kamailio/FreeSWITCH users wait for alternatives

**Mitigation:**
- Document roadmap clearly (alternatives coming)
- Can still use Kamailio/FreeSWITCH (installed, just not documented first)
- Week 6-8 can address any major concerns before v0.1.0 stable

### Status
**Accepted** - voip-stack, Week 6 public, OpenSIPS+Asterisk first, MIT license

---

## ADR-016: Phased Implementation Timeline

### Decision
**4-phase implementation over 32 weeks**:

- **Phase 1** (Weeks 1-8): Core VoIP stack (3 VMs)
- **Phase 2** (Weeks 9-16): HA/Failover (6 VMs)
- **Phase 3** (Weeks 17-24): Monitoring, Alerting, Real-time
- **Phase 4** (Weeks 25-32): Production migration, CI/CD, Kubernetes

**Public Alpha**: Week 6
**Phase 1 Complete**: Week 8

### Context
Needed to decide:
- How long each phase should take
- What to include in each phase
- When to go public
- What order to implement features

### Reasoning

**8 Weeks Per Phase Because:**

1. **Realistic Timeline**
   - Allows for complexity and learning
   - Time for thorough testing
   - Buffer for unexpected issues
   - Part-time development pace

2. **Manageable Milestones**
   - Clear deliverables every 8 weeks
   - Can adjust based on progress
   - Keeps motivation high

3. **Production-Quality Focus**
   - Not rushing to "make it work"
   - Time for proper testing
   - Time for documentation
   - Time for refactoring

**Phase 1: Core Stack Because:**

1. **Foundation First**
   - Get basic architecture working
   - Prove integration with devstack-core
   - Establish patterns for later phases

2. **Value Early**
   - Extension-to-extension calls by Week 6
   - Can start using for development
   - Real VoIP functionality

3. **Week 6 Milestone**
   - First call working
   - Public alpha release
   - Credibility established

**Phase 2: HA/Failover Because:**

1. **Natural Next Step**
   - Build on working Phase 1 foundation
   - Add redundancy and resilience
   - Production-grade architecture

2. **Critical Learning**
   - RTPEngine failover is complex
   - OpenSIPS dispatcher module
   - Stateful failover mechanisms

3. **Add Alternatives**
   - Phase 1.5: Kamailio
   - Phase 2.5: FreeSWITCH
   - Shows project evolution

**Phase 3: Monitoring/Alerting Because:**

1. **Observability is Production-Critical**
   - Can't run production without monitoring
   - Alerting prevents outages
   - Real-time dashboards for operations

2. **Builds on Phases 1-2**
   - Have full stack to monitor
   - HA means more complex monitoring
   - Multiple instances to track

3. **Deferred from Phase 1**
   - Basic monitoring in Phase 1 (Prometheus)
   - Advanced features in Phase 3
   - Alerting, real-time, advanced dashboards

**Phase 4: Production Migration Because:**

1. **Move Off Mac**
   - Dedicated servers or cloud
   - Real production capacity
   - Mac was development platform

2. **CI/CD for Production**
   - Automated deployments
   - Testing pipelines
   - GitOps workflows

3. **Kubernetes Exploration**
   - Container orchestration
   - May develop on Mac, deploy to K8s
   - Production scalability

### Phase 1 Weekly Breakdown

**Week 1-2**: Infrastructure
- VM provisioning
- Vault integration
- Database setup
- Network configuration

**Week 3-4**: SIP Layer
- OpenSIPS installation
- SIP registration working
- TLS configuration
- Homer SIP capture

**Week 5-6**: PBX & Media
- Asterisk installation
- RTPEngine installation
- First call working ← **Week 6 Milestone**

**Week 7-8**: Features
- Call recording
- Voicemail
- Call transfer
- Testing complete

### Consequences

**Positive:**
- Realistic, achievable timeline
- Clear milestones every 8 weeks
- Production-quality at each phase
- Iterative improvement

**Negative:**
- 32 weeks total (8 months)
- Longer than "quick and dirty" approach
- Requires patience and commitment

**Mitigation:**
- Each phase delivers value
- Can use system after Phase 1
- Phasing allows for adjustments
- Quality over speed

### Status
**Accepted** - 4 phases, 8 weeks each, 32 weeks total

---

## ADR-017: RTPEngine Failover Strategy

### Decision
**OpenSIPS/Kamailio dispatcher module** handles RTPEngine failover (NOT Redis-based session recovery)

**Failover Mechanism:**
1. OpenSIPS health-checks RTPEngine instances (OPTIONS ping)
2. Detects failure (timeout, no response)
3. Marks failed RTPEngine as inactive
4. Sends re-INVITE to move active calls to healthy RTPEngine

**No Redis dependency** for RTPEngine session state

### Context
Needed to decide:
- How to handle RTPEngine failover
- Whether to use Redis for session recovery
- Whether to use OpenSIPS dispatcher or another approach

### Reasoning

**OpenSIPS Dispatcher Over Redis Because:**

1. **Simplicity**
   - No additional Redis dependency for RTPEngine
   - RTPEngine runs stateless (simpler deployment)
   - All failover logic in one place (OpenSIPS config)

2. **Active Monitoring**
   - OpenSIPS actively health-checks RTPEngine instances
   - Detects failures immediately
   - Dispatcher module built for this use case

3. **Production-Proven Pattern**
   - Many production deployments use this approach
   - Well-documented in OpenSIPS community
   - Reliable and tested

4. **Clean Failover Logic**
   ```
   # opensips.cfg
   load module "dispatcher.so"

   modparam("dispatcher", "list_file", "/etc/opensips/dispatcher.list")
   modparam("dispatcher", "ds_ping_interval", 10)  # Health check every 10s
   modparam("dispatcher", "ds_probing_mode", 1)    # Probe inactive too
   modparam("dispatcher", "ds_ping_method", "OPTIONS")

   # dispatcher.list
   # RTPEngine instances
   1 sip:192.168.64.20:22222  # media-1
   1 sip:192.168.64.21:22222  # media-2
   1 sip:192.168.64.22:22222  # media-3
   ```

5. **Re-INVITE Mechanism**
   - For new calls: Route to healthy RTPEngine
   - For active calls: Send re-INVITE to move media
   - No call drops during failover

**Why NOT Redis Session Recovery:**

1. **Additional Complexity**
   - Would need Redis integration for RTPEngine
   - RTPEngine must store session state in Redis
   - Backup RTPEngine must reconstruct sessions from Redis
   - More moving parts, more failure modes

2. **Not Needed for Dev/Test**
   - OpenSIPS dispatcher is sufficient
   - Good enough for 10-50 concurrent calls
   - Can add Redis in Phase 4 if needed for massive scale

3. **Graceful Degradation**
   - Re-INVITE failover is graceful (no dropped calls)
   - Brief audio interruption (1-2 seconds) acceptable
   - Better than adding complexity

**When Redis Makes Sense:**
- Very high call volume (1000+ concurrent calls)
- Can't tolerate any audio interruption
- Geographic distribution of RTPEngine instances
- True production at scale (Phase 4+)

### Failover Behavior

**New Calls:**
```
1. OpenSIPS receives INVITE
2. Checks dispatcher: Which RTPEngine is healthy?
3. Routes to media-1 (healthy)
4. If media-1 fails, next call goes to media-2
```

**Active Calls:**
```
1. media-1 fails (no OPTIONS response)
2. OpenSIPS marks media-1 as inactive
3. For active calls on media-1:
   - Send re-INVITE to caller
   - Re-INVITE includes media-2 RTPEngine
   - Caller sends RTP to media-2
   - Brief audio interruption (~1-2 seconds)
   - Call continues without dropping
```

### Testing Failover

```bash
# Test script: Kill media-1, verify calls continue
1. Start call between ext 1001 and 1002
2. Verify RTP flowing through media-1
3. Kill RTPEngine on media-1
4. Wait 10 seconds (health check interval)
5. Verify OpenSIPS sends re-INVITE
6. Verify RTP now flowing through media-2
7. Verify call still active (no drop)
```

### Consequences

**Positive:**
- Simple, proven approach
- No Redis dependency for RTPEngine
- Clean failover logic
- Works for dev/test scale
- Can add Redis later if needed

**Negative:**
- Brief audio interruption during failover (1-2 seconds)
- Re-INVITE mechanism adds complexity to dialplan

**Mitigation:**
- Audio interruption acceptable for dev/test
- Can add Redis in Phase 4 if needed
- Clear documentation on failover behavior

### Status
**Accepted** - OpenSIPS dispatcher for failover, no Redis dependency

---

## Summary of All Decisions

| ADR | Decision | Status | Phase |
|-----|----------|--------|-------|
| 001 | Separate repository | Accepted | Foundation |
| 002 | Consolidated VMs (3 → 6) | Accepted | Foundation |
| 003 | OpenSIPS+Asterisk first | Accepted | Phase 1 |
| 004 | Mixed: Containers + Native RTPEngine | Accepted | Phase 1 |
| 005 | Dual interface (eth0=int, eth1=ext) | Accepted | Phase 1 |
| 006 | Separate PostgreSQL databases | Accepted | Phase 1 |
| 007 | TimescaleDB + Homer | Accepted | Phase 1 |
| 008 | Shared folder → MinIO | Accepted | Phase 1-2 |
| 009 | Prometheus + Loki | Accepted | Phase 1 |
| 010 | TLS/SRTP mandatory | Accepted | Phase 1 |
| 011 | AppRole authentication | Accepted | Phase 1 |
| 012 | Configurable rotation | Accepted | Phase 1 |
| 013 | Ansible automation | Accepted | Phase 1 |
| 014 | Phased testing | Accepted | Phase 1-2 |
| 015 | voip-stack, Week 6 public | Accepted | Foundation |
| 016 | 4 phases, 32 weeks | Accepted | All phases |
| 017 | OpenSIPS dispatcher failover | Accepted | Phase 2 |

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-29 | Initial architecture decisions documented |

---

## Future Decisions

Decisions still to be made in future phases:

- **Phase 2**: Exact Kamailio configuration patterns
- **Phase 2**: FreeSWITCH vs Asterisk for specific use cases
- **Phase 3**: Alerting thresholds and escalation policies
- **Phase 3**: Real-time dashboard design
- **Phase 4**: Kubernetes vs bare metal for production
- **Phase 4**: CI/CD tool selection (GitHub Actions, GitLab CI, etc.)

These will be added as ADRs when decisions are made.

---

**End of Architecture Decision Records**
