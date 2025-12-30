#!/bin/bash
# Create voip-stack VMs using libvirt/QEMU
# This script creates all VMs from scratch using Debian cloud images
#
# Security: VM credentials are managed via HashiCorp Vault
#   - Password: Fetched from Vault (for console access only)
#   - SSH: Key-based authentication only (password auth disabled)
#
# See: docs/VM-CREDENTIALS.md for full documentation
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"
DOMAINS_DIR="$SCRIPT_DIR/domains"
CLOUD_INIT_DIR="$SCRIPT_DIR/cloud-init"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Debian 12 cloud image URL (ARM64)
DEBIAN_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
DEBIAN_IMAGE_NAME="debian-12-generic-arm64.qcow2"

# Vault configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
# Logical path (for display)
VAULT_SECRET_PATH="secret/voip-stack/vms/voip-user"
# API path (KV v2 requires /data/ prefix after mount point)
VAULT_SECRET_API_PATH="secret/data/voip-stack/vms/voip-user"
ROOT_TOKEN_FILE="$HOME/.config/vault/root-token"

# VM definitions: name:ram_gb:cpu:has_eth1
VMS=(
    "sip-1:2:2:yes"
    "pbx-1:4:2:no"
    "media-1:4:4:yes"
)

# Force mode: skip interactive prompts (set via --force flag or FORCE_MODE=1)
FORCE_MODE="${FORCE_MODE:-0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get Vault token
get_vault_token() {
    if [ -n "${VAULT_TOKEN:-}" ]; then
        echo "$VAULT_TOKEN"
        return 0
    fi

    if [ -f "$ROOT_TOKEN_FILE" ]; then
        cat "$ROOT_TOKEN_FILE"
        return 0
    fi

    return 1
}

