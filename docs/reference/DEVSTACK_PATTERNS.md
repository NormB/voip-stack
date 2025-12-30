# DevStack Core Project Structure & Patterns Analysis

## 1. OVERALL STRUCTURE AND ORGANIZATION

### Directory Layout
```
devstack-core/
├── configs/              # Service configuration files
│   ├── exporters/       # Prometheus exporters
│   ├── forgejo/         # Git server
│   ├── grafana/         # Visualization (dashboards, provisioning)
│   ├── loki/            # Log aggregation
│   ├── mongodb/         # MongoDB
│   ├── mysql/           # MySQL with Vault wrapper scripts
│   ├── pgbouncer/       # PostgreSQL connection pooling
│   ├── postgres/        # PostgreSQL with Vault wrapper scripts
│   ├── prometheus/      # Prometheus configuration
│   ├── promtail/        # Log shipper to Loki
│   ├── rabbitmq/        # RabbitMQ message broker
│   ├── redis/           # Redis cluster
│   ├── vault/           # Vault server and bootstrap scripts
│   └── vector/          # Unified observability (logs + metrics)
├── docker-compose.yml   # Complete service definitions (41KB, highly detailed)
├── .env.example         # Environment template with inline documentation
├── devstack             # Primary management script (51KB, 600+ lines)
├── Makefile             # API synchronization validation targets
├── VERSION              # Version file (1.2.0)
├── scripts/             # Helper scripts for operations and validation
│   ├── generate-certificates.sh      # Vault PKI cert generation
│   ├── extract-openapi.sh            # OpenAPI extraction from code
│   ├── generate-api-first.sh         # API-first code generation
│   ├── load-vault-env.sh             # Vault credential loading
│   ├── regenerate-api-first.sh       # Regenerate API-first impl
│   ├── validate-sync.sh              # Validate API sync
│   ├── sync-report.sh                # Generate sync report
│   ├── sync-wiki.sh                  # Sync docs to wiki
│   ├── install-hooks.sh              # Install git pre-commit hooks
│   ├── validate-cicd.sh              # CI/CD validation
│   └── docker-compose-vault.sh       # Vault-only docker compose
├── tests/               # Comprehensive test infrastructure
│   ├── lib/common.sh    # Shared test library with helper functions
│   ├── run-all-tests.sh # Master test orchestrator (370+ tests)
│   ├── test-*.sh        # Service-specific test suites
│   ├── requirements.txt  # Python test dependencies
│   ├── pyproject.toml   # Python project config
│   └── TEST_COVERAGE.md # Coverage details
├── reference-apps/      # Language-specific implementations
│   ├── fastapi/         # Python code-first implementation
│   ├── fastapi-api-first/ # Python API-first (OpenAPI-driven)
│   ├── golang/          # Go/Gin implementation
│   ├── nodejs/          # Node.js/Express implementation
│   ├── rust/            # Rust/Actix-web implementation
│   ├── typescript-api-first/ # TypeScript API-first
│   ├── shared/          # Shared OpenAPI spec and test suite
│   └── README.md        # Architecture and patterns overview
├── docs/                # Comprehensive documentation (62,000+ lines)
│   ├── README.md        # Getting started guide
│   ├── INSTALLATION.md  # Step-by-step installation
│   ├── SERVICES.md      # Service configuration reference
│   ├── VAULT.md         # Vault PKI and secrets management
│   ├── MANAGEMENT.md    # Management script reference
│   ├── OBSERVABILITY.md # Prometheus, Grafana, Loki setup
│   ├── VAULT_SECURITY.md # Security best practices
│   ├── TROUBLESHOOTING.md # Issue diagnosis and resolution
│   ├── ARCHITECTURE.md  # System design with Mermaid diagrams
│   ├── PERFORMANCE_TUNING.md # Optimization strategies
│   ├── BEST_PRACTICES.md # Development guidelines
│   ├── FAQ.md           # Common questions and answers
│   └── [14 more docs]   # Complete reference library
├── wiki/                # Synchronized wiki documentation (50+ files)
├── assets/              # Social preview images
├── LICENSE              # MIT License
├── README.md            # Project overview
└── CLAUDE.md            # AI assistant guidance (NOT user-facing)

### Key Statistics
- Docker Compose: 41KB, defines 20+ services with detailed configuration
- devstack: 51KB, implements 20+ commands
- Scripts: 12 helper scripts averaging 5-20KB each
- Documentation: 62,000+ lines across 27 files + 50+ wiki pages
- Reference Apps: 5 language implementations with shared test suite
- Tests: 370+ automated tests across bash and Python
- Pre-commit Hooks: 10+ quality checks
```

