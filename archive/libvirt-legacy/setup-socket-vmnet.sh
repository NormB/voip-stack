#!/bin/bash
# Setup script for socket_vmnet with voip-stack network configuration
# This script requires sudo to install launchd services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/opt/homebrew/var/log/socket_vmnet"
RUN_DIR="/opt/homebrew/var/run"

echo "=== voip-stack socket_vmnet Setup ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

# Create log directory
echo "Creating log directory..."
mkdir -p "$LOG_DIR"
chown -R "$(logname):staff" "$LOG_DIR"

# Stop default socket_vmnet if running
echo "Stopping default socket_vmnet service (if running)..."
brew services stop socket_vmnet 2>/dev/null || true

# Install our custom services
echo ""
echo "Installing voip-stack socket_vmnet services..."

# Shared network (192.168.64.0/24)
echo "  - Installing shared network (192.168.64.0/24)..."
cp "$SCRIPT_DIR/socket_vmnet-shared.plist" /Library/LaunchDaemons/com.voipstack.socket_vmnet.shared.plist
chown root:wheel /Library/LaunchDaemons/com.voipstack.socket_vmnet.shared.plist
chmod 644 /Library/LaunchDaemons/com.voipstack.socket_vmnet.shared.plist

# Bridged network
echo "  - Installing bridged network (via en0)..."
cp "$SCRIPT_DIR/socket_vmnet-bridged.plist" /Library/LaunchDaemons/com.voipstack.socket_vmnet.bridged.plist
chown root:wheel /Library/LaunchDaemons/com.voipstack.socket_vmnet.bridged.plist
chmod 644 /Library/LaunchDaemons/com.voipstack.socket_vmnet.bridged.plist

# Load the services
echo ""
echo "Starting socket_vmnet services..."
launchctl load /Library/LaunchDaemons/com.voipstack.socket_vmnet.shared.plist
launchctl load /Library/LaunchDaemons/com.voipstack.socket_vmnet.bridged.plist

# Wait for sockets to be created
echo "Waiting for sockets..."
sleep 2

# Verify sockets exist
echo ""
echo "Verifying socket creation..."
if [ -S "$RUN_DIR/socket_vmnet.shared" ]; then
    echo "  ✓ Shared network socket: $RUN_DIR/socket_vmnet.shared"
else
    echo "  ✗ Shared network socket NOT FOUND"
    echo "    Check logs: $LOG_DIR/shared.stderr"
fi

if [ -S "$RUN_DIR/socket_vmnet.bridged" ]; then
    echo "  ✓ Bridged network socket: $RUN_DIR/socket_vmnet.bridged"
else
    echo "  ✗ Bridged network socket NOT FOUND"
    echo "    Check logs: $LOG_DIR/bridged.stderr"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Network configuration:"
echo "  Shared (eth0):  192.168.64.0/24, gateway 192.168.64.1"
echo "  Bridged (eth1): Uses your local network via en0"
echo ""
echo "Socket paths for QEMU:"
echo "  Shared:  $RUN_DIR/socket_vmnet.shared"
echo "  Bridged: $RUN_DIR/socket_vmnet.bridged"
echo ""
echo "To uninstall:"
echo "  sudo launchctl unload /Library/LaunchDaemons/com.voipstack.socket_vmnet.shared.plist"
echo "  sudo launchctl unload /Library/LaunchDaemons/com.voipstack.socket_vmnet.bridged.plist"
echo "  sudo rm /Library/LaunchDaemons/com.voipstack.socket_vmnet.*.plist"
