#!/bin/bash
# voip-stack VM Setup and Verification Script
#
# This script performs a complete setup of the voip-stack VMs:
#   1. Verifies prerequisites
#   2. Starts socket_vmnet (requires sudo)
#   3. Starts devstack-core (Vault)
#   4. Initializes VM credentials in Vault
#   5. Creates VMs with Vault-managed credentials
#   6. Starts VMs and waits for them to be ready
#   7. Verifies SSH connectivity and security configuration
#
# Usage:
#   ./setup.sh              # Full setup
#   ./setup.sh --check      # Verify existing setup only
#   ./setup.sh --help       # Show help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVSTACK_DIR="$HOME/devstack-core"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Status indicators
PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"
INFO="${BLUE}→${NC}"

log_info() { echo -e "${INFO} $1"; }
log_pass() { echo -e "${PASS} $1"; }
log_fail() { echo -e "${FAIL} $1"; }
log_warn() { echo -e "${WARN} $1"; }

# Track overall status
ERRORS=0

# VM definitions
VM_DEFS=(
    "sip-1:192.168.64.10"
    "pbx-1:192.168.64.30"
    "media-1:192.168.64.20"
)

# ============================================================================
# Prerequisites Check
# ============================================================================

check_prerequisites() {
    echo ""
    echo "========================================"
    echo "  Step 1: Checking Prerequisites"
    echo "========================================"
    echo ""

    local all_good=true

    # Required commands
    local commands=("virsh" "qemu-img" "mkisofs" "curl" "jq" "openssl" "nc")
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_pass "$cmd is installed"
        else
            log_fail "$cmd is NOT installed"
            all_good=false
        fi
    done

    # SSH key
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        log_pass "SSH key found: ~/.ssh/id_ed25519.pub"
    elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        log_pass "SSH key found: ~/.ssh/id_rsa.pub"
    else
        log_fail "No SSH public key found"
        echo "      Run: ssh-keygen -t ed25519"
        all_good=false
    fi

    # QEMU firmware
    if [ -f "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" ]; then
        log_pass "QEMU UEFI firmware found"
    else
        log_fail "QEMU UEFI firmware not found"
        echo "      Run: brew reinstall qemu"
        all_good=false
    fi

    # socket_vmnet
    if [ -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
        log_pass "socket_vmnet is running"
    else
        log_warn "socket_vmnet is not running"
        echo "      Will attempt to start it..."
    fi

    # devstack-core directory
    if [ -d "$DEVSTACK_DIR" ]; then
        log_pass "devstack-core found at $DEVSTACK_DIR"
    else
        log_fail "devstack-core not found at $DEVSTACK_DIR"
        all_good=false
    fi

    if ! $all_good; then
        echo ""
        log_fail "Prerequisites check failed. Please install missing components."
        return 1
    fi

    echo ""
    log_pass "All prerequisites satisfied"
    return 0
}

# ============================================================================
# socket_vmnet
# ============================================================================

ensure_socket_vmnet() {
    echo ""
    echo "========================================"
    echo "  Step 2: Ensuring socket_vmnet"
    echo "========================================"
    echo ""

    if [ -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
        log_pass "socket_vmnet is already running"
        return 0
    fi

    log_info "Starting socket_vmnet (requires sudo)..."
    sudo brew services start socket_vmnet

    # Wait for socket
    local retries=10
    while [ $retries -gt 0 ]; do
        if [ -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
            log_pass "socket_vmnet started successfully"
            return 0
        fi
        sleep 1
        retries=$((retries - 1))
    done

    log_fail "Failed to start socket_vmnet"
    return 1
}

# ============================================================================
# devstack-core / Vault
# ============================================================================

ensure_vault() {
    echo ""
    echo "========================================"
    echo "  Step 3: Ensuring Vault is Running"
    echo "========================================"
    echo ""

    # Check if Vault is already running
    local health
    health=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || true

    if [ "$health" = "200" ] || [ "$health" = "429" ]; then
        log_pass "Vault is already running and healthy"
        return 0
    fi

    log_info "Starting devstack-core..."

    # Start devstack-core
    # Note: devstack may return non-zero even if Vault starts successfully
    # (e.g., if other services fail to start). We check Vault health separately.
    if [ -f "$DEVSTACK_DIR/devstack" ]; then
        "$DEVSTACK_DIR/devstack" start || log_warn "devstack returned an error (checking Vault anyway...)"
    else
        log_fail "devstack script not found"
        return 1
    fi

    # Wait for Vault to be ready (regardless of devstack exit code)
    log_info "Waiting for Vault to be ready..."
    local retries=30
    while [ $retries -gt 0 ]; do
        health=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || true
        if [ "$health" = "200" ] || [ "$health" = "429" ]; then
            log_pass "Vault is running and healthy"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
        echo -n "."
    done
    echo ""

    log_fail "Vault did not become healthy in time"
    return 1
}

# ============================================================================
# Vault Credentials
# ============================================================================

ensure_vault_credentials() {
    echo ""
    echo "========================================"
    echo "  Step 4: Ensuring Vault Credentials"
    echo "========================================"
    echo ""

    local bootstrap_script="$SCRIPT_DIR/scripts/vault-bootstrap-vm-credentials.sh"

    if [ ! -f "$bootstrap_script" ]; then
        log_fail "Bootstrap script not found: $bootstrap_script"
        return 1
    fi

    # Check if credentials already exist
    if "$bootstrap_script" show >/dev/null 2>&1; then
        log_pass "VM credentials already exist in Vault"

        # Show the path (not the password)
        echo "      Path: secret/voip-stack/vms/debian-user"
        return 0
    fi

    log_info "Generating new VM credentials..."
    if "$bootstrap_script" generate; then
        log_pass "VM credentials created in Vault"
        return 0
    else
        log_fail "Failed to create VM credentials"
        return 1
    fi
}

# ============================================================================
# VM Creation
# ============================================================================

ensure_vms_created() {
    echo ""
    echo "========================================"
    echo "  Step 5: Ensuring VMs are Created"
    echo "========================================"
    echo ""

    local all_defined=true

    # Check if all VMs are defined
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        if virsh -c qemu:///session list --all --name 2>/dev/null | grep -q "^${vm}$"; then
            log_pass "VM $vm is defined"
        else
            log_info "VM $vm is not defined"
            all_defined=false
        fi
    done

    if $all_defined; then
        log_pass "All VMs are already defined"
        return 0
    fi

    log_info "Creating VMs..."
    echo ""

    # Run create-vms.sh
    if (cd "$SCRIPT_DIR" && ./create-vms.sh create); then
        log_pass "VMs created successfully"
        return 0
    else
        log_fail "Failed to create VMs"
        return 1
    fi
}

# ============================================================================
# VM Startup
# ============================================================================

ensure_vms_running() {
    echo ""
    echo "========================================"
    echo "  Step 6: Ensuring VMs are Running"
    echo "========================================"
    echo ""

    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        local state
        state=$(virsh -c qemu:///session domstate "$vm" 2>/dev/null || echo "undefined")

        if [ "$state" = "running" ]; then
            log_pass "$vm is already running"
        elif [ "$state" = "shut off" ]; then
            log_info "Starting $vm..."
            if virsh -c qemu:///session start "$vm" >/dev/null 2>&1; then
                log_pass "$vm started"
            else
                log_fail "Failed to start $vm"
                ERRORS=$((ERRORS + 1))
            fi
        else
            log_fail "$vm is in unexpected state: $state"
            ERRORS=$((ERRORS + 1))
        fi
    done

    return 0
}

# ============================================================================
# Wait for VMs
# ============================================================================

wait_for_vms() {
    echo ""
    echo "========================================"
    echo "  Step 7: Waiting for VMs to be Ready"
    echo "========================================"
    echo ""

    log_info "Waiting for VMs to be SSH-reachable (timeout: 120s)..."

    local timeout=120
    local start_time=$(date +%s)

    while [ $(($(date +%s) - start_time)) -lt $timeout ]; do
        local all_ready=true

        for def in "${VM_DEFS[@]}"; do
            local ip="${def##*:}"
            if ! nc -z -w 2 "$ip" 22 2>/dev/null; then
                all_ready=false
                break
            fi
        done

        if $all_ready; then
            echo ""
            log_pass "All VMs are SSH-reachable"
            return 0
        fi

        echo -n "."
        sleep 5
    done

    echo ""
    log_warn "Some VMs may not be fully ready"
    return 0
}

# ============================================================================
# Verification
# ============================================================================

verify_setup() {
    echo ""
    echo "========================================"
    echo "  Step 8: Verifying Setup"
    echo "========================================"
    echo ""

    local verification_errors=0

    # Check each VM
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        local ip="${def##*:}"

        echo ""
        echo "--- $vm ($ip) ---"

        # Check SSH connectivity
        if nc -z -w 5 "$ip" 22 2>/dev/null; then
            log_pass "SSH port reachable"
        else
            log_fail "SSH port NOT reachable"
            verification_errors=$((verification_errors + 1))
            continue
        fi

        # Check SSH key authentication
        if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
            voip@"$ip" "echo 'SSH key auth working'" 2>/dev/null | grep -q "working"; then
            log_pass "SSH key authentication working"
        else
            log_fail "SSH key authentication FAILED"
            verification_errors=$((verification_errors + 1))
            continue
        fi

        # Check SSH password auth is disabled
        local sshd_config
        sshd_config=$(ssh -o BatchMode=yes -o ConnectTimeout=10 \
            voip@"$ip" "grep -E '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null" 2>/dev/null || echo "")

        if echo "$sshd_config" | grep -q "PasswordAuthentication no"; then
            log_pass "SSH password authentication disabled"
        else
            log_warn "SSH password authentication may not be disabled"
        fi

        # Check hostname
        local hostname
        hostname=$(ssh -o BatchMode=yes -o ConnectTimeout=10 \
            voip@"$ip" "hostname" 2>/dev/null || echo "unknown")

        if [ "$hostname" = "$vm" ]; then
            log_pass "Hostname correctly set to $vm"
        else
            log_warn "Hostname is '$hostname' (expected '$vm')"
        fi

        # Check IP address
        local actual_ip
        actual_ip=$(ssh -o BatchMode=yes -o ConnectTimeout=10 \
            voip@"$ip" "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'" 2>/dev/null || echo "unknown")

        if [ "$actual_ip" = "$ip" ]; then
            log_pass "IP address correctly set to $ip"
        else
            log_warn "IP address is '$actual_ip' (expected '$ip')"
        fi
    done

    echo ""

    if [ $verification_errors -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""
    echo "========================================"
    echo "  Setup Summary"
    echo "========================================"
    echo ""

    if [ $ERRORS -eq 0 ]; then
        log_pass "Setup completed successfully!"
        echo ""
        echo "SECURITY CONFIGURATION:"
        echo "  - SSH: Key-based authentication only"
        echo "  - Console: Password stored in Vault"
        echo ""
        echo "ACCESS:"
        echo "  ssh voip@192.168.64.10  # sip-1"
        echo "  ssh voip@192.168.64.20  # media-1"
        echo "  ssh voip@192.168.64.30  # pbx-1"
        echo ""
        echo "MANAGEMENT:"
        echo "  ./vm-manager.sh status    # Check status"
        echo "  ./vm-manager.sh stop      # Stop VMs"
        echo "  ./vm-manager.sh start     # Start VMs"
        echo ""
        echo "VIEW CONSOLE PASSWORD:"
        echo "  ./scripts/vault-bootstrap-vm-credentials.sh show"
        echo ""
    else
        log_fail "Setup completed with $ERRORS error(s)"
        echo ""
        echo "Please review the errors above and re-run the script."
    fi
}

# ============================================================================
# Check Only Mode
# ============================================================================

check_only() {
    echo ""
    echo "========================================"
    echo "  voip-stack Setup Verification"
    echo "========================================"

    local check_errors=0

    echo ""
    echo "--- Infrastructure ---"

    # socket_vmnet
    if [ -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
        log_pass "socket_vmnet is running"
    else
        log_fail "socket_vmnet is NOT running"
        check_errors=$((check_errors + 1))
    fi

    # Vault
    local health
    health=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || true
    if [ "$health" = "200" ] || [ "$health" = "429" ]; then
        log_pass "Vault is running and healthy"
    else
        log_fail "Vault is NOT running (HTTP $health)"
        check_errors=$((check_errors + 1))
    fi

    # Vault credentials
    if "$SCRIPT_DIR/scripts/vault-bootstrap-vm-credentials.sh" show >/dev/null 2>&1; then
        log_pass "VM credentials exist in Vault"
    else
        log_fail "VM credentials NOT found in Vault"
        check_errors=$((check_errors + 1))
    fi

    echo ""
    echo "--- Virtual Machines ---"

    # VM status
    for def in "${VM_DEFS[@]}"; do
        local vm="${def%%:*}"
        local ip="${def##*:}"
        local state
        state=$(virsh -c qemu:///session domstate "$vm" 2>/dev/null || echo "undefined")

        if [ "$state" = "running" ]; then
            if nc -z -w 2 "$ip" 22 2>/dev/null; then
                log_pass "$vm: running, SSH reachable at $ip"
            else
                log_warn "$vm: running, but SSH not reachable at $ip"
            fi
        elif [ "$state" = "shut off" ]; then
            log_warn "$vm: defined but not running"
        else
            log_fail "$vm: $state"
            check_errors=$((check_errors + 1))
        fi
    done

    echo ""

    if [ $check_errors -eq 0 ]; then
        log_pass "All checks passed"
        return 0
    else
        log_fail "$check_errors check(s) failed"
        return 1
    fi
}

# ============================================================================
# Help
# ============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "voip-stack VM Setup and Verification Script"
    echo ""
    echo "Options:"
    echo "  (none)      Perform full setup"
    echo "  --check     Verify existing setup only (no changes)"
    echo "  --help      Show this help message"
    echo ""
    echo "Full setup performs:"
    echo "  1. Check prerequisites"
    echo "  2. Start socket_vmnet (requires sudo)"
    echo "  3. Start devstack-core/Vault"
    echo "  4. Initialize VM credentials in Vault"
    echo "  5. Create VMs with Vault-managed credentials"
    echo "  6. Start VMs"
    echo "  7. Wait for VMs to be SSH-reachable"
    echo "  8. Verify security configuration"
    echo ""
    echo "Documentation: docs/VM-CREDENTIALS.md"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  voip-stack VM Setup"
    echo "========================================"

    check_prerequisites || exit 1
    ensure_socket_vmnet || exit 1
    ensure_vault || exit 1
    ensure_vault_credentials || exit 1
    ensure_vms_created || exit 1
    ensure_vms_running || exit 1
    wait_for_vms
    verify_setup || ERRORS=$((ERRORS + 1))
    print_summary

    exit $ERRORS
}

# Parse arguments
case "${1:-}" in
    --check)
        check_only
        ;;
    --help|-h)
        show_help
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