## 2. CONFIGURATION APPROACH

### Docker Compose Pattern
- **Single File Approach**: All services defined in `docker-compose.yml` with x-templates
- **Extensibility**: Uses YAML anchors (&default-logging) for DRY principle
- **Environment Variables**: Extensive use of ${VAR:-default} pattern
- **Health Checks**: Every service has dedicated health check configuration
- **Resource Limits**: CPU and memory reservations/limits defined per service
- **Service Dependencies**: Uses depends_on with service_healthy conditions
- **Network Isolation**: Custom network (dev-services, 172.20.0.0/16) with static IPs

### .env.example Pattern
```
# Structure: Comprehensive, 360+ lines of documentation
# 1. Vault configuration (top-level, critical)
# 2. IP addresses for all services (section with inline comments)
# 3. TLS configuration (boolean flags for each service)
# 4. Database-specific config (PostgreSQL, MySQL, etc.)
# 5. Reference app configuration
# 6. Observability stack config
# 7. Service-specific credentials
# 8. Large NOTES section (100+ lines) explaining:
#    - How to get Colima IP
#    - Access instructions for each service
#    - Vault credential retrieval patterns
#    - TLS certificate management
#    - Security best practices

# Design Principles:
- Placeholder values with clear variable naming
- Sections use "===== SERVICE_NAME =====" headers
- Each section includes inline documentation
- Detailed comments explain functionality and defaults
- No actual secrets (empty strings for passwords)
- Password fields explicitly documented as "loaded from Vault"
- Health check parameters grouped with service config
- TLS configuration documented with usage examples
```

### Configuration File Locations
```
configs/<service>/
├── Dockerfile (if custom build needed)
├── <service>.conf or <service>.yml (main config)
├── scripts/ (initialization/wrapper scripts)
│   └── init.sh (Vault integration, health checks)
└── (optional Jinja2 templates, SQL scripts, etc.)
```

## 3. SERVICE DEFINITIONS

### Vault Integration Pattern
Every database service follows this pattern:

```yaml
service_name:
  image: official-image:version
  container_name: dev-service-name
  restart: unless-stopped
  
  # Vault integration
  entrypoint: ["/init/init.sh"]
  environment:
    VAULT_ADDR: ${VAULT_ADDR:-http://vault:8200}
    VAULT_TOKEN: ${VAULT_TOKEN}
    SERVICE_ENABLE_TLS: ${SERVICE_ENABLE_TLS:-false}
    SERVICE_IP: ${SERVICE_IP:-172.20.0.X}
  
  # Volumes
  volumes:
    - service_data:/data
    - ./configs/service:/docker-entrypoint-initdb.d:ro
    - ./configs/service/scripts/init.sh:/init/init.sh:ro
    - ${HOME}/.config/vault/certs/service:/service-certs:ro
  
  # Network
  networks:
    dev-services:
      ipv4_address: ${SERVICE_IP}
  
  # Dependencies
  depends_on:
    vault:
      condition: service_healthy
  
  # Health checks
  healthcheck:
    test: ["CMD-SHELL", "health_check_command"]
    interval: ${SERVICE_HEALTH_INTERVAL:-60s}
    timeout: ${SERVICE_HEALTH_TIMEOUT:-5s}
    retries: ${SERVICE_HEALTH_RETRIES:-5}
    start_period: ${SERVICE_HEALTH_START_PERIOD:-30s}
  
  # Resource allocation
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
  
  # Labels for identification
  labels:
    - "com.voip.service=service-name"
    - "com.voip.platform=colima"
```

### Logging Configuration
```yaml
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### Network Configuration
```yaml
networks:
  dev-services:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Services Overview

**Core Database Services:**
1. **PostgreSQL (16-alpine)**
   - Container IP: 172.20.0.10
   - Port: 5432
   - Wrapper script: configs/postgres/scripts/init.sh
   - Vault integration: Auto-fetches credentials
   - Health check: pg_isready

2. **MySQL (8.0.40)**
   - Container IP: 172.20.0.12
   - Port: 3306
   - Wrapper script: configs/mysql/scripts/init.sh
   - TLS support via Vault PKI

3. **MongoDB (7)**
   - Container IP: 172.20.0.15
   - Port: 27017
   - Vault-managed credentials

