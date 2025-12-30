# RTPEngine Role

Installs and configures RTPEngine media proxy with kernel module for high-performance RTP/SRTP relay.

## Features

- **Native installation** - Required for kernel module (Docker not supported)
- **Package installation** (default) - Sipwise APT repository
- **Source compilation** - Build from source with custom options
- **Kernel module** - Hardware-accelerated RTP forwarding
- **DTLS/SRTP** - Secure media encryption
- **ICE/ICE-Lite** - NAT traversal support
- **Homer/HEP** - RTP metadata capture
- **Call recording** - Native recording support
- **Transcoding** - Optional codec transcoding (with ffmpeg)

## Requirements

- Debian 12 (Bookworm) on ARM64
- Kernel headers matching running kernel
- External network interface (eth1) for NAT traversal
- Vault authentication configured (for production credentials)

## Architecture

```
                External Network (Internet)
                         │
                         │ eth1 (external_ip)
                         ▼
    ┌────────────────────────────────────────┐
    │           RTPEngine (media-1)          │
    │                                        │
    │  ┌──────────────────────────────────┐  │
    │  │       Kernel Module              │  │
    │  │    (xt_RTPENGINE/iptables)       │  │
    │  └──────────────────────────────────┘  │
    │                                        │
    │  Ports: 10000-20000/UDP (RTP/SRTP)     │
    │  Control: 192.168.64.20:2223 (NG)      │
    │                                        │
    └────────────────────┬───────────────────┘
                         │ eth0 (internal_ip)
                         │
                         ▼
                Internal Network (192.168.64.0/24)
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    OpenSIPS         Asterisk          Homer
    (sip-1)          (pbx-1)         (devstack)
```

## Why No Docker?

RTPEngine requires kernel module (`xt_RTPENGINE`) for:
- High-performance packet forwarding in kernel space
- NAT traversal with connection tracking
- Direct iptables integration

Docker's network namespace isolation prevents proper kernel module operation. Therefore, RTPEngine must be installed natively.

## Installation Methods

### Package Installation (Default)

Uses Sipwise APT repository with DKMS for kernel module:

```yaml
rtpengine_install_method: package
```

### Source Compilation

Builds from GitHub with custom options:

```yaml
rtpengine_install_method: source
rtpengine_version: "mr12.0"
```

## Role Variables

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_enabled` | `true` | Enable RTPEngine deployment |
| `rtpengine_install_method` | `package` | Installation method: `package` or `source` |
| `rtpengine_version` | `mr12.0` | Version for source builds |

### Network Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_listen_ng` | `192.168.64.20:2223` | NG protocol listen address |
| `rtpengine_listen_cli` | `127.0.0.1:9900` | CLI interface address |
| `rtpengine_port_min` | `10000` | Minimum RTP port |
| `rtpengine_port_max` | `20000` | Maximum RTP port |
| `rtpengine_interface_internal` | `192.168.64.20` | Internal interface IP |
| `rtpengine_interface_external` | `""` | External interface IP (if available) |

### Protocol Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_dtls_enabled` | `true` | Enable DTLS-SRTP |
| `rtpengine_ice_enabled` | `true` | Enable ICE support |
| `rtpengine_ice_lite` | `true` | Use ICE-Lite mode |
| `rtpengine_transcode_enabled` | `false` | Enable transcoding |

### Kernel Module

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_kernel_module` | `true` | Load kernel module |
| `rtpengine_kernel_table` | `0` | Kernel forwarding table ID |

### Recording

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_recording_enabled` | `false` | Enable recording |
| `rtpengine_recording_dir` | `/var/spool/rtpengine` | Recording directory |
| `rtpengine_recording_format` | `wav` | Recording format |

### Homer/HEP Integration

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_homer_enabled` | `true` | Enable HEP export |
| `rtpengine_homer_host` | `192.168.64.1` | Homer server |
| `rtpengine_homer_port` | `9060` | Homer HEP port |
| `rtpengine_homer_id` | `2002` | HEP capture ID |

### Performance Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_max_sessions` | `0` | Maximum sessions (0=unlimited) |
| `rtpengine_timeout` | `60` | Call timeout (seconds) |
| `rtpengine_silent_timeout` | `30` | Silent timeout |
| `rtpengine_final_timeout` | `10800` | Final timeout (3 hours) |

### Service Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `rtpengine_user` | `rtpengine` | Service user |
| `rtpengine_group` | `rtpengine` | Service group |
| `rtpengine_config_dir` | `/etc/rtpengine` | Config directory |
| `rtpengine_log_level` | `6` | Log level (syslog) |

## Templates

| Template | Purpose |
|----------|---------|
| `rtpengine.conf.j2` | Main configuration file |
| `rtpengine.service.j2` | Systemd service unit (optional override) |

## Dependencies

- `common` - Base system setup
- `vault-client` - Vault integration (optional)

## Usage

### Basic Usage

```yaml
- hosts: media_servers
  roles:
    - role: rtpengine
```

### With External Interface

```yaml
- hosts: media_servers
  roles:
    - role: rtpengine
      vars:
        rtpengine_interface_internal: "192.168.64.20"
        rtpengine_interface_external: "203.0.113.20"
```

### With Recording

```yaml
- hosts: media_servers
  roles:
    - role: rtpengine
      vars:
        rtpengine_recording_enabled: true
        rtpengine_recording_dir: "/mnt/recordings"
```

## Directory Structure

