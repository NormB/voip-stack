# Archived Files

This directory contains legacy implementations that have been superseded by newer approaches.

## libvirt-legacy/

**Archived**: 2025-12-30
**Replaced by**: `vagrant/` directory with vagrant-qemu

The libvirt implementation was the original VM infrastructure using:
- libvirt/QEMU with socket_vmnet for networking
- Cloud-init for VM initialization
- Manual virsh commands for VM management

### Why Archived

1. **EFI Firmware Issues**: Required OVMF firmware that needed manual installation
2. **Complex Setup**: socket_vmnet required sudo privileges and daemon configuration
3. **Limited Portability**: Tight coupling to macOS-specific paths and configurations

### Migration

The new Vagrant-based approach provides:
- Simpler setup (`vagrant plugin install vagrant-qemu`)
- Declarative infrastructure (Vagrantfile)
- Built-in Ansible provisioner
- Snapshot support
- Better cross-platform compatibility

See `vagrant/README.md` for the new approach.

### Restoring (if needed)

If you need to restore the libvirt setup:

```bash
# Move back to original location
mv archive/libvirt-legacy libvirt

# Install prerequisites
brew install libvirt qemu socket_vmnet

# Follow libvirt/README.md for setup
```