4. **PgBouncer (latest)**
   - Container IP: 172.20.0.11
   - Port: 6432
   - Connection pooling for PostgreSQL
   - Custom Dockerfile build

**Cache & Messaging:**
5. **Redis Cluster (3-node, 7-alpine)**
   - IPs: 172.20.0.13, 172.20.0.16, 172.20.0.17
   - Ports: 6379, 6380, 6381
   - Cluster mode enabled
   - Shared password across all nodes

6. **RabbitMQ (3-management-alpine)**
   - Container IP: 172.20.0.14
   - Ports: 5672 (AMQP), 15672 (Management)
   - Management UI enabled

**Git & Secrets:**
7. **Forgejo (1.21)**
   - Container IP: 172.20.0.20
   - Ports: 3000 (HTTP), 2222 (SSH)
   - PostgreSQL backend
   - Custom Dockerfile for configuration

8. **Vault (hashicorp/vault:latest)**
   - Container IP: 172.20.0.21
   - Port: 8200
   - File storage backend (/vault/data)
   - Auto-unseal via entrypoint script
   - UIenabled

**Observability:**
9. **Prometheus (2.48.0)**
   - Port: 9090
   - Metrics scraping config
   - Scrapes: Vault, Forgejo, Vector, cAdvisor

10. **Grafana (10.2.2)**
    - Port: 3001
    - Default credentials: admin/admin (must change)
    - Provisioned with dashboards
    - Loki data source configured

11. **Loki (2.9.3)**
    - Port: 3100
    - Log aggregation
    - 31-day retention
    - boltdb-shipper storage

12. **Vector**
    - Unified observability pipeline
    - Scrapes: Redis exporters, RabbitMQ, cAdvisor
    - Custom vector.yaml configuration

**Reference Applications:**
13-17. **FastAPI, Go, Node.js, Rust, TypeScript APIs**
    - Ports: 8000-8004 (HTTP), 8443-8447 (HTTPS)
    - All demonstrate Vault integration
    - Shared test suite in reference-apps/shared/

## 4. NETWORKING PATTERNS

### Static IP Assignment
```
172.20.0.10   → PostgreSQL
172.20.0.11   → PgBouncer
172.20.0.12   → MySQL
172.20.0.13   → Redis-1
172.20.0.14   → RabbitMQ
172.20.0.15   → MongoDB
172.20.0.16   → Redis-2
172.20.0.17   → Redis-3
172.20.0.20   → Forgejo
172.20.0.21   → Vault
172.20.0.100  → Reference API
172.20.0.101  → Prometheus
172.20.0.102  → Grafana
172.20.0.103  → Loki
```

### DNS Resolution
- Services communicate via hostname within container network
- Examples: postgres:5432, vault:8200, redis-1:6379
- Mac host accesses via localhost with port forwarding
- UTM VMs access via Colima IP (retrieved with `colima list`)

### Port Mapping Strategy
```
Host Port ← docker-compose Port Mapping ← Container Port
5432      ← POSTGRES_HOST_PORT            ← 5432
6432      ← PGBOUNCER_HOST_PORT           ← 5432
3306      ← MYSQL_HOST_PORT               ← 3306
27017     ← MONGODB_HOST_PORT             ← 27017
6379-6381 ← REDIS_1/2/3_HOST_PORT         ← 6379
5672      ← RABBITMQ_AMQP_PORT            ← 5672
15672     ← RABBITMQ_MGMT_PORT            ← 15672
3000      ← Forgejo HTTP                  ← 3000
2222      ← Forgejo SSH                   ← 2222
8200      ← Vault                         ← 8200
9090      ← Prometheus                    ← 9090
3001      ← Grafana                       ← 3001
3100      ← Loki                          ← 3100
8000-8004 ← Reference APIs                ← 8000-8004
8443-8447 ← Reference APIs (TLS)          ← 8443-8447
```

## 5. SECRET MANAGEMENT STRATEGY

### Vault Architecture
```
Vault PKI Hierarchy:
├── Root CA (10-year validity)
│   └── Intermediate CA (5-year validity)
│       └── Service Certificates (1-year validity)
│           ├── PostgreSQL (server.crt, server.key, ca.crt)
│           ├── MySQL (server-cert.pem, server-key.pem, ca.pem)
│           ├── Redis (redis.crt, redis.key)
│           ├── MongoDB (mongodb.pem combined, ca.pem)
│           ├── RabbitMQ (server.pem, key.pem, ca.pem)
│           └── Other services

Vault KV v2 Secrets:
├── secret/postgres (user, password, database, tls_enabled)
├── secret/mysql (root_password, user, password, database)
├── secret/redis-1 (password - shared across all nodes)
├── secret/rabbitmq (user, password, vhost)
├── secret/mongodb (user, password, database)
└── [Additional service secrets]
```

