#!/bin/bash
# Bootstrap VM credentials in Vault
# This script creates the voip user password in Vault for VM console access
#
# Prerequisites:
#   - Vault must be running (devstack-core)
#   - VAULT_ADDR and VAULT_TOKEN must be set, or root token file must exist
#
# Usage:
#   ./vault-bootstrap-vm-credentials.sh [generate|show|rotate]
#
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

# Vault configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
# Logical path (for display)
VAULT_SECRET_PATH="secret/voip-stack/vms/voip-user"
# API path (KV v2 requires /data/ prefix after mount point)
VAULT_SECRET_API_PATH="secret/data/voip-stack/vms/voip-user"
ROOT_TOKEN_FILE="$HOME/.config/vault/root-token"

# Get Vault token
get_vault_token() {
    if [ -n "${VAULT_TOKEN:-}" ]; then
        echo "$VAULT_TOKEN"
        return
    fi

    if [ -f "$ROOT_TOKEN_FILE" ]; then
        cat "$ROOT_TOKEN_FILE"
        return
    fi

    log_error "No Vault token found. Set VAULT_TOKEN or ensure $ROOT_TOKEN_FILE exists"
    exit 1
}

# Check Vault connectivity
check_vault() {
    log_info "Checking Vault connectivity at $VAULT_ADDR..."

    local health
    health=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo "000")

    case "$health" in
        200)
            log_info "Vault is initialized, unsealed, and active"
            return 0
            ;;
        429)
            log_info "Vault is unsealed and in standby mode"
            return 0
            ;;
        472)
            log_error "Vault is in recovery mode"
            return 1
            ;;
        473)
            log_error "Vault is in performance standby mode"
            return 1
            ;;
        501)
            log_error "Vault is not initialized"
            return 1
            ;;
        503)
            log_error "Vault is sealed"
            return 1
            ;;
        *)
            log_error "Cannot connect to Vault at $VAULT_ADDR (HTTP $health)"
            log_error "Ensure devstack-core is running: cd ~/devstack-core && ./devstack up"
            return 1
            ;;
    esac
}

# Generate a secure random password
generate_password() {
    # Generate 24 character password with letters, numbers, and safe special chars
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#%^&*()_+-=' | head -c 24
}

# Store password in Vault
store_password() {
    local password=$1
    local token
    token=$(get_vault_token)

    log_info "Storing credentials at $VAULT_SECRET_PATH..."

    # Store in Vault KV v2 (API path requires /data/ after mount point)
    local response
    response=$(curl -s -X POST \
        -H "X-Vault-Token: $token" \
        -H "Content-Type: application/json" \
        -d "{\"data\": {\"password\": \"$password\", \"username\": \"voip\", \"description\": \"VM console access only - SSH uses key authentication\"}}" \
        "$VAULT_ADDR/v1/$VAULT_SECRET_API_PATH" 2>&1)

    if echo "$response" | grep -q '"errors"'; then
        log_error "Failed to store credentials in Vault"
        echo "$response" | jq -r '.errors[]' 2>/dev/null || echo "$response"
        return 1
    fi

    log_info "Credentials stored successfully"
}

# Get password from Vault
get_password() {
    local token
    token=$(get_vault_token)

    # Read from Vault KV v2 (API path requires /data/ after mount point)
    local response
    response=$(curl -s \
        -H "X-Vault-Token: $token" \
        "$VAULT_ADDR/v1/$VAULT_SECRET_API_PATH" 2>&1)

    if echo "$response" | grep -q '"errors"'; then
        return 1
    fi

    # KV v2 returns data nested: .data.data.password
    echo "$response" | jq -r '.data.data.password' 2>/dev/null
}

# Check if password exists
password_exists() {
    local password
    password=$(get_password 2>/dev/null)
    [ -n "$password" ] && [ "$password" != "null" ]
}

# Generate and store new password
cmd_generate() {
    check_vault || exit 1

    if password_exists; then
        log_warn "Password already exists in Vault"
        read -p "Overwrite existing password? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing password"
            return
        fi
    fi

    local password
    password=$(generate_password)

    store_password "$password" || exit 1

    echo ""
    log_info "Generated new password for voip user"
    log_info "Password stored at: $VAULT_SECRET_PATH"
    echo ""
    echo "To view the password:"
    echo "  $0 show"
    echo ""
    echo "IMPORTANT: This password is for VM console access only."
    echo "           SSH access uses your ~/.ssh key (no password)."
}

# Show current password
cmd_show() {
    check_vault || exit 1

    local password
    password=$(get_password)

    if [ -z "$password" ] || [ "$password" = "null" ]; then
        log_error "No password found in Vault"
        log_info "Run '$0 generate' to create one"
        exit 1
    fi

    echo ""
    log_info "Vault path: $VAULT_SECRET_PATH"
    echo ""
    echo "Username: voip"
    echo "Password: $password"
    echo ""
    log_warn "This password is for VM console access only"
    log_info "SSH access uses your ~/.ssh key (password disabled)"
}

# Rotate password
cmd_rotate() {
    check_vault || exit 1

    if ! password_exists; then
        log_error "No existing password to rotate"
        log_info "Run '$0 generate' to create one"
        exit 1
    fi

    local password
    password=$(generate_password)

    store_password "$password" || exit 1

    echo ""
    log_info "Password rotated successfully"
    log_warn "IMPORTANT: You must recreate VMs for the new password to take effect"
    echo ""
    echo "To recreate VMs:"
    echo "  cd ~/voip-stack/libvirt"
    echo "  ./create-vms.sh destroy"
    echo "  ./create-vms.sh create"
}

# Show help
cmd_help() {
    echo "Usage: $0 {generate|show|rotate|help}"
    echo ""
    echo "Manage VM voip user credentials in Vault"
    echo ""
    echo "Commands:"
    echo "  generate  Generate and store a new password in Vault"
    echo "  show      Display the current password from Vault"
    echo "  rotate    Generate a new password (requires VM recreation)"
    echo "  help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  VAULT_ADDR   Vault server address (default: http://localhost:8200)"
    echo "  VAULT_TOKEN  Vault authentication token"
    echo ""
    echo "The password is stored at: $VAULT_SECRET_PATH"
    echo ""
    echo "Security notes:"
    echo "  - This password is for VM CONSOLE access only (emergency use)"
    echo "  - SSH access uses your ~/.ssh public key (password auth disabled)"
    echo "  - The password is fetched from Vault during VM creation"
}

# Main
case "${1:-help}" in
    generate)
        cmd_generate
        ;;
    show)
        cmd_show
        ;;
    rotate)
        cmd_rotate
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
