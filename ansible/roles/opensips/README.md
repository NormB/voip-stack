# OpenSIPS Role

Installs and configures OpenSIPS 3.5+ SIP proxy server with support for Docker, source compilation, and package installation.

## Features

- **Docker deployment** (default) - Pre-built ARM64 images for fast deployment
- **Source compilation** - Maximum control and optimization
- **Package installation** - Official APT repository fallback
- **Forgejo mirror support** - Faster local builds
- **ARM64 optimized** - Compilation flags for Apple Silicon
- **PostgreSQL** - Database backend for usrloc, dialog, dispatcher
- **Redis** - Caching support for session state
- **RTPEngine** - Media relay integration
- **Homer/HEP** - SIP capture and tracing
- **TLS** - Encryption support

## Requirements

- Debian 12 (Bookworm) on ARM64
- Docker (for Docker deployment method)
- Vault authentication configured (for production credentials)
- PostgreSQL database available (devstack-core @ 192.168.64.1)
- Redis available (devstack-core @ 192.168.64.1)
- RTPEngine available (media-1 @ 192.168.64.20)

## Installation Methods

### Docker Deployment (Default - Recommended)

Uses pre-built Docker images for fastest deployment. The container runs in host network mode for optimal SIP performance.

```yaml
# defaults/main.yml or inventory vars
opensips_install_method: docker
opensips_docker_image: "localhost:3000/gator/opensips:3.5-arm64"
```

**Features:**
- Fast deployment (~30 seconds vs 5-10 minutes for source)
- Consistent environment across deployments
- Easy rollback and updates
- Pre-compiled with all common modules

**Container Configuration:**
- Runs as `opensips` user
- Host network mode (required for SIP)
- Configuration mounted from `/etc/opensips/`
- Logs to `/var/log/opensips/`

### Source Compilation

Compiles OpenSIPS from source with selected modules:

```yaml
opensips_install_method: source
```

Recommended for:
- Custom module selection
- Performance optimization
- Latest features not yet in packages

### Package Installation

Uses official OpenSIPS APT repository:

```yaml
opensips_install_method: package
```

## Role Variables

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_install_method` | `docker` | Installation method: `docker`, `source`, or `package` |
| `opensips_version` | `3.5` | OpenSIPS version |
| `opensips_enabled` | `true` | Enable OpenSIPS deployment |

### Docker Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_docker_image` | `localhost:3000/gator/opensips:3.5-arm64` | Docker image to use |
| `opensips_docker_compose_dir` | `/opt/opensips` | Docker compose directory |
| `opensips_docker_pull_always` | `false` | Force pull image on every deploy |

### Build Settings (Source Installation)

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_git_repo` | GitHub URL | Source repository |
| `opensips_git_branch` | `3.5` | Git branch to compile |
| `opensips_forgejo_mirror` | `""` | Local Forgejo mirror URL |
| `opensips_build_dir` | `/usr/local/src/opensips` | Build directory |
| `opensips_compile_jobs` | `{{ ansible_processor_vcpus }}` | Parallel jobs |
| `opensips_cflags` | `-O2 -march=armv8-a` | Compiler flags |

### Service Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_user` | `opensips` | Service user |
| `opensips_group` | `opensips` | Service group |
| `opensips_sip_port` | `5060` | SIP UDP/TCP port |
| `opensips_sip_tls_port` | `5061` | SIP TLS port |
| `opensips_listen_interfaces` | See defaults | Listen interfaces |

### Database Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_db_host` | `192.168.64.1` | PostgreSQL host |
| `opensips_db_port` | `5432` | PostgreSQL port |
| `opensips_db_name` | `opensips` | Database name |
| `opensips_db_user` | `opensips` | Database user |

### Memory and Performance

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_children` | `4` | UDP worker processes (maps to `udp_workers`) |
| `opensips_tcp_children` | `4` | TCP worker processes (maps to `tcp_workers`) |

### HEP/Homer Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_hep_enabled` | `true` | Enable HEP tracing |
| `opensips_homer_host` | `192.168.64.1` | Homer server address |
| `opensips_homer_port` | `9060` | Homer HEP port |