### Credential Loading Pattern
All services follow this initialization flow:

```bash
1. Container starts
2. Wrapper script (init.sh) executes
   ├── Wait for Vault to be ready
   │   └── Poll /v1/sys/health?standbyok=true
   ├── Fetch credentials from Vault
   │   └── GET /v1/secret/data/$SERVICE_NAME
   │   └── Extract user, password, database, tls_enabled
   ├── Validate pre-generated certificates (if TLS enabled)
   ├── Configure TLS environment variables
   └── Exec original entrypoint with credentials
3. Service starts with injected credentials
```

### Vault Initialization & Auto-Unseal
- **vault-init.sh**: Initializes Vault, saves keys/token to ~/.config/vault/
- **vault-auto-unseal.sh**: Entrypoint script, auto-unseals on startup
- **vault-bootstrap.sh**: Sets up PKI, creates certificate roles, stores credentials
- **Key Files**:
  - ~/.config/vault/keys.json (5 unseal keys)
  - ~/.config/vault/root-token (root authentication token)
  - ~/.config/vault/ca/ (exported CA certificates)
  - ~/.config/vault/certs/ (service-specific certificates)

### Credential Retrieval Patterns

**Via Vault CLI:**
```bash
vault kv get secret/postgres        # All fields
vault kv get -field=password secret/postgres  # Specific field
vault read -field=certificate pki_int/issue/postgres-role
```

**Via Vault API (curl):**
```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://vault:8200/v1/secret/data/postgres
```

**Via load-vault-env.sh (sourced):**
```bash
source scripts/load-vault-env.sh
# Exports POSTGRES_PASSWORD, VAULT_TOKEN to environment
docker compose up -d
```

## 6. SCRIPT PATTERNS

### Master Management Script (devstack)
**Purpose**: Single interface for all operations
**Size**: 51KB, 600+ lines
**Pattern**:
- Heavy use of helper functions for logging (info, success, warn, error)
- Global color codes (RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, NC)
- Comprehensive documentation header (100+ lines)
- DOCKER_HOST configuration for Colima socket
- Commands implemented as functions with case statement router

**Key Commands**:
```bash
./devstack start                  # Start Colima VM + services
./devstack stop                   # Stop everything
./devstack restart                # Restart services only
./devstack status                 # Show VM + service status
./devstack logs [service]         # Stream logs
./devstack shell [service]        # Interactive shell
./devstack health                 # Health checks
./devstack vault-init             # Initialize Vault
./devstack vault-bootstrap        # Bootstrap PKI + credentials
./devstack vault-status           # Vault seal status
./devstack vault-token            # Display root token
./devstack vault-show-password [svc] # Retrieve password
./devstack ip                     # Colima VM IP
./devstack backup                 # Backup databases
./devstack reset                  # Destroy + reset
./devstack help                   # Detailed help
```

### Service Initialization Scripts (init.sh pattern)

**Location**: configs/<service>/scripts/init.sh
**Size**: 300-500 lines with extensive documentation
**Pattern**:

```bash
#!/bin/bash
#######################################
# <Service> Initialization with Vault Integration
#
# Comprehensive header (50-80 lines):
# - DESCRIPTION: What the script does
# - GLOBALS: All environment variables used
# - USAGE: Examples with different configurations
# - DEPENDENCIES: Required tools
# - EXIT CODES: 0 success, 1 errors
# - NOTES: Important behaviors
#######################################

set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN="${VAULT_TOKEN}"
SERVICE_NAME="service-name"
SERVICE_IP="${SERVICE_IP:-172.20.0.X}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions with consistent pattern
info() { echo -e "${BLUE}[Service Init]${NC} $1"; }
success() { echo -e "${GREEN}[Service Init]${NC} $1"; }
warn() { echo -e "${YELLOW}[Service Init]${NC} $1"; }
error() { echo -e "${RED}[Service Init]${NC} $1"; exit 1; }

# Step functions (each 20-40 lines with detailed comments)
wait_for_vault()    # Poll Vault health, 120s timeout, 60 attempts
fetch_credentials() # GET /v1/secret/data/$SERVICE, parse with jq
validate_certificates() # Check pre-generated certs exist, readable
configure_tls()     # Set TLS environment variables
main()              # Orchestrate all steps, exec entrypoint

main "$@"
```