# Check if Vault is available and has credentials
check_vault() {
    # Check connectivity
    local health
    health=$(curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" 2>/dev/null) || true

    if [ "$health" != "200" ] && [ "$health" != "429" ]; then
        return 1
    fi

    # Check for token
    local token
    token=$(get_vault_token 2>/dev/null) || return 1

    # Check if secret exists (use API path for KV v2)
    local response
    response=$(curl -s -H "X-Vault-Token: $token" "$VAULT_ADDR/v1/$VAULT_SECRET_API_PATH" 2>/dev/null)

    if echo "$response" | grep -q '"errors"'; then
        return 1
    fi

    return 0
}

# Get password from Vault
get_vault_password() {
    local token
    token=$(get_vault_token) || return 1

    # Read from KV v2 (use API path)
    local response
    response=$(curl -s -H "X-Vault-Token: $token" "$VAULT_ADDR/v1/$VAULT_SECRET_API_PATH" 2>/dev/null)

    # KV v2 returns data nested: .data.data.password
    local password
    password=$(echo "$response" | jq -r '.data.data.password' 2>/dev/null)

    if [ -z "$password" ] || [ "$password" = "null" ]; then
        return 1
    fi

    echo "$password"
}

# Generate SHA-512 password hash for cloud-init
# Uses openssl to generate a proper crypt(3) compatible hash
generate_password_hash() {
    local password=$1
    local salt
    salt=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

    # Generate SHA-512 hash using openssl
    # Format: $6$rounds=4096$salt$hash
    openssl passwd -6 -salt "$salt" "$password"
}

# Get SSH public key
get_ssh_key() {
    local key_file="$HOME/.ssh/id_ed25519.pub"
    if [ ! -f "$key_file" ]; then
        key_file="$HOME/.ssh/id_rsa.pub"
    fi
    if [ ! -f "$key_file" ]; then
        log_error "No SSH public key found. Please run: ssh-keygen -t ed25519"
        exit 1
    fi
    cat "$key_file"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=()

    # Check for required tools
    command -v virsh >/dev/null 2>&1 || missing+=("virsh (brew install libvirt)")
    command -v qemu-img >/dev/null 2>&1 || missing+=("qemu-img (brew install qemu)")
    command -v mkisofs >/dev/null 2>&1 || command -v hdiutil >/dev/null 2>&1 || missing+=("mkisofs or hdiutil")

    # Check for QEMU firmware
    if [ ! -f "/opt/homebrew/share/qemu/edk2-aarch64-code.fd" ]; then
        missing+=("QEMU UEFI firmware (reinstall qemu)")
    fi

    # Check for socket_vmnet sockets
    if [ ! -S "/opt/homebrew/var/run/socket_vmnet.shared" ]; then
        log_warn "socket_vmnet.shared not found. Run: sudo $SCRIPT_DIR/setup-socket-vmnet.sh"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing prerequisites:"
        for item in "${missing[@]}"; do
            echo "  - $item"
        done
        exit 1
    fi

    log_info "All prerequisites satisfied"
}

# Download Debian cloud image
download_image() {
    mkdir -p "$IMAGES_DIR"

    if [ -f "$IMAGES_DIR/$DEBIAN_IMAGE_NAME" ]; then
        log_info "Debian cloud image already exists"
        return
    fi

    log_info "Downloading Debian 12 cloud image (ARM64)..."
    log_info "URL: $DEBIAN_IMAGE_URL"
    curl -L -o "$IMAGES_DIR/$DEBIAN_IMAGE_NAME" "$DEBIAN_IMAGE_URL"
    log_info "Download complete"
}

# Create cloud-init ISO for a VM
# Arguments: vm_name ssh_key password_hash
create_cloud_init_iso() {
    local vm_name=$1
    local ssh_key=$2
    local password_hash=$3
    local temp_dir=$(mktemp -d)

    log_info "Creating cloud-init ISO for $vm_name..."

    # Create meta-data
    cat > "$temp_dir/meta-data" << EOF
instance-id: $vm_name
local-hostname: $vm_name
EOF

    # Create user-data
    # SECURITY:
    #   - ssh_pwauth: false - Disables SSH password authentication (key-only)
    #   - Password is for console access only (emergency use)
    #   - Password hash is fetched from Vault at VM creation time
    cat > "$temp_dir/user-data" << EOF
#cloud-config
hostname: $vm_name
fqdn: $vm_name.local
manage_etc_hosts: true

users:
  - name: voip
    gecos: VoIP Stack User
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: $password_hash
    ssh_authorized_keys:
      - $ssh_key

# SECURITY: Disable SSH password authentication
# SSH access requires key-based authentication only
# Password is for VM console access (emergency use only)
ssh_pwauth: false

packages:
  - qemu-guest-agent
  - vim
  - curl
  - wget
  - net-tools
  - dnsutils
  - htop
  - sudo

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  # Ensure SSH password auth is disabled (belt and suspenders)
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - echo "$vm_name cloud-init complete" > /var/log/cloud-init-done

final_message: "Cloud-init complete for $vm_name"
EOF

    # Copy network config if exists
    if [ -f "$CLOUD_INIT_DIR/network-config-$vm_name.yaml" ]; then
        cp "$CLOUD_INIT_DIR/network-config-$vm_name.yaml" "$temp_dir/network-config"
    fi

    # Create ISO using mkisofs (requires: brew install cdrtools)
    # IMPORTANT: Volume label MUST be "cidata" for cloud-init NoCloud datasource
    local iso_path="$IMAGES_DIR/$vm_name-cidata.iso"
    mkisofs -output "$iso_path" -volid cidata -joliet -rock "$temp_dir" 2>/dev/null

    rm -rf "$temp_dir"
    log_info "Created: $iso_path"
}

# Create VM disk from base image
create_vm_disk() {
    local vm_name=$1
    local disk_size=${2:-50G}
    local disk_path="$IMAGES_DIR/$vm_name.qcow2"

    if [ -f "$disk_path" ]; then
        if [ "$FORCE_MODE" = "1" ]; then
            log_info "Force mode: removing existing disk $disk_path"
            rm -f "$disk_path"
        else
            log_warn "Disk already exists: $disk_path"
            read -p "Delete and recreate? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f "$disk_path"
            else
                return
            fi
        fi
    fi

    log_info "Creating disk for $vm_name ($disk_size)..."
    qemu-img create -f qcow2 -b "$IMAGES_DIR/$DEBIAN_IMAGE_NAME" -F qcow2 "$disk_path" "$disk_size"
    log_info "Created: $disk_path"
}

# Define VM in libvirt
define_vm() {
    local vm_name=$1
    local domain_file="$DOMAINS_DIR/$vm_name.xml"

    if [ ! -f "$domain_file" ]; then
        log_error "Domain file not found: $domain_file"
        return 1
    fi

    # Check if VM already exists
    if virsh -c qemu:///session list --all --name | grep -q "^${vm_name}$"; then
        if [ "$FORCE_MODE" = "1" ]; then
            log_info "Force mode: undefining existing VM $vm_name"
            virsh -c qemu:///session destroy "$vm_name" 2>/dev/null || true
            virsh -c qemu:///session undefine "$vm_name" 2>/dev/null || true
        else
            log_warn "VM $vm_name already defined"
            read -p "Undefine and recreate? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                virsh -c qemu:///session destroy "$vm_name" 2>/dev/null || true
                virsh -c qemu:///session undefine "$vm_name" 2>/dev/null || true
            else
                return
            fi
        fi
    fi

    log_info "Defining VM: $vm_name"
    virsh -c qemu:///session define "$domain_file"
}

# Start VM
start_vm() {
    local vm_name=$1

    log_info "Starting VM: $vm_name"
    virsh -c qemu:///session start "$vm_name"
}

# Main
main() {
    echo "========================================"
    echo "  voip-stack VM Creator (libvirt/QEMU)"
    echo "========================================"
    echo ""

    check_prerequisites

    # Get SSH key
    local ssh_key
    ssh_key=$(get_ssh_key)
    log_info "Using SSH key: ${ssh_key:0:50}..."

    # Get password from Vault
    local password=""
    local password_hash=""

    log_info "Checking Vault for VM credentials..."
    if check_vault; then
        password=$(get_vault_password)
        if [ -n "$password" ]; then
            log_info "Retrieved debian user password from Vault"
            password_hash=$(generate_password_hash "$password")
        fi
    fi

    if [ -z "$password_hash" ]; then
        log_warn "Vault not available or credentials not found"
        echo ""
        echo "To use Vault-managed credentials:"
        echo "  1. Start devstack-core: cd ~/devstack-core && ./devstack up"
        echo "  2. Initialize credentials: $SCRIPTS_DIR/vault-bootstrap-vm-credentials.sh generate"
        echo "  3. Re-run this script"
        echo ""
        read -p "Continue without Vault (use a temporary password)? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Aborted. Please configure Vault first."
            exit 1
        fi

        # Generate a temporary password for non-Vault setup
        log_warn "Generating temporary password (NOT stored in Vault)"
        password=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        password_hash=$(generate_password_hash "$password")
        echo ""
        log_warn "Temporary console password: $password"
        log_warn "This password is NOT stored anywhere - save it now if needed!"
        echo ""
    fi

    # Download base image
    download_image

    # Create VMs - parallelize when in force mode
    if [ "$FORCE_MODE" = "1" ]; then
        log_info "Creating VMs in parallel (force mode)..."

        # Phase 1: Create cloud-init ISOs in parallel (I/O bound, no prompts)
        log_info "Phase 1/3: Creating cloud-init ISOs..."
        for vm_def in "${VMS[@]}"; do
            IFS=':' read -r vm_name ram_gb cpu has_eth1 <<< "$vm_def"
            create_cloud_init_iso "$vm_name" "$ssh_key" "$password_hash" &
        done
        wait
        log_info "All cloud-init ISOs created"

        # Phase 2: Create disks in parallel (copy-on-write, fast)
        log_info "Phase 2/3: Creating VM disks..."
        for vm_def in "${VMS[@]}"; do
            IFS=':' read -r vm_name ram_gb cpu has_eth1 <<< "$vm_def"
            create_vm_disk "$vm_name" "50G" &
        done
        wait
        log_info "All VM disks created"

        # Phase 3: Define VMs (sequential for virsh stability)
        log_info "Phase 3/3: Defining VMs..."
        for vm_def in "${VMS[@]}"; do
            IFS=':' read -r vm_name ram_gb cpu has_eth1 <<< "$vm_def"
            define_vm "$vm_name"
        done
    else
        # Sequential mode (interactive prompts require it)
        for vm_def in "${VMS[@]}"; do
            IFS=':' read -r vm_name ram_gb cpu has_eth1 <<< "$vm_def"

            echo ""
            echo "----------------------------------------"
            log_info "Creating VM: $vm_name (${ram_gb}GB RAM, ${cpu} CPU)"
            echo "----------------------------------------"

            # Create disk
            create_vm_disk "$vm_name" "50G"

            # Create cloud-init ISO with password hash
            create_cloud_init_iso "$vm_name" "$ssh_key" "$password_hash"

            # Define VM
            define_vm "$vm_name"
        done
    fi

    echo ""
    echo "========================================"
    log_info "All VMs created successfully!"
    echo "========================================"
    echo ""
    echo "SECURITY CONFIGURATION:"
    echo "  - SSH: Key-based authentication only (password disabled)"
    echo "  - Console: Password from Vault (for emergency access)"
    echo ""
    echo "To start VMs:"
    echo "  ./vm-manager.sh start"
    echo ""
    echo "To check status:"
    echo "  ./vm-manager.sh status"
    echo ""
    echo "To SSH (after VMs boot):"
    echo "  ssh voip@192.168.64.10  # sip-1"
    echo "  ssh voip@192.168.64.30  # pbx-1"
    echo "  ssh voip@192.168.64.20  # media-1"
    echo ""
    echo "To view console password:"
    echo "  $SCRIPTS_DIR/vault-bootstrap-vm-credentials.sh show"
}

# Parse command line arguments
ACTION="${1:-create}"
shift || true

# Check for --force flag
for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE_MODE=1
            ;;
    esac
done

case "$ACTION" in
    create)
        main
        ;;
    start)
        for vm in sip-1 pbx-1 media-1; do
            virsh -c qemu:///session start "$vm" 2>/dev/null || log_warn "$vm already running or not defined"
        done
        ;;
    stop)
        for vm in sip-1 pbx-1 media-1; do
            virsh -c qemu:///session shutdown "$vm" 2>/dev/null || log_warn "$vm not running"
        done
        ;;
    destroy)
        for vm in sip-1 pbx-1 media-1; do
            virsh -c qemu:///session destroy "$vm" 2>/dev/null || true
            virsh -c qemu:///session undefine "$vm" 2>/dev/null || true
        done
        rm -f "$IMAGES_DIR"/{sip-1,pbx-1,media-1}.qcow2
        rm -f "$IMAGES_DIR"/*-cidata.iso
        log_info "All VMs destroyed"
        ;;
    status)
        virsh -c qemu:///session list --all
        ;;
    *)
        echo "Usage: $0 {create|start|stop|destroy|status} [--force]"
        echo ""
        echo "Options:"
        echo "  --force, -f    Skip interactive prompts (auto-recreate existing resources)"
        exit 1
        ;;
esac
