#!/bin/bash
################################################################
# Ansible Runner Helper Script
#
# Simplifies running Ansible playbooks with common options
#
# Usage:
#   ./scripts/ansible-run.sh provision-vms
#   ./scripts/ansible-run.sh provision-vms --limit sip_proxies
#   ./scripts/ansible-run.sh provision-vms --tags opensips -v
################################################################

set -euo pipefail

# Configuration
ANSIBLE_DIR="ansible"
PLAYBOOK_DIR="${ANSIBLE_DIR}/playbooks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Usage
usage() {
    echo "Usage: $0 <playbook> [ansible-options]"
    echo ""
    echo "Available playbooks:"
    find "${PLAYBOOK_DIR}" -name "*.yml" -exec basename {} .yml \;
    echo ""
    echo "Examples:"
    echo "  $0 provision-vms"
    echo "  $0 provision-vms --limit sip_proxies"
    echo "  $0 provision-vms --tags opensips"
    echo "  $0 provision-vms --check  # Dry run"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

PLAYBOOK="$1"
shift

PLAYBOOK_PATH="${PLAYBOOK_DIR}/${PLAYBOOK}.yml"

# Check if playbook exists
if [[ ! -f "${PLAYBOOK_PATH}" ]]; then
    echo -e "${RED}✗ Playbook not found: ${PLAYBOOK_PATH}${NC}"
    echo ""
    usage
fi

# Check prerequisites
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}✗ ansible-playbook not found${NC}"
    echo "Install with: brew install ansible"
    exit 1
fi

# Change to ansible directory
cd "${ANSIBLE_DIR}"

# Install requirements if needed
if [[ -f "requirements.yml" ]]; then
    echo -e "${YELLOW}→ Installing Ansible Galaxy requirements...${NC}"
    ansible-galaxy install -r requirements.yml
    echo ""
fi

# Run playbook
echo -e "${GREEN}→ Running playbook: ${PLAYBOOK}${NC}"
echo "  Path: ${PLAYBOOK_PATH}"
echo "  Args: $*"
echo ""

ansible-playbook "playbooks/${PLAYBOOK}.yml" "$@"

echo ""
echo -e "${GREEN}✓ Playbook complete${NC}"
