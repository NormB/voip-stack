# voip-stack Vagrant Infrastructure

This directory contains Vagrant configuration for creating and managing voip-stack VMs using QEMU on Apple Silicon.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     macOS Host (Apple Silicon)                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  DevStack Core (Docker)                   │   │
│  │  Vault:8200  PostgreSQL:5432  Redis:6379  RabbitMQ:5672  │   │
│  │                    192.168.64.1                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│      ┌───────────────────────┼───────────────────────┐          │
│      │                       │                       │          │
│  ┌───▼───┐               ┌───▼───┐               ┌───▼───┐      │
│  │ sip-1 │               │media-1│               │ pbx-1 │      │
│  │ .10   │               │ .20   │               │ .30   │      │
│  │2GB/2C │               │4GB/4C │               │4GB/2C │      │
│  └───────┘               └───────┘               └───────┘      │
│  OpenSIPS                RTPEngine               Asterisk       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              vagrant-qemu (QEMU + HVF)                    │   │
│  │              192.168.64.0/24 private network              │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Install QEMU and Vagrant

```bash
# Install QEMU
brew install qemu

# Install Vagrant
brew install --cask vagrant

# Install vagrant-qemu plugin
vagrant plugin install vagrant-qemu
```

### 2. Verify Installation

```bash
# Check QEMU
qemu-system-aarch64 --version

# Check Vagrant
vagrant --version

# Check plugin
vagrant plugin list | grep qemu
```

## Quick Start

### 1. Start VMs

```bash
cd ~/voip-stack/vagrant

# Start all VMs
vagrant up

# Or start specific VM
vagrant up sip-1
```

### 2. SSH Access

```bash
# Via Vagrant
vagrant ssh sip-1
vagrant ssh media-1
vagrant ssh pbx-1

# Or directly (after VMs are up)
ssh vagrant@192.168.64.10  # sip-1
ssh vagrant@192.168.64.20  # media-1
ssh vagrant@192.168.64.30  # pbx-1
```

### 3. Run Ansible Provisioning

```bash
# Via Vagrant (recommended)
vagrant provision

# Or directly with Ansible
cd ~/voip-stack
./scripts/ansible-run.sh provision-vms -i ansible/inventory/vagrant.yml
```

## VM Specifications

| VM | Role | IP Address | RAM | CPU | Description |
|----|------|------------|-----|-----|-------------|
| sip-1 | SIP Proxy | 192.168.64.10 | 2GB | 2 | OpenSIPS/Kamailio |
| media-1 | Media Proxy | 192.168.64.20 | 4GB | 4 | RTPEngine |
| pbx-1 | PBX | 192.168.64.30 | 4GB | 2 | Asterisk/FreeSWITCH |

## Commands Reference

### Vagrant Commands

```bash
# Lifecycle
vagrant up              # Create and start all VMs
vagrant up sip-1        # Start specific VM
vagrant halt            # Stop all VMs gracefully
vagrant halt sip-1      # Stop specific VM
vagrant destroy -f      # Destroy all VMs
vagrant reload          # Restart VMs

# Provisioning
vagrant provision              # Run Ansible on all VMs
vagrant provision sip-1        # Provision specific VM
ANSIBLE_VERBOSE=1 vagrant provision  # Verbose Ansible output

# SSH
vagrant ssh sip-1       # SSH into VM
vagrant ssh-config      # Show SSH configuration

# Status
vagrant status          # Show VM status
vagrant global-status   # Show all Vagrant VMs on system

# Snapshots
vagrant snapshot push   # Create snapshot of all VMs
vagrant snapshot pop    # Restore last snapshot
vagrant snapshot list   # List snapshots
vagrant snapshot save sip-1 baseline  # Named snapshot
vagrant snapshot restore sip-1 baseline
```

### Debug Mode

```bash
# Enable QEMU serial console output
VAGRANT_DEBUG=1 vagrant up

# Enable verbose Ansible output
ANSIBLE_VERBOSE=1 vagrant provision

# Both
VAGRANT_DEBUG=1 ANSIBLE_VERBOSE=1 vagrant up --provision
```

## Networking

### Private Network (192.168.64.0/24)

- **sip-1**: 192.168.64.10
- **media-1**: 192.168.64.20
- **pbx-1**: 192.168.64.30
- **Mac Host**: 192.168.64.1 (gateway, DevStack Core)

### Connectivity

VMs can reach:
- Each other via 192.168.64.x
- DevStack Core services at 192.168.64.1
- Internet via NAT (QEMU user-mode networking)

### Port Access

