#!/bin/bash
#######################################
# voip-stack VM Manager
#
# Wrapper script for managing voip-stack VMs via Vagrant
#
# Usage:
#   ./scripts/vm-manager.sh <command> [options]
#
# Commands:
#   start       Start all VMs (or specific VM)
#   stop        Stop all VMs gracefully
#   restart     Restart all VMs
#   destroy     Destroy all VMs
#   status      Show VM status
#   ssh <vm>    SSH into specific VM
#   provision   Run Ansible provisioning
#   snapshot    Create/restore snapshots
#   logs <vm>   Show VM console output
#
# Examples:
#   ./scripts/vm-manager.sh start
#   ./scripts/vm-manager.sh start sip-1
#   ./scripts/vm-manager.sh ssh sip-1
#   ./scripts/vm-manager.sh provision
#   ./scripts/vm-manager.sh snapshot save baseline
#######################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VAGRANT_DIR="${PROJECT_DIR}/vagrant"

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

# Check prerequisites
check_prerequisites() {
    if ! command -v vagrant &> /dev/null; then
        error "Vagrant is not installed. Run: brew install --cask vagrant"
    fi

    if ! command -v qemu-system-aarch64 &> /dev/null; then
        error "QEMU is not installed. Run: brew install qemu"
    fi

    if ! vagrant plugin list | grep -q "vagrant-qemu"; then
        error "vagrant-qemu plugin not installed. Run: vagrant plugin install vagrant-qemu"
    fi
}

# Change to vagrant directory
cd_vagrant() {
    if [[ ! -d "$VAGRANT_DIR" ]]; then
        error "Vagrant directory not found: $VAGRANT_DIR"
    fi
    cd "$VAGRANT_DIR"
}

# Commands
cmd_start() {
    local vm="${1:-}"
    check_prerequisites
    cd_vagrant

    info "Starting VMs..."
    if [[ -n "$vm" ]]; then
        vagrant up "$vm"
    else
        vagrant up
    fi
    success "VMs started"
}

cmd_stop() {
    local vm="${1:-}"
    cd_vagrant

    info "Stopping VMs..."
    if [[ -n "$vm" ]]; then
        vagrant halt "$vm"
    else
        vagrant halt
    fi
    success "VMs stopped"
}

cmd_restart() {
    local vm="${1:-}"
    cd_vagrant

    info "Restarting VMs..."
    if [[ -n "$vm" ]]; then
        vagrant reload "$vm"
    else
        vagrant reload
    fi
    success "VMs restarted"
}

cmd_destroy() {
    cd_vagrant

    warn "This will destroy all VMs and their data!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        vagrant destroy -f
        success "VMs destroyed"
    else
        info "Cancelled"
    fi
}

cmd_status() {
    cd_vagrant

    echo -e "${BLUE}═══ voip-stack VM Status ═══${NC}"
    echo ""
    vagrant status
    echo ""

    # Show IP addresses for running VMs
    if vagrant status | grep -q "running"; then
        echo -e "${BLUE}VM IP Addresses:${NC}"
        echo "  sip-1:   192.168.64.10 (OpenSIPS)"
        echo "  media-1: 192.168.64.20 (RTPEngine)"
        echo "  pbx-1:   192.168.64.30 (Asterisk)"
    fi
}

cmd_ssh() {
    local vm="${1:-}"
    cd_vagrant

    if [[ -z "$vm" ]]; then
        echo "Usage: $0 ssh <vm-name>"
        echo "Available VMs: sip-1, media-1, pbx-1"
        exit 1
    fi

    vagrant ssh "$vm"
}

cmd_provision() {
    local vm="${1:-}"
    cd_vagrant

    info "Running Ansible provisioning..."
    if [[ -n "$vm" ]]; then
        vagrant provision "$vm"
    else
        vagrant provision
    fi
    success "Provisioning complete"
}

cmd_snapshot() {
    local action="${1:-}"
    local name="${2:-}"
    cd_vagrant

    case "$action" in
        save)
            if [[ -z "$name" ]]; then
                name="snapshot-$(date +%Y%m%d-%H%M%S)"
            fi
            info "Creating snapshot: $name"
            vagrant snapshot save "$name"
            success "Snapshot created: $name"
            ;;
        restore)
            if [[ -z "$name" ]]; then
                error "Usage: $0 snapshot restore <name>"
            fi
            info "Restoring snapshot: $name"
            vagrant snapshot restore "$name"
            success "Snapshot restored: $name"
            ;;
        list)
            vagrant snapshot list
            ;;
        delete)
            if [[ -z "$name" ]]; then
                error "Usage: $0 snapshot delete <name>"
            fi
            vagrant snapshot delete "$name"
            success "Snapshot deleted: $name"
            ;;
        push)
            info "Creating quick snapshot..."
            vagrant snapshot push
            success "Quick snapshot created"
            ;;
        pop)
            info "Restoring last quick snapshot..."
            vagrant snapshot pop
            success "Quick snapshot restored"
            ;;
        *)
            echo "Usage: $0 snapshot <save|restore|list|delete|push|pop> [name]"
            exit 1
            ;;
    esac
}

cmd_logs() {
    local vm="${1:-sip-1}"
    cd_vagrant

    info "Note: For real-time logs, use: VAGRANT_DEBUG=1 vagrant up $vm"
    vagrant ssh "$vm" -c "sudo journalctl -f" 2>/dev/null || \
        warn "Could not connect to $vm. Is it running?"
}

cmd_help() {
    cat << 'EOF'
voip-stack VM Manager

Usage: ./scripts/vm-manager.sh <command> [options]

Commands:
  start [vm]          Start all VMs or specific VM
  stop [vm]           Stop all VMs or specific VM gracefully
  restart [vm]        Restart all VMs or specific VM
  destroy             Destroy all VMs (with confirmation)
  status              Show VM status and IP addresses
  ssh <vm>            SSH into specific VM (sip-1, media-1, pbx-1)
  provision [vm]      Run Ansible provisioning
  snapshot <action>   Manage VM snapshots
  logs <vm>           Show VM logs (journalctl)
  help                Show this help message

Snapshot Actions:
  save [name]         Create named snapshot (or auto-named)
  restore <name>      Restore named snapshot
  list                List all snapshots
  delete <name>       Delete named snapshot
  push                Create quick unnamed snapshot
  pop                 Restore last quick snapshot

Examples:
  ./scripts/vm-manager.sh start
  ./scripts/vm-manager.sh start sip-1
  ./scripts/vm-manager.sh ssh sip-1
  ./scripts/vm-manager.sh provision
  ./scripts/vm-manager.sh snapshot save baseline
  ./scripts/vm-manager.sh snapshot restore baseline

Environment Variables:
  VAGRANT_DEBUG=1     Enable QEMU serial console output
  ANSIBLE_VERBOSE=1   Enable verbose Ansible output

EOF
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        start)      cmd_start "$@" ;;
        stop)       cmd_stop "$@" ;;
        restart)    cmd_restart "$@" ;;
        destroy)    cmd_destroy ;;
        status)     cmd_status ;;
        ssh)        cmd_ssh "$@" ;;
        provision)  cmd_provision "$@" ;;
        snapshot)   cmd_snapshot "$@" ;;
        logs)       cmd_logs "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            error "Unknown command: $command. Use 'help' for usage."
            ;;
    esac
}

main "$@"
