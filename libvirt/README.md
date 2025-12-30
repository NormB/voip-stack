# voip-stack libvirt/QEMU VM Infrastructure

This directory contains scripts and configurations for creating and managing voip-stack VMs using libvirt/QEMU on macOS with Apple Silicon.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     macOS Host (Apple Silicon)                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              socket_vmnet (rootless networking)           │   │
│  │  ┌────────────────────┐  ┌────────────────────────────┐  │   │
│  │  │ vmnet.shared       │  │ vmnet.bridged (optional)   │  │   │
│  │  │ 192.168.64.0/24    │  │ via en0 to LAN             │  │   │
│  │  │ GW: 192.168.64.1   │  │                            │  │   │
│  │  └────────────────────┘  └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│      ┌───────────────────────┼───────────────────────┐          │
│      │                       │                       │          │
│  ┌───▼───┐               ┌───▼───┐               ┌───▼───┐      │
│  │ sip-1 │               │ pbx-1 │               │media-1│      │
│  │ .10   │               │ .30   │               │ .20   │      │
│  │2GB/2C │               │4GB/2C │               │4GB/4C │      │
│  │eth0+1 │               │eth0   │               │eth0+1 │      │
│  └───────┘               └───────┘               └───────┘      │
│  OpenSIPS                Asterisk                RTPEngine      │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- macOS on Apple Silicon (M1/M2/M3/M4)
- Homebrew installed
- libvirt: `brew install libvirt`
- QEMU: `brew install qemu`
- socket_vmnet: `brew install socket_vmnet`

## Quick Start

### 1. Install socket_vmnet networking (one-time, requires sudo)

```bash
# Run the setup script to install networking services
sudo ./setup-socket-vmnet.sh

# Verify sockets are created
ls -la /opt/homebrew/var/run/socket_vmnet*
```

### 2. Create VMs

```bash
# Create all VMs (downloads Debian image, creates disks, defines VMs)
./create-vms.sh create

# Or just check prerequisites
./create-vms.sh status
```

### 3. Start VMs

```bash
# Start all VMs
./create-vms.sh start

# Or start individually
virsh -c qemu:///session start sip-1
virsh -c qemu:///session start pbx-1
virsh -c qemu:///session start media-1
```

### 4. Connect to VMs

```bash
# Wait 30-60 seconds for VMs to boot and cloud-init to complete
ssh voip@192.168.64.10  # sip-1
ssh voip@192.168.64.30  # pbx-1
ssh voip@192.168.64.20  # media-1
```

## VM Specifications

| VM | Role | IP Address | RAM | CPU | Network |
|----|------|------------|-----|-----|---------|
| sip-1 | SIP Proxy (OpenSIPS) | 192.168.64.10 | 2GB | 2 | eth0 + eth1 |
| pbx-1 | PBX (Asterisk) | 192.168.64.30 | 4GB | 2 | eth0 only |
| media-1 | Media Proxy (RTPEngine) | 192.168.64.20 | 4GB | 4 | eth0 + eth1 |

**Note:** pbx-1 intentionally has NO eth1 (external interface) for security isolation.

## Directory Structure

```
libvirt/
├── README.md                    # This file
├── setup-socket-vmnet.sh        # Networking setup (requires sudo)
├── create-vms.sh                # Main VM management script
├── socket_vmnet-shared.plist    # Shared network config
├── socket_vmnet-bridged.plist   # Bridged network config
├── domains/                     # VM XML definitions
│   ├── sip-1.xml
│   ├── pbx-1.xml
│   └── media-1.xml
├── cloud-init/                  # Cloud-init configurations
│   ├── user-data.yaml.tpl       # User/package template
│   ├── meta-data.yaml.tpl       # Instance metadata template
│   ├── network-config-sip-1.yaml
│   ├── network-config-pbx-1.yaml
│   └── network-config-media-1.yaml
├── images/                      # Disk images (created by script)
│   ├── debian-12-generic-arm64.qcow2  # Base image
│   ├── sip-1.qcow2              # sip-1 disk
│   ├── pbx-1.qcow2              # pbx-1 disk
│   ├── media-1.qcow2            # media-1 disk
│   └── *-cidata.iso             # Cloud-init ISOs
└── networks/                    # Network definitions (unused with socket_vmnet)
```