| Service | VM | Port | Access |
|---------|-----|------|--------|
| OpenSIPS SIP | sip-1 | 5060/UDP | 192.168.64.10:5060 |
| OpenSIPS TLS | sip-1 | 5061/TCP | 192.168.64.10:5061 |
| Asterisk SIP | pbx-1 | 5080/UDP | 192.168.64.30:5080 |
| RTPEngine | media-1 | 10000-20000/UDP | 192.168.64.20:10000-20000 |

## Integration with DevStack Core

### Prerequisites

Ensure DevStack Core is running before provisioning VMs:

```bash
cd ~/devstack-core
./devstack start
./devstack status
```

### Verify Connectivity

From a VM, verify DevStack Core access:

```bash
vagrant ssh sip-1

# Test Vault
curl -s http://192.168.64.1:8200/v1/sys/health | jq

# Test PostgreSQL
nc -zv 192.168.64.1 5432

# Test Redis
nc -zv 192.168.64.1 6379
```

## Troubleshooting

### VM Won't Start

```bash
# Check QEMU is installed
which qemu-system-aarch64

# Check vagrant-qemu plugin
vagrant plugin list

# Try with debug output
VAGRANT_LOG=debug vagrant up sip-1
```

### Network Connectivity Issues

```bash
# Check VM is running
vagrant status

# Check IP configuration inside VM
vagrant ssh sip-1 -c "ip addr show"

# Ping gateway
vagrant ssh sip-1 -c "ping -c 3 192.168.64.1"
```

### Ansible Provisioning Fails

```bash
# Run with verbose output
ANSIBLE_VERBOSE=1 vagrant provision

# Check SSH connectivity
vagrant ssh-config > ssh.config
ssh -F ssh.config sip-1 "echo OK"

# Run Ansible directly
cd ~/voip-stack
ansible -i ansible/inventory/vagrant.yml all -m ping
```

### Slow VM Performance

```bash
# Verify HVF acceleration is enabled
vagrant ssh sip-1 -c "dmesg | grep -i hypervisor"

# Check CPU info
vagrant ssh sip-1 -c "lscpu"
```

## Migration from libvirt

If you previously used the libvirt setup:

```bash
# 1. Stop and remove libvirt VMs
cd ~/voip-stack/libvirt
./create-vms.sh destroy

# 2. Undefine VMs from libvirt
virsh -c qemu:///session undefine sip-1
virsh -c qemu:///session undefine pbx-1
virsh -c qemu:///session undefine media-1

# 3. Start Vagrant VMs
cd ~/voip-stack/vagrant
vagrant up
```

## Directory Structure

```
vagrant/
├── Vagrantfile          # VM definitions and configuration
└── README.md            # This file

ansible/inventory/
└── vagrant.yml          # Ansible inventory for Vagrant VMs
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VAGRANT_DEBUG` | Enable QEMU serial console | unset |
| `ANSIBLE_VERBOSE` | Enable verbose Ansible output | unset |
| `VAGRANT_LOG` | Vagrant log level (debug, info, warn, error) | unset |

## Known Limitations

1. **Port Forwarding**: vagrant-qemu has limited port forwarding support. Use private_network IPs directly instead.

2. **Synced Folders**: SMB synced folders require additional configuration. Ansible is recommended for file transfers.

3. **Multiple Networks**: Unlike libvirt, vagrant-qemu doesn't support bridged networking as easily. All VMs use private_network.

4. **Box Compatibility**: Some Vagrant boxes may have boot issues with vagrant-qemu on Apple Silicon. The `generic/debian12` ARM64 box is recommended but may require extended boot timeouts.

## Known Issues

### SSH Timeout During Boot

If VMs show "timeout during server version negotiating" or "Connection reset by peer", the VM may be:
- Still booting (can take 5-10 minutes on first boot)
- Using an incompatible box (ensure ARM64 architecture)

**Solutions:**
1. Increase boot timeout in Vagrantfile (currently set to 1200s)
2. Try a different ARM64-compatible box
3. Verify QEMU supports HVF: `qemu-system-aarch64 -accel help`

### Alternative Approaches

If vagrant-qemu proves unreliable, consider:

1. **VirtualBox 7.1+**: Now supports Apple Silicon (as of September 2024)
   ```bash
   brew install --cask virtualbox
   vagrant up --provider=virtualbox
   ```

2. **UTM with vagrant-utm**: Native macOS virtualization
   - Install UTM from App Store
   - `vagrant plugin install vagrant_utm`

3. **Lima/Colima**: Lightweight alternative with QEMU backend
   ```bash
   brew install colima
   colima start --vm-type=qemu --arch=aarch64
   ```

## References

- [vagrant-qemu GitHub](https://github.com/ppggff/vagrant-qemu)
- [Vagrant Documentation](https://developer.hashicorp.com/vagrant/docs)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [voip-stack Documentation](../docs/README.md)
