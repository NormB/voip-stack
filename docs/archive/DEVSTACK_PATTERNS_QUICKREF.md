# DevStack Core Patterns - Quick Reference

This is a condensed quick reference guide. For complete details, see [DEVSTACK_PATTERNS.md](./DEVSTACK_PATTERNS.md).

## Key Architectural Patterns to Replicate

### 1. Single Docker Compose File with YAML Anchors
```yaml
# Use x-templates for reusable configurations
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

# Reference in all services
services:
  service_name:
    logging: *default-logging
```

### 2. Service Definition Template
Every service follows this pattern in docker-compose.yml:
```yaml
service_name:
  image: version
  container_name: dev-service-name
  restart: unless-stopped
  entrypoint: ["/init/init.sh"]         # Wrapper for Vault integration
  environment:
    VAULT_ADDR: ${VAULT_ADDR:-http://vault:8200}
    VAULT_TOKEN: ${VAULT_TOKEN}
    SERVICE_IP: ${SERVICE_IP:-172.X.X.X}
  volumes:
    - service_data:/data
    - ./configs/service/scripts/init.sh:/init/init.sh:ro
    - ${HOME}/.config/vault/certs/service:/service-certs:ro
  networks:
    dev-services:
      ipv4_address: ${SERVICE_IP}
  depends_on:
    vault:
      condition: service_healthy
  healthcheck:
    test: ["CMD-SHELL", "health_check_command"]
    interval: ${SERVICE_HEALTH_INTERVAL:-60s}
    timeout: ${SERVICE_HEALTH_TIMEOUT:-5s}
    retries: ${SERVICE_HEALTH_RETRIES:-5}
    start_period: ${SERVICE_HEALTH_START_PERIOD:-30s}
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '0.5'
        memory: 512M
```

### 3. Vault Integration in Service Init Scripts
```bash
#!/bin/bash
# Pattern: configs/<service>/scripts/init.sh

set -e

# Configuration section
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_TOKEN="${VAULT_TOKEN}"
SERVICE_NAME="service-name"

# Colors (consistent across all scripts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
info() { echo -e "${BLUE}[Service Init]${NC} $1"; }
success() { echo -e "${GREEN}[Service Init]${NC} $1"; }
warn() { echo -e "${YELLOW}[Service Init]${NC} $1"; }
error() { echo -e "${RED}[Service Init]${NC} $1"; exit 1; }

# Step functions
wait_for_vault() {
    info "Waiting for Vault..."
    local max_attempts=60
    while [ $attempt -lt $max_attempts ]; do
        if wget --spider -q "$VAULT_ADDR/v1/sys/health?standbyok=true"; then
            success "Vault is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    error "Vault did not become ready"
}

fetch_credentials() {
    info "Fetching credentials from Vault..."
    local response=$(wget -qO- --header "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/$SERVICE_NAME")
    
    export SERVICE_USER=$(echo "$response" | jq -r '.data.data.user')
    export SERVICE_PASSWORD=$(echo "$response" | jq -r '.data.data.password')
    # ... more fields
    
    success "Credentials fetched"
}

main() {
    wait_for_vault
    fetch_credentials
    validate_certificates
    configure_tls
    
    # Exec original entrypoint with credentials
    exec docker-entrypoint.sh "$@"
}

main "$@"
```

### 4. .env.example Documentation Pattern
```bash
# Headers with visual separators
# ===========================================================================
# SERVICE_NAME Configuration
# ===========================================================================

# Inline comments explaining each variable
SERVICE_VAR=default_value

# Empty variables for secrets loaded from Vault
SERVICE_PASSWORD=

# Health check parameters grouped together
SERVICE_HEALTH_INTERVAL=60s
SERVICE_HEALTH_TIMEOUT=5s
SERVICE_HEALTH_RETRIES=5

# Large NOTES section at end (100+ lines explaining usage)
# ===========================================================================
# NOTES
# ===========================================================================
# 
# 1. How to access services
# 2. Vault credential retrieval examples
# 3. TLS certificate management
# 4. Security best practices
```