## Commands

### create-vms.sh

```bash
./create-vms.sh create   # Download image, create disks, define VMs
./create-vms.sh start    # Start all VMs
./create-vms.sh stop     # Gracefully shutdown all VMs
./create-vms.sh destroy  # Destroy VMs and delete disks
./create-vms.sh status   # Show VM status
```

### virsh commands

```bash
# List VMs
virsh -c qemu:///session list --all

# Start/stop individual VM
virsh -c qemu:///session start sip-1
virsh -c qemu:///session shutdown sip-1
virsh -c qemu:///session destroy sip-1  # Force stop

# Console access (Ctrl+] to exit)
virsh -c qemu:///session console sip-1

# Redefine VM after XML changes
virsh -c qemu:///session define domains/sip-1.xml
```

## Networking

### Shared Network (vmnet-shared)
- Network: 192.168.64.0/24
- Gateway: 192.168.64.1 (host)
- DHCP: 192.168.64.2 - 192.168.64.254
- VMs use static IPs via cloud-init

### Bridged Network (vmnet-bridged)
- Direct connection to LAN via en0
- VMs get IPs from your router's DHCP
- Used for eth1 on sip-1 and media-1

## Troubleshooting

### socket_vmnet not working

```bash
# Check if services are running
sudo launchctl list | grep socket_vmnet

# Restart services
sudo launchctl unload /Library/LaunchDaemons/com.socket_vmnet.shared.plist
sudo launchctl load /Library/LaunchDaemons/com.socket_vmnet.shared.plist

# Check socket exists
ls -la /opt/homebrew/var/run/socket_vmnet*
```

### VM won't start

```bash
# Check for errors
virsh -c qemu:///session start sip-1 --console

# Check domain XML
virsh -c qemu:///session dumpxml sip-1

# Verify disk exists
ls -la images/sip-1.qcow2
```

### Can't SSH to VM

```bash
# Wait for cloud-init (60-90 seconds after boot)
# Check VM is running
virsh -c qemu:///session list

# Check your SSH key is in cloud-init
grep -A2 "ssh_authorized_keys" cloud-init/user-data.yaml.tpl

# Try ping first
ping 192.168.64.10
```

### VM IP not accessible

```bash
# Verify shared network socket exists
ls /opt/homebrew/var/run/socket_vmnet.shared

# Check host can reach gateway
ping 192.168.64.1

# If still failing, restart socket_vmnet
sudo launchctl kickstart -k system/com.socket_vmnet.shared
```

## Technical Notes

### Why socket_vmnet?
macOS's vmnet.framework requires root access. socket_vmnet is a daemon that provides vmnet access via a Unix socket, enabling rootless QEMU networking.

### Why not standard libvirt networks?
libvirt's network drivers don't support vmnet.framework. We use QEMU's `-netdev stream` with socket_vmnet instead of libvirt network definitions.

### HVF Acceleration
VMs use Apple's Hypervisor.framework (HVF) for near-native performance. This is configured via `<qemu:arg value='-accel'/><qemu:arg value='hvf'/>` in domain XML.

### Cloud-init
VMs are initialized using cloud-init with:
- Debian user with sudo access
- Your SSH public key (~/.ssh/id_ed25519.pub or id_rsa.pub)
- Static IP configuration
- Essential packages (qemu-guest-agent, vim, curl, htop, etc.)

## Integration with voip-stack

After VMs are created, use Ansible to provision VoIP components:

```bash
cd ~/voip-stack

# Provision all components (VMs have static IPs from cloud-init)
./scripts/ansible-run.sh provision-vms

# Or provision specific components
./scripts/ansible-run.sh provision-vms --limit sip_proxies --tags opensips
./scripts/ansible-run.sh provision-vms --limit pbx --tags asterisk
./scripts/ansible-run.sh provision-vms --limit media --tags rtpengine
```
