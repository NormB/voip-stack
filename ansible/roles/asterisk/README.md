# Asterisk Role

Installs and configures Asterisk 20+ PBX server with Docker deployment support, PJSIP stack, and integration with OpenSIPS SIP proxy.

## Features

- **Docker deployment** (default) - Pre-built ARM64 images for fast deployment
- **Source compilation** - Build from source with custom modules
- **Package installation** - Official Asterisk APT repository
- **PJSIP stack** - Modern SIP implementation (replaces chan_sip)
- **PostgreSQL realtime** - Database-driven configuration
- **AMI/ARI interfaces** - Management and REST APIs
- **Call recording** - MixMonitor integration
- **CDR/CEL** - Call detail and event logging
- **Voicemail** - Integrated voicemail system
- **OpenSIPS integration** - Trunk connection to SIP proxy

## Requirements

- Debian 12 (Bookworm) on ARM64
- Docker (for Docker deployment method)
- Vault authentication configured (for production credentials)
- PostgreSQL database available (devstack-core @ 192.168.64.1)
- OpenSIPS SIP proxy (sip-1 @ 192.168.64.10)
- RTPEngine media proxy (media-1 @ 192.168.64.20)

## Architecture

```
                    External
                        │
                        ▼
    ┌───────────────────────────────────────┐
    │           OpenSIPS (sip-1)            │
    │         Registration & Routing         │
    │            192.168.64.10:5060          │
    └───────────────────┬───────────────────┘
                        │ SIP (port 5080)
                        ▼
    ┌───────────────────────────────────────┐
    │           Asterisk (pbx-1)            │
    │         Call Processing & Apps         │
    │            192.168.64.30:5080          │
    └───────────────────┬───────────────────┘
                        │ RTP Control
                        ▼
    ┌───────────────────────────────────────┐
    │          RTPEngine (media-1)          │
    │            Media Relay                 │
    │            192.168.64.20               │
    └───────────────────────────────────────┘
```

## Installation Methods

### Docker Deployment (Default)

Uses pre-built Docker images for fastest deployment:

```yaml
asterisk_install_method: docker
asterisk_docker_image: "192.168.64.1:3000/devadmin/asterisk:20-arm64"
```

**Container Configuration:**
- Runs as `asterisk` user
- Host network mode (required for SIP)
- Configuration mounted from `/etc/asterisk/`
- Logs to `/var/log/asterisk/`
- Spool directory at `/var/spool/asterisk/`

### Source Compilation

```yaml
asterisk_install_method: source
asterisk_version: "20"
```

### Package Installation

```yaml
asterisk_install_method: package
```

## Role Variables

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_install_method` | `docker` | Installation method |
| `asterisk_version` | `20` | Asterisk major version |
| `asterisk_enabled` | `true` | Enable Asterisk deployment |

### Docker Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_docker_image` | `192.168.64.1:3000/devadmin/asterisk:20-arm64` | Docker image |
| `asterisk_docker_compose_dir` | `/opt/asterisk` | Compose directory |
| `asterisk_docker_pull_always` | `false` | Force pull on deploy |

### Network Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_sip_port` | `5080` | PJSIP listen port |
| `asterisk_sip_tls_port` | `5081` | PJSIP TLS port |
| `asterisk_ami_port` | `5038` | AMI listen port |
| `asterisk_ami_bindaddr` | `{{ internal_ip }}` | AMI bind address |
| `asterisk_ari_port` | `8088` | ARI listen port |
| `asterisk_ari_bindaddr` | `{{ internal_ip }}` | ARI bind address |

### Database Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_db_host` | `192.168.64.1` | PostgreSQL host |
| `asterisk_db_port` | `5432` | PostgreSQL port |
| `asterisk_db_name` | `asterisk` | Database name |
| `asterisk_db_user` | `asterisk` | Database user |
| `asterisk_realtime_enabled` | `true` | Enable realtime config |

### Integration Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_opensips_host` | `192.168.64.10` | OpenSIPS SIP proxy |
| `asterisk_rtpengine_socket` | `udp:192.168.64.20:2223` | RTPEngine socket |