### 5. Master Management Script (manage-<system>.sh)
```bash
#!/bin/bash
# Pattern: manage-<system>.sh (51KB, 600+ lines)
# Single interface for all operations

set -euo pipefail

# Global configuration
COLIMA_PROFILE="${COLIMA_PROFILE:-default}"
export DOCKER_HOST="unix://${HOME}/.colima/${COLIMA_PROFILE}/docker.sock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Command functions
cmd_start() {
    info "Starting infrastructure..."
    colima start --cpu 4 --memory 8
    docker compose up -d
    success "Infrastructure started"
}

cmd_stop() {
    info "Stopping infrastructure..."
    docker compose down
    colima stop
    success "Infrastructure stopped"
}

# Router
case "${1:-help}" in
    start)        cmd_start ;;
    stop)         cmd_stop ;;
    status)       cmd_status ;;
    logs)         cmd_logs "$@" ;;
    help)         cmd_help ;;
    *)            error "Unknown command: $1" ;;
esac
```

### 6. Network Isolation Pattern
```yaml
networks:
  dev-services:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  service_name:
    networks:
      dev-services:
        ipv4_address: 172.20.0.10
```

### 7. Static IP Assignment Strategy
```
Tier 1: Core Infrastructure
172.20.0.10   → PostgreSQL
172.20.0.11   → PgBouncer
172.20.0.12   → MySQL
172.20.0.13   → Redis-1
172.20.0.14   → RabbitMQ
172.20.0.15   → MongoDB
172.20.0.16   → Redis-2
172.20.0.17   → Redis-3

Tier 2: Git & Secrets
172.20.0.20   → Forgejo
172.20.0.21   → Vault

Tier 3: Observability
172.20.0.100  → Applications
172.20.0.101  → Prometheus
172.20.0.102  → Grafana
172.20.0.103  → Loki
```

### 8. Documentation Structure
```
docs/
├── README.md                    # Overview
├── INSTALLATION.md              # Setup guide
├── SERVICES.md                  # Service reference
├── VAULT.md                     # PKI documentation
├── MANAGEMENT.md                # Script reference
├── ARCHITECTURE.md              # Design diagrams
├── TROUBLESHOOTING.md           # Issue resolution
├── BEST_PRACTICES.md            # Development guidelines
├── COLIMA_PATTERNS.md           # Pattern reference (NEW)
└── [13 more specialized docs]
```

### 9. Testing Pattern
```bash
#!/bin/bash
# Pattern: tests/test-<service>.sh

source lib/common.sh

# Initialize counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS=()

# Test function
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
test_something "test description 1"
test_something "test description 2"

# Report
print_test_results "Test Suite Name"
```

### 10. Pre-commit Hooks Configuration
```yaml
# .pre-commit-config.yaml

repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: detect-private-key

  - repo: https://github.com/shellcheck-py/shellcheck-py
    hooks:
      - id: shellcheck
        args: [--severity=warning]

  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks:
      - id: ruff
      - id: ruff-format
```

## Environment Variable Naming Convention

```
<SERVICE>_<PROPERTY>

Examples:
POSTGRES_HOST_PORT          # Host-facing port
POSTGRES_HEALTH_INTERVAL    # Health check interval
POSTGRES_ENABLE_TLS         # Boolean flag
POSTGRES_MAX_CONNECTIONS    # Performance tuning
VAULT_ADDR                  # Service address
VAULT_TOKEN                 # Authentication
```

## File Naming Conventions

| Type | Pattern | Examples |
|------|---------|----------|
| Scripts | snake_case.sh | generate-certificates.sh |
| Configs | lowercase | docker-compose.yml, vault.hcl |
| Containers | dev-<service> | dev-postgres, dev-vault |
| Volumes | <service>_data | postgres_data, redis_1_data |
| Docs | UPPERCASE.md | VAULT.md, SERVICES.md |
| Wiki | Title-Case.md | Service-Overview.md |

