#!/bin/bash
# Manage voip-stack VMs (start/stop/status)
# Handles socket_vmnet and all VM lifecycle operations
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# VM definitions: name:ip
VM_DEFS=(
    "sip-1:192.168.64.10"
    "pbx-1:192.168.64.30"
    "media-1:192.168.64.20"
)

# Get VM names
get_vm_names() {
    for def in "${VM_DEFS[@]}"; do
        echo "${def%%:*}"
    done
}

# Get IP for a VM
get_vm_ip() {
    local vm_name=$1
    for def in "${VM_DEFS[@]}"; do
        if [ "${def%%:*}" = "$vm_name" ]; then
            echo "${def##*:}"
            return
        fi
    done
}

# Check if socket_vmnet is running
check_socket_vmnet() {
    if [ -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
        return 0
    fi
    return 1
}

# Start socket_vmnet service
start_socket_vmnet() {
    log_info "Checking socket_vmnet status..."

    if check_socket_vmnet; then
        log_info "socket_vmnet is already running"
        return 0
    fi

    log_info "Starting socket_vmnet (requires sudo)..."
    sudo brew services start socket_vmnet

    # Wait for socket to appear
    local retries=10
    while [ $retries -gt 0 ]; do
        if check_socket_vmnet; then
            log_info "socket_vmnet started successfully"
            return 0
        fi
        sleep 1
        retries=$((retries - 1))
    done

    log_error "Failed to start socket_vmnet"
    return 1
}

# Start a single VM
start_vm() {
    local vm_name=$1
    local state

    state=$(virsh -c qemu:///session domstate "$vm_name" 2>/dev/null || echo "undefined")

    case "$state" in
        "running")
            log_info "$vm_name is already running"
            ;;
        "shut off"|"paused")
            log_info "Starting $vm_name..."
            virsh -c qemu:///session start "$vm_name"
            ;;
        "undefined")
            log_warn "$vm_name is not defined. Run ./create-vms.sh first"
            return 1
            ;;
        *)
            log_warn "$vm_name is in state: $state"
            ;;
    esac
}

# Start all VMs (parallel)
start_all_vms() {
    log_info "Starting VMs in parallel..."

    local pids=()
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        start_vm "$vm" &
        pids+=($!)
    done

    # Wait for all VM starts to complete
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    log_info "All VM start commands completed"
}

# Wait for VMs to be reachable via SSH (parallel checks)
wait_for_vms() {
    log_info "Waiting for VMs to be reachable (timeout: 120s)..."

    local timeout=120
    local start_time=$(date +%s)
    local total_vms=${#VM_DEFS[@]}

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        local ready_count=0

        # Check all VMs (don't break early - check all simultaneously)
        for def in "${VM_DEFS[@]}"; do
            local ip="${def##*:}"
            if nc -z -w 1 "$ip" 22 2>/dev/null; then
                ((ready_count++))
            fi
        done

        if [ "$ready_count" -eq "$total_vms" ]; then
            log_info "All VMs are reachable"
            return 0
        fi

        log_info "Waiting for VMs... ($ready_count/$total_vms ready)"
        sleep 2
    done

    log_warn "Some VMs may not be fully ready yet"
}

# Stop all VMs
stop_all_vms() {
    echo "========================================"
    echo "  voip-stack Shutdown"
    echo "========================================"
    echo ""
    log_info "Stopping VMs gracefully..."
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        local state
        state=$(virsh -c qemu:///session domstate "$vm" 2>/dev/null || echo "undefined")
        if [ "$state" = "running" ]; then
            log_info "Shutting down $vm..."
            virsh -c qemu:///session shutdown "$vm"
        else
            log_info "$vm is not running (state: $state)"
        fi
    done
    log_info "Shutdown signals sent. VMs will stop gracefully."
}

# Show status
show_status() {
    echo ""
    log_info "VM Status:"
    virsh -c qemu:///session list --all
    echo ""
    log_info "Network connectivity:"
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        local ip="${def##*:}"
        if nc -z -w 2 "$ip" 22 2>/dev/null; then
            echo -e "  $vm ($ip): ${GREEN}reachable${NC}"
        else
            echo -e "  $vm ($ip): ${RED}not reachable${NC}"
        fi
    done
}

# Main
main() {
    echo "========================================"
    echo "  voip-stack Startup"
    echo "========================================"
    echo ""

    # Step 1: Ensure socket_vmnet is running
    start_socket_vmnet || exit 1

    # Step 2: Start all VMs
    start_all_vms

    # Step 3: Wait for VMs to be ready (optional, can be skipped with --no-wait)
    if [[ "${1:-}" != "--no-wait" ]]; then
        wait_for_vms
    fi

    # Step 4: Show status
    show_status

    echo ""
    echo "========================================"
    log_info "Startup complete!"
    echo "========================================"
    echo ""
    echo "SSH access:"
    echo "  ssh voip@192.168.64.10  # sip-1"
    echo "  ssh voip@192.168.64.20  # media-1"
    echo "  ssh voip@192.168.64.30  # pbx-1"
}

# Parse command line
case "${1:-}" in
    start)
        main "${2:-}"
        ;;
    stop)
        stop_all_vms
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status} [--no-wait]"
        echo ""
        echo "Commands:"
        echo "  start      Start socket_vmnet and all VMs"
        echo "  stop       Gracefully shutdown all VMs"
        echo "  status     Show current status"
        echo ""
        echo "Options for 'start':"
        echo "  --no-wait  Don't wait for VMs to be SSH-reachable"
        echo ""
        echo "Examples:"
        echo "  $0 start           # Start everything and wait for SSH"
        echo "  $0 start --no-wait # Start without waiting"
        echo "  $0 stop            # Graceful shutdown"
        echo "  $0 status          # Check current state"
        exit 1
        ;;
esac