### Feature Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_ami_enabled` | `true` | Enable AMI |
| `asterisk_ari_enabled` | `true` | Enable ARI |
| `asterisk_cdr_enabled` | `true` | Enable CDR |
| `asterisk_voicemail_enabled` | `true` | Enable voicemail |
| `asterisk_recording_enabled` | `true` | Enable call recording |

### Performance Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `asterisk_max_calls` | `100` | Maximum concurrent calls |
| `asterisk_max_open_files` | `16384` | File descriptor limit |
| `asterisk_log_level` | `notice` | Log level |
| `asterisk_log_verbose` | `3` | Verbose level |

## Templates

### Core Configuration

| Template | Destination | Description |
|----------|-------------|-------------|
| `asterisk.conf.j2` | `asterisk.conf` | Main Asterisk configuration |
| `modules.conf.j2` | `modules.conf` | Module loading configuration |
| `logger.conf.j2` | `logger.conf` | Logging configuration |

### PJSIP Configuration

| Template | Destination | Description |
|----------|-------------|-------------|
| `pjsip.conf.j2` | `pjsip.conf` | PJSIP stack configuration |

**pjsip.conf.j2 Features:**
- **Transports**: UDP and TCP on port 5080
- **OpenSIPS trunk**: Endpoint for SIP proxy connection
- **Endpoint templates**: Reusable configs for extensions
- **Static extensions**: Optional test extensions
- **Realtime support**: PostgreSQL-driven endpoints

### Dialplan

| Template | Destination | Description |
|----------|-------------|-------------|
| `extensions.conf.j2` | `extensions.conf` | Dialplan configuration |

**extensions.conf.j2 Contexts:**
- `from-opensips`: Inbound calls from SIP proxy
- `internal`: Internal extension dialing (1XXX, 2XXX)
- `internal-missed`: Voicemail on no answer
- `to-opensips`: Outbound routing via SIP proxy

**Feature Codes:**
- `*98`: Voicemail access
- `*1XXX`: Direct voicemail for extension
- `*43`: Echo test
- `*60`: Speaking clock

### Interfaces

| Template | Destination | Description |
|----------|-------------|-------------|
| `manager.conf.j2` | `manager.conf` | AMI configuration |
| `ari.conf.j2` | `ari.conf` | ARI configuration |

### Other

| Template | Destination | Description |
|----------|-------------|-------------|
| `cdr.conf.j2` | `cdr.conf` | CDR configuration |
| `voicemail.conf.j2` | `voicemail.conf` | Voicemail configuration |
| `docker-compose.yml.j2` | Docker compose | Container deployment |
| `asterisk-docker.service.j2` | systemd service | Service management |

## Dependencies

- `common` - Base system setup
- `docker` - Docker engine (for Docker deployment)
- `vault-client` - Vault integration (optional)

## Usage

### Basic Usage (Docker)

```yaml
- hosts: pbx_servers
  roles:
    - role: asterisk
```

### With Custom Variables

```yaml
- hosts: pbx_servers
  roles:
    - role: asterisk
      vars:
        asterisk_install_method: docker
        asterisk_max_calls: 200
        asterisk_recording_enabled: true
        asterisk_static_extensions:
          - number: "1001"
            name: "Test User 1"
            password: "secret123"
          - number: "1002"
            name: "Test User 2"
            password: "secret456"
```

## Directory Structure

### Docker Deployment

```
/opt/asterisk/
├── docker-compose.yml

/etc/asterisk/
├── asterisk.conf          # Main configuration
├── modules.conf           # Module loading
├── logger.conf            # Logging
├── pjsip.conf            # PJSIP SIP stack
├── extensions.conf        # Dialplan
├── manager.conf          # AMI
├── ari.conf              # ARI
├── cdr.conf              # CDR
├── voicemail.conf        # Voicemail
└── tls/                  # TLS certificates

/var/log/asterisk/
├── messages              # Main log
├── security              # Security events (fail2ban)
└── cdr-csv/              # CDR CSV files

/var/spool/asterisk/
├── voicemail/            # Voicemail storage
├── recording/            # Call recordings
└── monitor/              # Monitor recordings
```

## Handlers

| Handler | Description |
|---------|-------------|
| `restart asterisk` | Restart Asterisk (Docker or native) |
| `Reload asterisk` | Reload configuration |

## Testing

### Check Service Status