## Command Pattern (Makefile)

```makefile
.PHONY: validate test help

help: ## Display this help message
	@echo "Available targets:"
	@awk '/^[a-zA-Z_-]+:.*?##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

validate: ## Run all validation checks
	@echo "Running validation..."
	@./scripts/validate-sync.sh

test: ## Run all tests
	@./tests/run-all-tests.sh
```

## Critical Design Patterns for voip-stack

### Pattern 1: Vault-First Initialization
1. Start Vault first (no other service depends on it)
2. Wait for Vault health before other services
3. Fetch credentials at service startup
4. Store nothing in plaintext config

### Pattern 2: Layered Documentation
1. README: Quick start guide
2. INSTALLATION: Detailed setup steps
3. MANAGEMENT: Command reference
4. .env.example: In-line parameter documentation
5. CLAUDE.md: AI assistant guidance
6. Inline code comments: Implementation details

### Pattern 3: Health Check Driven Startup
1. Every service has a healthcheck
2. Services depend on healthcheck conditions
3. Startup order enforced by conditions
4. No hard-coded wait times

### Pattern 4: Consistent Logging
```bash
info()    → Blue [INFO] message
success() → Green [OK] message
warn()    → Yellow [WARN] message
error()   → Red [ERROR] message and exit
```

### Pattern 5: Resource Management
```yaml
deploy:
  resources:
    limits:        # Hard limits
      cpus: '2'
      memory: 2G
    reservations:  # Soft guarantees
      cpus: '0.5'
      memory: 512M
```

## File Size Guidelines

| Component | Size | Lines |
|-----------|------|-------|
| docker-compose.yml | 40-50KB | 1000+ |
| manage-<system>.sh | 50-60KB | 600+ |
| Service init.sh | 10-15KB | 400+ |
| Helper script | 5-20KB | 150-300 |
| Test script | 5-10KB | 150-250 |
| Documentation | Variable | 100+ lines each |

## Quick Replication Checklist for voip-stack

- [ ] Single docker-compose.yml with x-templates for reusable configs
- [ ] .env.example with 300+ lines of documentation
- [ ] manage-voip.sh (or similar) with 20+ commands
- [ ] configs/<service>/scripts/init.sh for each service
- [ ] Vault integration for secret management
- [ ] Static IP assignment (separate subnet)
- [ ] Health checks for all services
- [ ] Resource limits and reservations
- [ ] Comprehensive documentation (docs/ directory)
- [ ] Testing framework (tests/lib/common.sh + test-*.sh)
- [ ] Pre-commit hooks configuration
- [ ] Makefile for CI/CD interface
- [ ] CLAUDE.md for AI assistant guidance

## Services to Configure in voip-stack

Following devstack-core pattern:

**Core VoIP Services** (replacing development databases):
- OpenSIPS (sip-1 VM)
- Asterisk (pbx-1 VM)
- RTPEngine (media-1 VM)

**Infrastructure** (from devstack-core):
- PostgreSQL (16-alpine) - separate DB per component
- Redis Cluster (3-node) - session state, caching
- RabbitMQ - CDR publishing
- Vault - secrets management
- Prometheus/Grafana - metrics and dashboards
- Loki - log aggregation
- Homer - SIP capture (HEP)

**Development Support**:
- Forgejo - local git repository
- PgBouncer - connection pooling

## References

- **Complete Guide**: [DEVSTACK_PATTERNS.md](../reference/DEVSTACK_PATTERNS.md)
- **DevStack Core**: https://github.com/NormB/devstack-core
- **Docker Compose**: https://docs.docker.com/compose/
- **HashiCorp Vault**: https://www.vaultproject.io/docs
- **Best Practices**: See docs/BEST_PRACTICES.md in voip-stack