```
/etc/rtpengine/
└── rtpengine.conf        # Main configuration

/var/run/rtpengine/
└── rtpengine.pid         # PID file

/var/spool/rtpengine/     # Recording directory (if enabled)

/var/log/
└── rtpengine.log         # Log file (via syslog)
```

## Handlers

| Handler | Description |
|---------|-------------|
| `restart rtpengine` | Restart RTPEngine service |
| `reload kernel module` | Reload xt_RTPENGINE module |

## Testing

### Check Service Status

```bash
ssh voip@192.168.64.20 'systemctl status rtpengine'
```

### Check Kernel Module

```bash
# Verify module is loaded
ssh voip@192.168.64.20 'lsmod | grep xt_RTPENGINE'

# Check iptables rules
ssh voip@192.168.64.20 'sudo iptables -L -n -v | grep RTPENGINE'

# Check kernel table
ssh voip@192.168.64.20 'cat /proc/rtpengine/0/list'
```

### Check Listening Ports

```bash
# NG protocol port
ssh voip@192.168.64.20 'ss -nlup | grep 2223'

# CLI port
ssh voip@192.168.64.20 'ss -nltp | grep 9900'

# RTP port range (when active)
ssh voip@192.168.64.20 'ss -nlup | grep -E "1[0-9]{4}"'
```

### CLI Commands

```bash
# List active sessions
ssh voip@192.168.64.20 'rtpengine-ctl list'

# Show statistics
ssh voip@192.168.64.20 'rtpengine-ctl stats'

# Show version
ssh voip@192.168.64.20 'rtpengine-ctl version'
```

### Test NG Protocol

```bash
# Send a ping command
ssh voip@192.168.64.20 'echo "d1:1i0e1:2s4:ping" | nc -u 192.168.64.20 2223'
```

## Troubleshooting

### Service Won't Start

```bash
# Check service logs
ssh voip@192.168.64.20 'journalctl -u rtpengine -f'

# Check configuration
ssh voip@192.168.64.20 'rtpengine --config-test'
```

### Kernel Module Issues

```bash
# Check if module exists
ssh voip@192.168.64.20 'find /lib/modules -name "xt_RTPENGINE*"'

# Check DKMS status
ssh voip@192.168.64.20 'dkms status'

# Rebuild module if needed
ssh voip@192.168.64.20 'sudo dkms autoinstall'

# Manual module load
ssh voip@192.168.64.20 'sudo modprobe xt_RTPENGINE'
```

### No RTP Traffic

```bash
# Check iptables RTPENGINE target
ssh voip@192.168.64.20 'sudo iptables -t raw -L -n'

# Check if forwarding table is active
ssh voip@192.168.64.20 'cat /proc/rtpengine/control'

# Check interface configuration
ssh voip@192.168.64.20 'rtpengine-ctl list interfaces'
```

### Media Not Relayed

```bash
# Enable debug logging temporarily
ssh voip@192.168.64.20 'sudo sed -i "s/log-level=.*/log-level=7/" /etc/rtpengine/rtpengine.conf'
ssh voip@192.168.64.20 'sudo systemctl restart rtpengine'

# Watch logs
ssh voip@192.168.64.20 'journalctl -u rtpengine -f'
```

### OpenSIPS Integration Issues

```bash
# Test connectivity from OpenSIPS
ssh voip@192.168.64.10 'nc -u -z 192.168.64.20 2223 && echo "NG OK"'

# Check OpenSIPS rtpengine module
ssh voip@192.168.64.10 'docker exec opensips opensips-cli -x mi rtpengine_show'
```

## Integration with OpenSIPS

OpenSIPS communicates with RTPEngine via NG protocol:

```
# OpenSIPS config (opensips.cfg)
modparam("rtpengine", "rtpengine_sock", "udp:192.168.64.20:2223")

# Usage in routing
rtpengine_manage("replace-origin replace-session-connection ICE=remove");
```

**Common rtpengine_manage flags:**
- `replace-origin` - Rewrite SDP origin
- `replace-session-connection` - Rewrite connection address
- `ICE=remove` - Strip ICE candidates
- `RTP/SAVP` - Force SRTP
- `DTLS=passive` - DTLS passive mode

## Performance Considerations

### Kernel Module Benefits

With kernel module loaded:
- RTP packets forwarded in kernel space
- Minimal userspace processing
- Handles 1000s of concurrent streams
- Sub-millisecond latency

Without kernel module (fallback):
- All packets processed in userspace
- Higher CPU usage
- Limited scalability

### Tuning

```yaml
# For high-volume deployments
rtpengine_max_sessions: 5000
rtpengine_port_min: 10000
rtpengine_port_max: 60000

# Adjust timeouts for your use case
rtpengine_timeout: 120
rtpengine_silent_timeout: 60
```

## Security

- NG protocol listens only on internal network
- CLI binds to localhost only
- DTLS/SRTP encryption supported
- No external management ports exposed

## References

- [RTPEngine GitHub](https://github.com/sipwise/rtpengine)
- [RTPEngine Documentation](https://github.com/sipwise/rtpengine/blob/master/docs/README.md)
- [OpenSIPS RTPEngine Module](https://www.opensips.org/Documentation/Modules-3-5#toc79)
- [voip-stack Architecture](../../docs/ARCHITECTURE.md)

## Changelog

### 2024-12 Updates
- Documented kernel module requirements
- Added comprehensive troubleshooting guide
- Added Homer/HEP integration settings
- Added performance tuning section

## Phase

Phase 1 - Media Relay