```bash
# Docker deployment
ssh voip@192.168.64.30 'docker ps | grep asterisk'
ssh voip@192.168.64.30 'docker logs asterisk --tail 50'

# Native deployment
ssh voip@192.168.64.30 'systemctl status asterisk'
```

### Asterisk CLI

```bash
# Docker
ssh voip@192.168.64.30 'docker exec -it asterisk asterisk -rvvv'

# Native
ssh voip@192.168.64.30 'asterisk -rvvv'
```

### Check PJSIP Configuration

```bash
# List endpoints
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show endpoints"'

# List transports
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show transports"'

# Show OpenSIPS trunk
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show endpoint opensips-trunk"'
```

### Check Active Channels

```bash
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "core show channels"'
```

### Check Registrations

```bash
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show registrations"'
```

### AMI Connection Test

```bash
# From VM
ssh voip@192.168.64.30 'nc -z 127.0.0.1 5038 && echo "AMI OK"'
```

### ARI Connection Test

```bash
# From VM
ssh voip@192.168.64.30 'curl -s http://127.0.0.1:8088/ari/api-docs/resources.json | head'
```

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
ssh voip@192.168.64.30 'docker logs asterisk'

# Check systemd service
ssh voip@192.168.64.30 'systemctl status asterisk'
ssh voip@192.168.64.30 'journalctl -u asterisk -f'
```

### PJSIP Endpoint Issues

```bash
# Check endpoint details
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show endpoint opensips-trunk"'

# Check AOR status
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip show aor opensips-aor"'

# Enable PJSIP debug
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "pjsip set logger on"'
```

### Call Not Connecting

```bash
# Check dialplan
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "dialplan show from-opensips"'

# Enable verbose logging
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "core set verbose 5"'

# Watch calls in real-time
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "core show channels verbose"'
```

### Database Connection Issues

```bash
# Test PostgreSQL connection from VM
ssh voip@192.168.64.30 'psql -h 192.168.64.1 -U asterisk -d asterisk -c "SELECT 1"'

# Check realtime config
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "realtime show tables"'
```

### AMI/ARI Connection Refused

```bash
# Check listening ports
ssh voip@192.168.64.30 'ss -nltp | grep -E "5038|8088"'

# Check AMI users
ssh voip@192.168.64.30 'docker exec asterisk asterisk -rx "manager show users"'
```

## Integration with OpenSIPS

Asterisk receives calls forwarded from OpenSIPS via the `opensips-trunk` endpoint:

1. OpenSIPS authenticates and routes the call
2. INVITE is sent to Asterisk on port 5080
3. Asterisk matches the `opensips-identify` section by source IP
4. Call is processed in `from-opensips` context
5. Media is handled by RTPEngine

**Required OpenSIPS Configuration:**
```
# Dispatcher or static route to Asterisk
modparam("dispatcher", "ds_list", "1:sip:192.168.64.30:5080:0:0")
```

## Security Considerations

- Asterisk listens on port 5080 (not standard 5060) to avoid conflicts
- AMI/ARI bind to internal IP only by default
- Credentials should be stored in Vault
- Security logging enabled for fail2ban integration
- No direct external access (all traffic via OpenSIPS)

## Performance Tuning

### Concurrent Calls
```yaml
asterisk_max_calls: 200
```

### File Descriptors
```yaml
asterisk_max_open_files: 32768
```

### Logging
Reduce for production:
```yaml
asterisk_log_verbose: 0
asterisk_log_level: warning
```

## References

- [Asterisk Documentation](https://docs.asterisk.org/)
- [PJSIP Configuration](https://docs.asterisk.org/Configuration/Channel-Drivers/SIP/Configuring-res_pjsip/)
- [Asterisk REST Interface](https://docs.asterisk.org/Configuration/Interfaces/Asterisk-REST-Interface-ARI/)
- [voip-stack Architecture](../../docs/ARCHITECTURE.md)

## Changelog

### 2024-12 Updates
- Added Docker deployment method (now default)
- Created comprehensive pjsip.conf.j2 template
- Created extensions.conf.j2 with OpenSIPS integration
- Added manager.conf.j2, ari.conf.j2 templates
- Added cdr.conf.j2, voicemail.conf.j2 templates
- Fixed service.yml version output in check mode

## Phase

Phase 1 - PBX Core