**Key Example: PostgreSQL init.sh**
- 410 lines total
- 8 main functions (wait_for_vault, fetch_credentials, etc.)
- Validates VAULT_TOKEN length
- Polls Vault for 120 seconds max
- Uses jq for JSON parsing
- Configures dual-mode TLS (accepts both SSL and non-SSL)
- Exports credentials as environment variables
- Execs original docker-entrypoint.sh with TLS flags

### Helper Scripts

**generate-certificates.sh** (23KB)
- Pre-generates all TLS certificates from Vault PKI
- Service-specific certificate formats
- 1-year TTL by default
- Checks expiration, skips valid certs (>30 days)
- Stores in ~/.config/vault/certs/

**vault-bootstrap.sh** (28KB)
- Sets up Root CA (10-year), Intermediate CA (5-year)
- Creates certificate roles for each service
- Generates service passwords (25-character alphanumeric)
- Creates Vault policies for access control
- Stores all credentials in KV v2 secrets engine
- Exports CA chain to ~/.config/vault/ca/

**load-vault-env.sh** (6.7KB)
- Sourced (not executed) to export variables
- Auto-loads VAULT_TOKEN from ~/.config/vault/root-token
- Reads individual secrets from Vault API
- Exports to environment for docker-compose
- Example-based documentation

**validate-sync.sh**, **sync-report.sh** (7.8KB, 7.8KB)
- Validates API synchronization between code-first and API-first
- Generates detailed sync reports
- Used in CI/CD pipeline

**validate-cicd.sh** (4.8KB)
- Checks CI/CD configuration validity
- Validates docker-compose configuration
- Runs pre-commit checks locally

### Makefile Conventions