### TLS Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `opensips_tls_enabled` | `false` | Enable TLS |
| `opensips_tls_cert_dir` | `/etc/opensips/tls` | TLS certificate directory |

## OpenSIPS 3.5 Configuration Changes

OpenSIPS 3.5 introduced several syntax changes from previous versions. This role handles these automatically:

| Old Syntax | New Syntax (3.5+) |
|------------|-------------------|
| `children=N` | `udp_workers=N` |
| `tcp_children=N` | `tcp_workers=N` |
| `listen=udp:...` | `socket=udp:...` |
| `log_stderror=yes` | `stderror_enabled=yes` |
| `log_facility=LOG_LOCAL0` | `syslog_facility=LOG_LOCAL0` |

**Transport modules** must now be explicitly loaded:
```
loadmodule "proto_udp.so"
loadmodule "proto_tls.so"  # if TLS enabled
```

The deprecated `-E` command-line flag is replaced by `-F` for foreground operation.

## Dependencies

This role depends on:
- `common` - Base system setup
- `docker` - Docker engine (for Docker deployment)
- `vault-client` - Vault integration (optional but recommended)

## Usage

### Basic Usage (Docker)

```yaml
- hosts: sip_proxies
  roles:
    - role: opensips
```

### Source Compilation

```yaml
- hosts: sip_proxies
  roles:
    - role: opensips
      vars:
        opensips_install_method: source
        opensips_version: "3.5.1"
        opensips_modules:
          - db_postgres
          - cachedb_redis
          - rtpengine
          - proto_tls
```

### Using Forgejo Mirror

1. Create a mirror repository in Forgejo:
   ```
   http://localhost:3000 → New repo → Migration from URL
   Source: https://github.com/OpenSIPS/opensips.git
   ```

2. Configure the role:
   ```yaml
   opensips_forgejo_mirror: "http://192.168.64.1:3000/gator/opensips.git"
   ```

## Templates

| Template | Purpose |
|----------|---------|
| `opensips.cfg.j2` | Main OpenSIPS configuration |
| `docker-compose.yml.j2` | Docker deployment configuration |
| `opensips-docker.service.j2` | Systemd service for Docker |
| `opensips.service.j2` | Systemd service for native |

### opensips.cfg.j2 Features

The main configuration template provides:

- **Global settings**: Worker processes, logging, memory
- **Listeners**: UDP, TCP, TLS (configurable via `opensips_listen_interfaces`)
- **Modules**: Database, auth, registrar, dialog, dispatcher, rtpengine, HEP
- **Routing logic**:
  - REGISTER handling with digest authentication
  - INVITE processing with RTPEngine integration
  - Sequential request routing (in-dialog)
  - Failure handling

## Handlers

| Handler | Description |
|---------|-------------|
| `restart opensips` | Restart OpenSIPS (Docker or native) |
| `reload opensips` | Reload configuration |
| `Reload systemd` | Reload systemd daemon |

## Directory Structure

### Docker Deployment
```
/opt/opensips/
├── docker-compose.yml     # Docker compose configuration

/etc/opensips/
├── opensips.cfg           # Main configuration (mounted into container)
└── tls/                   # TLS certificates
    ├── server.crt
    ├── server.key
    └── ca.crt

/var/log/opensips/
└── opensips.log           # Log file (mounted volume)
```

### Native Deployment
```
/etc/opensips/
├── opensips.cfg
└── tls/

/var/log/opensips/
└── opensips.log

/var/run/opensips/
└── opensips.pid

/usr/local/sbin/          # (source) or /usr/sbin/ (package)
├── opensips
├── opensipsctl
└── opensips-cli

/lib64/opensips/modules/  # (Docker path)
/usr/local/lib64/opensips/modules/  # (source path)
└── *.so
```

## Testing

### Check Service Status

