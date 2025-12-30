# Archived Files

This directory contains legacy implementations that have been superseded.

## libvirt-legacy/

**Archived**: 2025-12-30
**Replaced by**: Lima (`scripts/lima-vms.sh`)

The libvirt implementation was the original VM infrastructure using:
- libvirt/QEMU with socket_vmnet for networking
- Cloud-init for VM initialization
- Manual virsh commands for VM management

### Why Archived

1. **EFI Firmware Issues**: Required OVMF firmware that needed manual installation
2. **Complex Setup**: socket_vmnet required sudo privileges and daemon configuration
3. **Limited Portability**: Tight coupling to macOS-specific paths and configurations

### Current Approach

Use Lima for Debian VMs on Apple Silicon:
```bash
./scripts/lima-vms.sh create
./scripts/lima-vms.sh status
```