**Purpose**: Platform-agnostic interface for CI/CD systems
**Pattern**:
- Help target as default goal
- Color-coded output (BLUE, GREEN, YELLOW, RED)
- Hierarchical comments (@@ markers)
- Each target has description suffix (## comment)
- Complex logic in shell scripts called from targets
- Test execution targets chain together
- Status target provides synchronization information

Example Targets:
```makefile
.PHONY: validate test sync-check extract-openapi
validate:          # Run all validation checks
test-code-first:   # Test code-first implementation only
regenerate:        # Regenerate API-first from OpenAPI spec
install-hooks:     # Install git pre-commit hooks
```

## 7. DOCUMENTATION PATTERNS

### Documentation Structure

**Directory**: docs/ (27 files, 62,000+ lines)

**Core Documentation**:
- README.md - Overview with table of contents
- INSTALLATION.md - Step-by-step with pre-flight checks
- SERVICES.md - Service configuration reference
- VAULT.md - PKI and secrets management
- MANAGEMENT.md - devstack command reference
- OBSERVABILITY.md - Prometheus, Grafana, Loki setup

**Reference Documentation**:
- ARCHITECTURE.md - System design with Mermaid diagrams
- BEST_PRACTICES.md - Development guidelines
- TROUBLESHOOTING.md - Issue diagnosis and resolution
- PERFORMANCE_TUNING.md - Optimization strategies
- VAULT_SECURITY.md - Security hardening

**Specialized Documentation**:
- REDIS.md - Redis cluster operations
- SECURITY_ASSESSMENT.md - Security audit guide
- DISASTER_RECOVERY.md - 30-minute RTO procedures
- TESTING_APPROACH.md - Testing methodology
- ENVIRONMENT_VARIABLES.md - All env vars documented

**Wiki Synchronization**:
- 50+ files synchronized with GitHub wiki
- Documentation duplicated for offline access
- Wiki provides interactive navigation

### Documentation Patterns

**Header Structure**:
```markdown
# Title

## Table of Contents
- [Section 1](#section-1)
- [Section 2](#section-2)
- [etc](#etc)

---

### Section 1
Content...

### Section 2
Content...
```

**Code Block Patterns**:
- Bash commands: ````bash ... ````
- YAML configuration: ````yaml ... ````
- JSON output: ````json ... ````
- Tree diagrams: ASCII art with proper indentation

**Reference Tables**:
- Service overview table with Version, Port(s), Purpose, Health Check
- Environment variable tables with descriptions
- Architecture comparison tables

**Inline Documentation**:
- Extensive comments in configuration files
- Every .env.example line explained
- CLAUDE.md for AI assistant guidance

### .env.example Documentation Pattern

**Size**: 360+ lines (13KB)
**Structure**:
1. Header comment (project name, instructions)
2. Section headers with visual separator (===)
3. Grouped related variables
4. Inline comments for each variable
5. Default values shown in example assignments
6. Large NOTES section at end (100+ lines)
7. Cross-references to documentation

**Variable Naming Convention**:
- Uppercase with underscores
- Service name prefix (POSTGRES_, MYSQL_, REDIS_, etc.)
- Descriptive suffix (_PORT, _PASSWORD, _ENABLE_TLS, etc.)
- Boolean flags: _ENABLE_TLS, _HEALTH_INTERVAL
- Health parameters grouped: _HEALTH_INTERVAL, _HEALTH_TIMEOUT, _HEALTH_RETRIES

## 8. FILE NAMING CONVENTIONS

### Script Files
- **Executable scripts**: snake_case.sh (install-hooks.sh, generate-certificates.sh)
- **Library scripts**: common.sh (imported, not executed)
- **Management script**: manage-<system>.sh (devstack)
- **Test scripts**: test-<service>.sh (test-postgres.sh)
- **Initialization scripts**: init.sh (in subdirectories)

### Configuration Files
- **Docker Compose**: docker-compose.yml (single file)
- **Vault config**: vault.hcl (HCL format)
- **Prometheus config**: prometheus.yml
- **Loki config**: loki-config.yml
- **Service configs**: <service>.conf or <service>.yml
- **Vector config**: vector.yaml
- **Promtail config**: promtail-config.yml

### Container Names
- Pattern: dev-<service> (dev-postgres, dev-mysql, dev-vault)
- Rationale: Easy identification, avoids conflicts

### Volume Names
- Pattern: <service>_data (postgres_data, redis_1_data, mongodb_data)
- Network names: dev-services

### Directory Names
- **Service configs**: lowercase with hyphens if needed
- **Internal script directories**: scripts/ (never bin/)
- **Config subdirs**: exporters/, provisioning/, scripts/

### Documentation Files
- **Markdown files**: UPPERCASE_WITH_UNDERSCORES.md
- **Wiki files**: Title-Case-With-Hyphens.md
- **Guides**: guides/<action>-guide.md pattern
- **Reference**: reference/<system>-reference.md pattern

## 9. ENVIRONMENT VARIABLES STRUCTURE

### Vault Configuration
```
VAULT_ADDR=http://vault:8200
VAULT_TOKEN=<auto-loaded from ~/.config/vault/root-token>
```

### Network IP Allocation
```
POSTGRES_IP=172.20.0.10
PGBOUNCER_IP=172.20.0.11
MYSQL_IP=172.20.0.12
# ... (defined for all services)
```

### Service-Specific Configuration
Each service has:
```
<SERVICE>_USER              # Username/admin user
<SERVICE>_PASSWORD          # Password (often empty, loaded from Vault)
<SERVICE>_DATABASE          # Database name
<SERVICE>_HOST_PORT         # Host port mapping
<SERVICE>_ENABLE_TLS        # Boolean flag for TLS
```

### Health Check Parameters
```
<SERVICE>_HEALTH_INTERVAL    # default: 60s
<SERVICE>_HEALTH_TIMEOUT     # default: 5s
<SERVICE>_HEALTH_RETRIES     # default: 5
<SERVICE>_HEALTH_START_PERIOD # default: 30s
```

### Performance Tuning
```
POSTGRES_MAX_CONNECTIONS=100
POSTGRES_SHARED_BUFFERS=256MB
POSTGRES_EFFECTIVE_CACHE_SIZE=1GB
POSTGRES_WORK_MEM=8MB

MYSQL_MAX_CONNECTIONS=100
MYSQL_INNODB_BUFFER_POOL=256M

REDIS_MAXMEMORY=256mb
```

### Observability Configuration
```
PROMETHEUS_PORT=9090
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
LOKI_PORT=3100
```

### Reference Application Configuration
```
REFERENCE_API_HTTP_PORT=8000
REFERENCE_API_HTTPS_PORT=8443
REFERENCE_API_ENABLE_TLS=true
```

## 10. INITIALIZATION AND SETUP FLOWS

### First-Time Setup Sequence

**Step 1: Install Dependencies**
```bash
brew install colima docker docker-compose
```

**Step 2: Clone and Configure**
```bash
git clone https://github.com/NormB/devstack-core.git
cd devstack-core
cp .env.example .env
nano .env  # Optional: change default passwords
```

**Step 3: Start Infrastructure**
```bash
./devstack start
# Starts Colima VM, then docker-compose up -d for all services
```

**Step 4: Vault Initialization (First Time Only)**
```bash
./devstack vault-init
# Initializes Vault, saves keys and token
```

**Step 5: Vault Bootstrap (First Time Only)**
```bash
./devstack vault-bootstrap
# Sets up PKI, generates credentials, stores in Vault
```

**Step 6: Generate Service Certificates**
```bash
./scripts/generate-certificates.sh
# Pre-generates TLS certificates from Vault PKI
```

**Step 7: Verify Setup**
```bash
./devstack health
./devstack status
```

### Service Startup Order

**Enforced Dependencies**:
1. Colima VM starts first (in devstack)
2. Vault starts first (no depends_on from other services)
3. Other services depend on: vault (condition: service_healthy)
4. PostgreSQL + MySQL + MongoDB start in parallel (all depend on Vault)
5. Forgejo depends on PostgreSQL healthy
6. Reference APIs depend on healthy status

**Initialization Flow for Any Database Service**:
1. Container pulls image
2. Container starts, executes entrypoint: ["/init/init.sh"]
3. init.sh waits for Vault health (120s timeout)
4. init.sh fetches credentials from Vault
5. init.sh validates pre-generated certificates (if TLS enabled)
6. init.sh configures TLS environment variables
7. init.sh execs docker-entrypoint.sh with credentials
8. Database starts with injected credentials
9. Healthcheck polls database for readiness
10. Service marked healthy, dependent services can start

### Service Access from Different Locations

**From Mac Host**:
```
PostgreSQL:        localhost:5432
Redis:             localhost:6379
Forgejo:           http://localhost:3000
Vault:             http://localhost:8200/ui
Prometheus:        http://localhost:9090
Grafana:           http://localhost:3001
```

**From UTM VM**:
```
Get Colima IP: colima list | grep default | awk '{print $NF}'
PostgreSQL:    <COLIMA_IP>:5432
Forgejo:       http://<COLIMA_IP>:3000
Redis:         <COLIMA_IP>:6379
```

**From Inside Container**:
```
PostgreSQL:    postgres:5432 (service name resolution)
Redis:         redis-1:6379
Vault:         vault:8200
Forgejo:       forgejo:3000
```

## 11. TESTING PATTERNS

### Test Infrastructure

**Master Test Runner**: tests/run-all-tests.sh
- Orchestrates all 370+ tests
- Bash test suites (infrastructure, databases, messaging)
- Python pytest suites (unit tests, integration tests)
- 300+ tests total

**Shared Test Library**: tests/lib/common.sh
- 400+ lines of helper functions
- Logging functions: info, success, warn, error, debug
- Vault integration functions
- Container health monitoring
- Retry mechanisms with exponential backoff
- Test data management
- Result reporting and statistics

**Bash Test Pattern**:
```bash
#!/bin/bash
# Header with purpose, dependencies, usage

source ../lib/common.sh

# Initialize test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Test functions
test_something() {
    local description="$1"
    TESTS_RUN=$((TESTS_RUN+1))
    
    if [ condition ]; then
        success "$description"
        TESTS_PASSED=$((TESTS_PASSED+1))
    else
        fail "$description"
        TESTS_FAILED=$((TESTS_FAILED+1))
        FAILED_TESTS+=("$description")
    fi
}

# Run tests
test_something "description"
test_something "description"

# Report results
print_test_results "Test Suite Name"
```

**Test Coverage Areas**:
- Vault PKI and auto-unseal
- Database connectivity and health
- Credential management
- TLS certificate validation
- Redis cluster operations
- RabbitMQ queue operations
- MongoDB operations
- Performance benchmarks
- Negative test cases (error handling)
- Security tests

### Test Organization

```
tests/
├── lib/
│   ├── common.sh            # Shared functions
│   ├── postgres_client.py   # DB connection helpers
│   ├── redis_client.py
│   ├── mongodb_client.py
│   ├── rabbitmq_client.py
│   ├── vault_client.py
│   └── mysql_client.py
├── run-all-tests.sh         # Master orchestrator
├── test-vault.sh            # Service-specific tests
├── test-postgres.sh
├── test-redis.sh
├── test-redis-cluster.sh
├── test-rabbitmq.sh
├── test-mongodb.sh
├── test-mysql.sh
├── test-fastapi.sh
├── test-performance.sh
├── test-negative.sh
├── setup-test-env.sh
├── performance-benchmark.sh
├── requirements.txt
├── pyproject.toml
└── TEST_COVERAGE.md
```

## 12. QUALITY ASSURANCE & GIT HOOKS

### Pre-commit Configuration

**File**: .pre-commit-config.yaml
**Dependencies**:
```yaml
- General checks (pre-commit-hooks)
  - Trailing whitespace
  - End-of-file fixer
  - YAML/JSON validation
  - Large file detection (>1MB)
  - Executability checks
  - Private key detection
- Shell script checks (shellcheck-py, shfmt)
  - Lint with ShellCheck (warning level)
  - Format with shfmt (-i 2, -ci, -sr)
- Python checks (ruff)
  - Linting and formatting
- YAML formatting (google/yamlfmt)
- Markdown linting (markdownlint-cli)
- Docker Compose validation (local hook)
- Environment file validation (local hook)
- Secrets detection (detect-secrets)
- Git commit message linting (gitlint)
```

### Hook Installation
```bash
./scripts/install-hooks.sh
# or
make install-hooks
```

## 13. REFERENCE IMPLEMENTATIONS

### Language Implementations

**FastAPI (Code-First)** - reference-apps/fastapi/
- Rapid development, implementation drives documentation
- Health checks for all infrastructure
- Vault integration (KV secrets, PKI)
- Database connectivity examples
- Redis caching patterns
- RabbitMQ messaging
- HTTPS/TLS support
- Comprehensive test suite

**FastAPI (API-First)** - reference-apps/fastapi-api-first/
- OpenAPI specification-driven
- Generated from shared spec
- Contract-first development
- Consistent behavior with code-first
- Demonstrates API-first patterns

**Go/Gin** - reference-apps/golang/
- Compiled binary with goroutines
- Production-ready patterns
- Concurrent request handling
- Vault integration
- Database connection pooling

**Node.js/Express** - reference-apps/nodejs/
- Event-driven async/await
- Modern JavaScript patterns
- Comprehensive middleware
- Error handling examples

**Rust/Actix-web** - reference-apps/rust/
- Memory-safe high-performance
- Zero-cost abstractions
- Async Tokio runtime
- Production-grade error handling

### Shared Test Suite - reference-apps/shared/test-suite/
- OpenAPI specification (openapi.yaml, openapi.json)
- Executable tests in multiple languages
- Ensures behavioral consistency
- Tests all implementations identically
- Automated via CI/CD

## 14. KEY FILES & PATTERNS SUMMARY

### Most Important Files to Study

| File | Purpose | Size | Key Pattern |
|------|---------|------|-------------|
| docker-compose.yml | Service definitions | 41KB | Complete service config with x-templates |
| devstack | Operations interface | 51KB | Master script with 20+ commands |
| .env.example | Configuration template | 13KB | Documented placeholders with sections |
| configs/postgres/scripts/init.sh | Vault integration | 410 lines | Service initialization with Vault |
| configs/vault/vault.hcl | Vault config | 34 lines | File storage, HTTP listener, file backend |
| scripts/vault-bootstrap.sh | PKI setup | 28KB | Two-tier CA, credential generation |
| tests/lib/common.sh | Test library | 400+ lines | Shared testing functions and helpers |
| docs/VAULT.md | Vault documentation | 200+ lines | PKI architecture, integration patterns |
| docs/SERVICES.md | Service reference | 500+ lines | Service configuration details |
| Makefile | CI/CD interface | 170 lines | Platform-agnostic validation targets |

### Patterns to Replicate in voip-stack

1. **Docker Compose**: Single file with x-templates for reusable configs
2. **Environment Variables**: Section-based .env.example with extensive inline docs
3. **Management Script**: Master shell script for all operations
4. **Service Initialization**: Wrapper init.sh scripts with Vault integration
5. **Logging**: Consistent colored output (info, success, warn, error functions)
6. **Health Checks**: Comprehensive health check configuration per service
7. **Resource Limits**: CPU/memory reservations and limits
8. **Networking**: Custom network with static IP assignment
9. **Dependencies**: Service dependency chain with health conditions
10. **Documentation**: Markdown-based with extensive inline comments
11. **Testing**: Shared test library with consistent patterns
12. **Scripts**: 500-line scripts with 100+ line documentation headers

