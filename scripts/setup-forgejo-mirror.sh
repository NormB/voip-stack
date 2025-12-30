#!/bin/bash
################################################################################
# Forgejo Mirror Setup Script
################################################################################
# This script helps create mirror repositories in Forgejo for faster builds.
#
# Usage:
#   ./scripts/setup-forgejo-mirror.sh opensips
#   ./scripts/setup-forgejo-mirror.sh asterisk
#   ./scripts/setup-forgejo-mirror.sh rtpengine
#
# Prerequisites:
#   - devstack-core running with Forgejo (port 3000)
#   - Forgejo user account created
#   - Forgejo access token (stored in Vault or provided interactively)
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Forgejo configuration
FORGEJO_URL="${FORGEJO_URL:-http://localhost:3000}"
FORGEJO_API="${FORGEJO_URL}/api/v1"

# Repository mappings
declare -A REPO_SOURCES=(
    ["opensips"]="https://github.com/OpenSIPS/opensips.git"
    ["asterisk"]="https://github.com/asterisk/asterisk.git"
    ["rtpengine"]="https://github.com/sipwise/rtpengine.git"
    ["kamailio"]="https://github.com/kamailio/kamailio.git"
    ["freeswitch"]="https://github.com/signalwire/freeswitch.git"
)

usage() {
    echo "Usage: $0 <project>"
    echo ""
    echo "Available projects:"
    for key in "${!REPO_SOURCES[@]}"; do
        echo "  - $key"
    done
    echo ""
    echo "Environment variables:"
    echo "  FORGEJO_URL    Forgejo base URL (default: http://localhost:3000)"
    echo "  FORGEJO_TOKEN  Forgejo access token (or provide interactively)"
    exit 1
}

check_forgejo() {
    log_info "Checking Forgejo availability at ${FORGEJO_URL}..."

    if ! curl -s "${FORGEJO_API}/version" > /dev/null 2>&1; then
        log_error "Forgejo is not available at ${FORGEJO_URL}"
        log_info "Make sure devstack-core is running: cd ~/devstack-core && ./devstack start"
        exit 1
    fi

    local version
    version=$(curl -s "${FORGEJO_API}/version" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','unknown'))" 2>/dev/null || echo "unknown")
    log_success "Forgejo is running (version: ${version})"
}

get_token() {
    if [[ -n "${FORGEJO_TOKEN:-}" ]]; then
        log_info "Using token from FORGEJO_TOKEN environment variable"
        return
    fi

    # Try to get from Vault
    if [[ -f ~/.config/vault/root-token ]]; then
        local vault_token
        vault_token=$(cat ~/.config/vault/root-token)
        FORGEJO_TOKEN=$(curl -s \
            -H "X-Vault-Token: ${vault_token}" \
            "http://localhost:8200/v1/secret/data/forgejo" 2>/dev/null | \
            python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('data',{}).get('api_token',''))" 2>/dev/null || echo "")

        if [[ -n "${FORGEJO_TOKEN}" ]]; then
            log_success "Retrieved Forgejo token from Vault"
            return
        fi
    fi

    echo ""
    log_warn "Forgejo access token not found"
    echo "To create a token:"
    echo "  1. Go to ${FORGEJO_URL}"
    echo "  2. Log in to your account"
    echo "  3. Go to Settings → Applications → Generate New Token"
    echo "  4. Select 'repository' scope"
    echo ""
    echo -n "Enter Forgejo access token (or press Enter to open browser): "
    read -r FORGEJO_TOKEN

    if [[ -z "${FORGEJO_TOKEN}" ]]; then
        log_info "Opening Forgejo in browser..."
        open "${FORGEJO_URL}/user/settings/applications" 2>/dev/null || \
            xdg-open "${FORGEJO_URL}/user/settings/applications" 2>/dev/null || \
            log_warn "Could not open browser. Please visit: ${FORGEJO_URL}/user/settings/applications"
        echo ""
        echo -n "Enter token after creating it: "
        read -r FORGEJO_TOKEN
    fi

    if [[ -z "${FORGEJO_TOKEN}" ]]; then
        log_error "No token provided"
        exit 1
    fi
}

check_repo_exists() {
    local repo_name=$1
    local response

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token ${FORGEJO_TOKEN}" \
        "${FORGEJO_API}/repos/${FORGEJO_USER}/${repo_name}")

    [[ "$response" == "200" ]]
}

get_forgejo_user() {
    FORGEJO_USER=$(curl -s \
        -H "Authorization: token ${FORGEJO_TOKEN}" \
        "${FORGEJO_API}/user" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('login',''))" 2>/dev/null || echo "")

    if [[ -z "${FORGEJO_USER}" ]]; then
        log_error "Could not get Forgejo username. Is the token valid?"
        exit 1
    fi

    log_info "Authenticated as: ${FORGEJO_USER}"
}

create_mirror() {
    local project=$1
    local source_url="${REPO_SOURCES[$project]}"

    log_info "Creating mirror for ${project}..."
    log_info "Source: ${source_url}"

    if check_repo_exists "$project"; then
        log_warn "Repository ${FORGEJO_USER}/${project} already exists"
        log_info "Mirror URL: ${FORGEJO_URL}/${FORGEJO_USER}/${project}.git"
        return
    fi

    local response
    response=$(curl -s -X POST \
        -H "Authorization: token ${FORGEJO_TOKEN}" \
        -H "Content-Type: application/json" \
        "${FORGEJO_API}/repos/migrate" \
        -d "{
            \"clone_addr\": \"${source_url}\",
            \"repo_name\": \"${project}\",
            \"mirror\": true,
            \"private\": false,
            \"description\": \"Mirror of ${source_url}\"
        }")

    if echo "$response" | python3 -c "import sys,json; j=json.load(sys.stdin); exit(0 if 'id' in j else 1)" 2>/dev/null; then
        log_success "Mirror created successfully!"
        log_info "Mirror URL: ${FORGEJO_URL}/${FORGEJO_USER}/${project}.git"
        echo ""
        echo "Add this to your Ansible inventory to use the mirror:"
        echo ""
        echo "  ${project}_forgejo_mirror: \"${FORGEJO_URL}/${FORGEJO_USER}/${project}.git\""
    else
        log_error "Failed to create mirror"
        echo "Response: $response"
        exit 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
    fi

    local project=$1

    if [[ -z "${REPO_SOURCES[$project]:-}" ]]; then
        log_error "Unknown project: ${project}"
        usage
    fi

    check_forgejo
    get_token
    get_forgejo_user
    create_mirror "$project"
}

main "$@"
