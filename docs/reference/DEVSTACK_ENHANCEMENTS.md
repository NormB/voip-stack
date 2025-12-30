# DevStack Core Enhancements for voip-stack

**Document Version**: 1.0
**Date**: October 29, 2025
**Purpose**: Document required changes to devstack-core repository to support voip-stack

---

## Overview

The `voip-stack` project depends on `devstack-core` for infrastructure services (Vault, PostgreSQL, Redis, RabbitMQ, Prometheus, Grafana, Loki). This document outlines enhancements needed in devstack-core to support VoIP workloads.

**Repository**: https://github.com/NormB/devstack-core

**Integration Model**: voip-stack VMs are **clients** of devstack-core (consumer relationship)

---

## Table of Contents

- [Required Enhancements](#required-enhancements)
- [Optional Enhancements](#optional-enhancements)
- [PostgreSQL Changes](#postgresql-changes)
- [Vault Changes](#vault-changes)
- [Prometheus Changes](#prometheus-changes)
- [New Services](#new-services)
- [Network Configuration](#network-configuration)
- [Documentation Updates](#documentation-updates)

---

## Required Enhancements

These changes are **mandatory** for voip-stack to function.

### 1. PostgreSQL: Add TimescaleDB Extension

**Current**: PostgreSQL 16 (standard)
**Required**: PostgreSQL 16 with TimescaleDB extension

**Why**: voip-stack uses TimescaleDB for CDR (Call Detail Records) storage. Time-series optimization is critical for VoIP analytics.

**Change**:
```yaml
# docker-compose.yml
services:
  postgres:
    # Change from standard postgres image
    # image: postgres:16-alpine

    # To TimescaleDB image (drop-in replacement)
    image: timescale/timescaledb:latest-pg16

    # All other configuration stays the same
    container_name: postgres
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    # ...
```

**Impact**:
- ✅ **Backward compatible** - TimescaleDB is PostgreSQL with extensions
- ✅ **Existing services unaffected** - Works with all current PostgreSQL clients
- ✅ **Zero migration** - Just change Docker image

**Testing**:
```sql
-- After change, verify TimescaleDB is available
\dx  -- List extensions
CREATE EXTENSION IF NOT EXISTS timescaledb;
\dx  -- Should show timescaledb extension
```

---

### 2. Vault: Add VoIP Secrets and Policies

**Current**: Vault configured for dev services
**Required**: Add VoIP secrets, policies, and PKI roles

**Changes Needed**:

#### A. VoIP Secrets Bootstrap

**File**: `configs/vault/scripts/vault-bootstrap.sh`

**Add** (after existing secret creation):
```bash
# ===== VoIP Secrets =====

# OpenSIPS secrets
vault kv put secret/opensips \
  db_password="$(openssl rand -base64 32)" \
  admin_password="$(openssl rand -base64 32)" \
  api_key="$(openssl rand -base64 32)"

# Kamailio secrets
vault kv put secret/kamailio \
  db_password="$(openssl rand -base64 32)" \
  admin_password="$(openssl rand -base64 32)" \
  api_key="$(openssl rand -base64 32)"

# Asterisk secrets
vault kv put secret/asterisk \
  db_password="$(openssl rand -base64 32)" \
  ami_secret="$(openssl rand -base64 32)" \
  ari_password="$(openssl rand -base64 32)" \
  manager_password="$(openssl rand -base64 32)"

# FreeSWITCH secrets
vault kv put secret/freeswitch \
  db_password="$(openssl rand -base64 32)" \
  esl_password="$(openssl rand -base64 32)" \
  api_password="$(openssl rand -base64 32)"

# RTPEngine secrets
vault kv put secret/rtpengine \
  control_secret="$(openssl rand -base64 32)" \
  redis_password="${REDIS_PASSWORD}"  # Reuse Redis cluster password

echo "VoIP secrets created successfully"
```

#### B. PKI Roles for VoIP Components

**Add** (after existing PKI setup):
```bash
# ===== VoIP PKI Roles =====

# OpenSIPS TLS role
vault write pki_int/roles/opensips-role \
  allowed_domains="opensips.local,sip.local" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_localhost=true \
  max_ttl="2160h" \
  ttl="2160h" \
  key_bits=2048

# Kamailio TLS role
vault write pki_int/roles/kamailio-role \
  allowed_domains="kamailio.local,sip.local" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_localhost=true \
  max_ttl="2160h" \
  ttl="2160h" \
  key_bits=2048

# Asterisk TLS role
vault write pki_int/roles/asterisk-role \
  allowed_domains="asterisk.local,pbx.local" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_localhost=true \
  max_ttl="2160h" \
  ttl="2160h" \
  key_bits=2048

# FreeSWITCH TLS role
vault write pki_int/roles/freeswitch-role \
  allowed_domains="freeswitch.local,pbx.local" \
  allow_subdomains=true \
  allow_bare_domains=true \
  allow_localhost=true \
  max_ttl="2160h" \
  ttl="2160h" \
  key_bits=2048

echo "VoIP PKI roles created successfully"
```

#### C. AppRole and Policies for VoIP VMs

**Add** (after existing policies):
```bash
# ===== VoIP Policies =====

# Policy for SIP VMs (sip-1, sip-2)
vault policy write sip-vm-policy - <<EOF
# Read OpenSIPS and Kamailio secrets
path "secret/data/opensips" {
  capabilities = ["read"]
}
path "secret/data/kamailio" {
  capabilities = ["read"]
}

# Read shared database credentials
path "secret/data/postgres" {
  capabilities = ["read"]
}
path "secret/data/redis-1" {
  capabilities = ["read"]
}

# Issue TLS certificates
path "pki_int/issue/opensips-role" {
  capabilities = ["create", "update"]
}
path "pki_int/issue/kamailio-role" {
  capabilities = ["create", "update"]
}

# Read CA chain
path "pki_int/ca_chain" {
  capabilities = ["read"]
}
path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF

# Policy for PBX VMs (pbx-1, pbx-2)
vault policy write pbx-vm-policy - <<EOF
# Read Asterisk and FreeSWITCH secrets
path "secret/data/asterisk" {
  capabilities = ["read"]
}
path "secret/data/freeswitch" {
  capabilities = ["read"]
}

# Read database credentials
path "secret/data/postgres" {
  capabilities = ["read"]
}
path "secret/data/rabbitmq" {
  capabilities = ["read"]
}

# Issue TLS certificates
path "pki_int/issue/asterisk-role" {
  capabilities = ["create", "update"]
}
path "pki_int/issue/freeswitch-role" {
  capabilities = ["create", "update"]
}

# Read CA chain
path "pki_int/ca_chain" {
  capabilities = ["read"]
}
path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF

# Policy for Media VMs (media-1, media-2, media-3)
vault policy write media-vm-policy - <<EOF
# Read RTPEngine secrets
path "secret/data/rtpengine" {
  capabilities = ["read"]
}

# Read Redis credentials
path "secret/data/redis-1" {
  capabilities = ["read"]
}

# Read CA chain (for monitoring)
path "pki_int/ca_chain" {
  capabilities = ["read"]
}
EOF

# ===== AppRoles for VoIP VMs =====

# SIP VM AppRole
vault write auth/approle/role/sip-vm-role \
  token_ttl=24h \
  token_max_ttl=48h \
  token_policies="sip-vm-policy"

# PBX VM AppRole
vault write auth/approle/role/pbx-vm-role \
  token_ttl=24h \
  token_max_ttl=48h \
  token_policies="pbx-vm-policy"

# Media VM AppRole
vault write auth/approle/role/media-vm-role \
  token_ttl=24h \
  token_max_ttl=48h \
  token_policies="media-vm-policy"

echo "VoIP AppRoles and policies created successfully"
```

**Impact**:
- ✅ VoIP VMs can authenticate with Vault
- ✅ Least-privilege access (each VM only gets what it needs)
- ✅ Automated certificate issuance

---

### 3. Prometheus: Add VoIP VM Scrape Targets

**Current**: Prometheus scrapes devstack-core containers only
**Required**: Add scrape configs for VoIP VMs

**File**: `configs/prometheus/prometheus.yml`

**Add** (to `scrape_configs`):
```yaml
scrape_configs:
  # ... existing configs ...

  # ===== VoIP Infrastructure =====

  # Node exporters on VoIP VMs (system metrics)
  - job_name: 'voip-vms'
    static_configs:
      - targets:
          - '192.168.64.10:9100'  # sip-1
          - '192.168.64.30:9100'  # pbx-1
          - '192.168.64.20:9100'  # media-1
        labels:
          environment: 'voip'
          tier: 'infrastructure'

  # OpenSIPS metrics (SIP proxy)
  - job_name: 'opensips'
    static_configs:
      - targets:
          - '192.168.64.10:9434'  # sip-1 opensips-exporter
        labels:
          component: 'sip-proxy'
          software: 'opensips'

  # Kamailio metrics (SIP proxy alternative)
  - job_name: 'kamailio'
    static_configs:
      - targets:
          - '192.168.64.10:9494'  # sip-1 kamailio-exporter
        labels:
          component: 'sip-proxy'
          software: 'kamailio'

  # Asterisk metrics (PBX)
  - job_name: 'asterisk'
    static_configs:
      - targets:
          - '192.168.64.30:9101'  # pbx-1 asterisk-exporter
        labels:
          component: 'pbx'
          software: 'asterisk'

  # FreeSWITCH metrics (PBX alternative)
  - job_name: 'freeswitch'
    static_configs:
      - targets:
          - '192.168.64.30:9102'  # pbx-1 freeswitch-exporter
        labels:
          component: 'pbx'
          software: 'freeswitch'

  # RTPEngine metrics (media server)
  - job_name: 'rtpengine'
    static_configs:
      - targets:
          - '192.168.64.20:9099'  # media-1 rtpengine-exporter
        labels:
          component: 'media'
          software: 'rtpengine'

  # Phase 2: HA instances
  # - job_name: 'voip-vms-ha'
  #   static_configs:
  #     - targets:
  #         - '192.168.64.11:9100'  # sip-2
  #         - '192.168.64.31:9100'  # pbx-2
  #         - '192.168.64.21:9100'  # media-2
  #         - '192.168.64.22:9100'  # media-3
```

**Impact**:
- ✅ VoIP VMs visible in Prometheus
- ✅ Metrics available in Grafana
- ✅ Can create VoIP dashboards

---

### 4. Add Homer for SIP Capture

**Current**: No SIP capture capability
**Required**: Homer (HEP server + Web UI) for SIP message debugging

**File**: `docker-compose.yml`

**Add**:
```yaml
services:
  # ... existing services ...

  # ===== Homer: SIP Capture and Analysis =====

  heplify-server:
    image: sipcapture/heplify-server:latest
    container_name: heplify-server
    ports:
      - "9060:9060/udp"  # HEP capture port (OpenSIPS/Kamailio send here)
      - "9061:9061/tcp"  # HEP over TCP
    environment:
      HEPLIFYSERVER_HEPADDR: "0.0.0.0:9060"
      HEPLIFYSERVER_HEPTCPADDR: "0.0.0.0:9061"
      HEPLIFYSERVER_DBDRIVER: postgres
      HEPLIFYSERVER_DBADDR: postgres:5432
      HEPLIFYSERVER_DBUSER: homer
      HEPLIFYSERVER_DBPASS: ${HOMER_DB_PASSWORD:-homerpass}
      HEPLIFYSERVER_DBDATABASE: homer
      HEPLIFYSERVER_DBDROPDAYS: 7  # Keep SIP messages for 7 days
    networks:
      - dev-services
    depends_on:
      - postgres
    restart: unless-stopped

  homer-app:
    image: sipcapture/webapp:latest
    container_name: homer-app
    ports:
      - "9080:80"  # Homer Web UI
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: homer
      DB_PASS: ${HOMER_DB_PASSWORD:-homerpass}
      DB_NAME: homer
    networks:
      - dev-services
    depends_on:
      - postgres
      - heplify-server
    restart: unless-stopped

volumes:
  # ... existing volumes ...

  homer-data:
    name: homer-data
```

**PostgreSQL Setup** (add to bootstrap):
```bash
# Create Homer database and user
docker exec -i postgres psql -U postgres <<EOF
CREATE DATABASE homer;
CREATE USER homer WITH ENCRYPTED PASSWORD '${HOMER_DB_PASSWORD:-homerpass}';
GRANT ALL PRIVILEGES ON DATABASE homer TO homer;
\c homer
CREATE EXTENSION IF NOT EXISTS timescaledb;
EOF
```

**Environment Variables** (add to `.env.example`):
```bash
# Homer SIP Capture
HOMER_DB_PASSWORD=your-secure-homer-password
```

**Impact**:
- ✅ SIP message capture from OpenSIPS/Kamailio
- ✅ Visual SIP ladder diagrams
- ✅ Essential for VoIP debugging

**Access**:
```
Homer Web UI: http://localhost:9080
Default credentials: admin / sipcapture (change after first login)
```

---

## Optional Enhancements

These changes are **nice-to-have** but not strictly required for Phase 1.

### 5. Add Ansible Container (Highly Recommended)

**Why**: Automate voip-stack provisioning without installing Ansible on Mac

**File**: `docker-compose.yml`

**Add**:
```yaml
services:
  # ... existing services ...

  # ===== Ansible: Automation Tool =====

  ansible:
    image: cytopia/ansible:latest-tools
    container_name: ansible
    volumes:
      - ~/voip-stack:/workspace
      - ~/.ssh:/root/.ssh:ro  # SSH keys for VM access
      - ./ansible-config:/etc/ansible:ro  # Optional: custom ansible.cfg
    working_dir: /workspace
    networks:
      - dev-services
    entrypoint: ["tail", "-f", "/dev/null"]  # Keep running
    profiles:
      - tools  # Optional profile (start with --profile tools)
    restart: "no"
```

**Usage**:
```bash
# Start Ansible container
docker-compose --profile tools up -d ansible

# Run playbook
docker exec ansible ansible-playbook \
  /workspace/ansible/playbooks/provision-vms.yml

# Or shell into container
docker exec -it ansible bash

# Stop when done
docker-compose --profile tools down
```

**Alternative**: Install Ansible locally with `brew install ansible`

---

### 6. Add MinIO (S3-Compatible Storage) - Phase 2

**Why**: Call recording storage (Phase 2)

**File**: `docker-compose.yml`

**Add** (defer to Phase 2):
```yaml
services:
  # ... existing services ...

  # ===== MinIO: S3-Compatible Object Storage =====

  minio:
    image: minio/minio:latest
    container_name: minio
    ports:
      - "9000:9000"   # S3 API
      - "9001:9001"   # Web Console
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio-data:/data
    command: server /data --console-address ":9001"
    networks:
      - dev-services
    restart: unless-stopped
    profiles:
      - voip  # Only start when VoIP features needed

volumes:
  minio-data:
    name: minio-data
```

**Access**:
```
MinIO Console: http://localhost:9001
S3 Endpoint: http://localhost:9000
```

**Status**: Deferred to Phase 2 (when call recording implemented)

---

## Network Configuration

### Current Network

**devstack-core Network**:
```yaml
networks:
  dev-services:
    name: dev-services
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**Host Access**: `192.168.64.1` (Colima VM on Mac)

### Required Changes

✅ **No changes required**

VoIP VMs will access devstack-core via `192.168.64.1` on standard ports:
- Vault: `192.168.64.1:8200`
- PostgreSQL: `192.168.64.1:5432`
- Redis: `192.168.64.1:6379-6381`
- RabbitMQ: `192.168.64.1:5672`
- Homer HEP: `192.168.64.1:9060`

### Firewall Considerations

**No changes needed** - devstack-core already listens on all interfaces

**Verify**:
```bash
# From voip-stack VM, test connectivity
nc -zv 192.168.64.1 8200  # Vault
nc -zv 192.168.64.1 5432  # PostgreSQL
nc -zv 192.168.64.1 6379  # Redis
```

---

## Documentation Updates

### README.md Changes

**Add section**:
```markdown
## Integration with voip-stack

This devstack-core infrastructure supports the `voip-stack` project, which provides a production-grade VoIP system (OpenSIPS, Asterisk, RTPEngine).

**What voip-stack uses from devstack-core:**
- **Vault**: Secrets management and PKI for TLS certificates
- **PostgreSQL**: Databases for OpenSIPS, Asterisk, CDRs, and Homer
- **Redis**: Caching and session state
- **RabbitMQ**: CDR publishing and async processing
- **Prometheus/Grafana**: VoIP metrics and dashboards
- **Loki**: Log aggregation from VoIP VMs
- **Homer**: SIP message capture and analysis

**Setup:**
1. Start devstack-core normally
2. Provision voip-stack VMs (separate repository)
3. VMs connect to devstack-core at 192.168.64.1

See: https://github.com/YourUsername/voip-stack
```

### CLAUDE.md Updates

**Update services list**:
```markdown
## What is running?

This Colima environment now includes:

**Development Infrastructure:**
- Git hosting (Forgejo) + development databases
- Vault (secrets, PKI)
- PostgreSQL with TimescaleDB (databases)
- Redis Cluster (caching)
- RabbitMQ (messaging)
- Prometheus/Grafana/Loki (observability)

**VoIP Support (for voip-stack):**
- Homer (SIP capture and analysis)
- Ansible container (automation)
- TimescaleDB extension (CDR analytics)

**Separate UTM VMs (voip-stack):**
- Production VoIP services (OpenSIPS, Asterisk, RTPEngine)
```

---

## Testing the Enhancements

### Validation Checklist

After making changes, verify:

```bash
# 1. TimescaleDB extension available
docker exec -it postgres psql -U postgres -c "\dx"
# Should show: timescaledb

# 2. VoIP secrets exist in Vault
docker exec -it vault vault kv get secret/opensips
docker exec -it vault vault kv get secret/asterisk

# 3. VoIP PKI roles exist
docker exec -it vault vault list pki_int/roles
# Should show: opensips-role, asterisk-role, etc.

# 4. Prometheus scraping (check targets)
open http://localhost:9090/targets
# Should show voip-vms job (may be down until VMs exist)

# 5. Homer accessible
open http://localhost:9080
# Should load Homer login page

# 6. Ansible container (if added)
docker-compose --profile tools up -d ansible
docker exec ansible ansible --version
```

---

## Migration Plan

### For Existing devstack-core Users

**Backward Compatibility**: ✅ All changes are backward compatible

**Steps**:
1. Pull latest devstack-core changes
2. Update `.env` with new variables (HOMER_DB_PASSWORD, etc.)
3. Run: `docker-compose pull` (get new images)
4. Run: `docker-compose up -d` (restart with new configs)
5. Run: `./scripts/vault-bootstrap.sh` (add VoIP secrets)
6. Verify with checklist above

**Downtime**: ~5 minutes (Vault and PostgreSQL restart)

---

## Summary of Changes

| Component | Change | Required | Phase |
|-----------|--------|----------|-------|
| PostgreSQL | Change to TimescaleDB image | ✅ Yes | 1 |
| Vault | Add VoIP secrets | ✅ Yes | 1 |
| Vault | Add VoIP PKI roles | ✅ Yes | 1 |
| Vault | Add VoIP policies/AppRoles | ✅ Yes | 1 |
| Prometheus | Add VoIP scrape configs | ✅ Yes | 1 |
| Homer | Add heplify-server + webapp | ✅ Yes | 1 |
| Ansible | Add Ansible container | ⚠️ Recommended | 1 |
| MinIO | Add S3-compatible storage | ⏳ Optional | 2 |
| Documentation | Update README, CLAUDE.md | ✅ Yes | 1 |

---

## Implementation Timeline

### Week 1-2 (Before voip-stack Week 1)

**Recommended**: Implement enhancements before starting voip-stack development

**Steps**:
1. Update PostgreSQL to TimescaleDB
2. Add Homer services
3. Update Vault bootstrap script
4. Update Prometheus config
5. Add Ansible container (optional)
6. Update documentation
7. Test all changes
8. Tag release: `v2.0.0-voip`

**Effort**: 2-4 hours

---

## Questions for User

Before implementing these changes:

1. **PostgreSQL Migration**: OK to change to TimescaleDB image? (Backward compatible)
2. **Homer**: Want SIP capture from day 1, or defer?
3. **Ansible Container**: Add to devstack-core, or users install locally?
4. **MinIO**: Add now (Phase 1) or later (Phase 2)?
5. **Version**: Tag as v2.0.0-voip, or different versioning?

---

## Conclusion

**Impact**: Moderate changes to devstack-core, all backward compatible

**Benefits**:
- ✅ Full VoIP infrastructure support
- ✅ No breaking changes to existing users
- ✅ Clean separation (VoIP is client, not part of devstack-core)
- ✅ Reusable infrastructure (devstack-core serves multiple projects)

**Next Steps**:
1. Review this document
2. Approve changes
3. Implement in devstack-core
4. Test thoroughly
5. Begin voip-stack development

---

**Status**: Ready for implementation

**Estimated Time**: 2-4 hours of work