```bash
# Docker deployment
ssh voip@192.168.64.10 'docker ps | grep opensips'
ssh voip@192.168.64.10 'docker logs opensips --tail 50'

# Native deployment
ssh voip@192.168.64.10 'systemctl status opensips'
```

### Check OpenSIPS Version

```bash
# Docker
ssh voip@192.168.64.10 'docker exec opensips opensips -V'

# Native
ssh voip@192.168.64.10 'opensips -V'
```

### Verify SIP Listening

```bash
# Check UDP port
ssh voip@192.168.64.10 'nc -z -u -v 127.0.0.1 5060'

# Check from Mac
nc -z -u -v 192.168.64.10 5060
```

### Test SIP Registration

```bash
# Using sipsak (install via brew)
sipsak -U -C sip:test@192.168.64.10 -s sip:1001@192.168.64.10

# Using sngrep to capture traffic
sngrep -d any port 5060
```

### Validate Configuration

```bash
# Docker
ssh voip@192.168.64.10 'docker exec opensips opensips -c -f /etc/opensips/opensips.cfg'

# Native
ssh voip@192.168.64.10 'opensips -c -f /etc/opensips/opensips.cfg'
```

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
ssh voip@192.168.64.10 'docker logs opensips'

# Check systemd service
ssh voip@192.168.64.10 'systemctl status opensips'
ssh voip@192.168.64.10 'journalctl -u opensips -f'
```

**Common Issues:**
- **Exit code 255**: Deprecated `-E` flag - ensure `command: ["-F"]` in docker-compose
- **Config parse errors**: Check for deprecated 3.5 syntax
- **Missing module**: Ensure `proto_udp.so` is loaded

### Configuration Validation Fails

```bash
# Get detailed error
ssh voip@192.168.64.10 'docker exec opensips opensips -c -f /etc/opensips/opensips.cfg 2>&1'

# Common fixes:
# - Use socket= instead of listen=
# - Use udp_workers= instead of children=
# - Load proto_udp.so before other modules
```

### Database Connection Issues

```bash
# Test PostgreSQL connection from VM
ssh voip@192.168.64.10 'psql -h 192.168.64.1 -U opensips -d opensips -c "SELECT 1"'

# Check from container
ssh voip@192.168.64.10 'docker exec opensips nc -z 192.168.64.1 5432'
```

### Port Already in Use

```bash
# Check what's using port 5060
ssh voip@192.168.64.10 'ss -nlup | grep 5060'

# May indicate native service conflicting with Docker
ssh voip@192.168.64.10 'systemctl list-units | grep opensips'
```

### Healthcheck Failing

The Docker healthcheck uses UDP port check:
```bash
# Test healthcheck manually
ssh voip@192.168.64.10 'nc -z -u 192.168.64.10 5060 && echo OK'
```

Note: TCP healthchecks will fail since OpenSIPS primarily listens on UDP.

## Performance Tuning

### Worker Processes
```yaml
# Increase for high traffic
opensips_children: 8        # UDP workers
opensips_tcp_children: 4    # TCP workers (if TLS enabled)
```

### Database Connection Pool
Configure in `db_postgres` module parameters in the config template.

### RTPEngine Integration
Ensure `rtpengine_socket` is correctly configured and RTPEngine is healthy.

## References

- [OpenSIPS 3.5 Documentation](https://www.opensips.org/Documentation/Tutorials-3-5)
- [OpenSIPS 3.5 Core Parameters](https://www.opensips.org/Documentation/Script-CoreParameters-3-5)
- [OpenSIPS Docker Hub](https://hub.docker.com/r/opensips/opensips)
- [voip-stack Architecture](../../docs/ARCHITECTURE.md)

## Changelog

### 2024-12 Updates
- Added Docker deployment method (now default)
- Updated configuration for OpenSIPS 3.5 syntax changes
- Fixed healthcheck to use UDP instead of TCP
- Added conditional handlers for Docker vs native deployment
- Updated module path for container deployment

## Phase

Phase 1 - Core SIP Proxy
