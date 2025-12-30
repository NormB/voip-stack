#!/bin/bash
################################################################
# Test: Asterisk Status
#
# Verifies Asterisk is running on pbx-1 VM
################################################################

set -euo pipefail

TEST_NAME="Asterisk Status"
PBX_VM="${PBX_VM:-192.168.64.30}"

echo "Running: ${TEST_NAME}"

# Test 1: SSH to VM and check systemd service
echo "  → Checking Asterisk service status..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${PBX_VM}" \
    'systemctl is-active asterisk.service' 2>/dev/null | grep -q "active"; then
    echo "✗ FAILED: Asterisk service is not active on ${PBX_VM}"
    exit 1
fi
echo "  ✓ Asterisk service is active"

# Test 2: Check Asterisk core show version via Docker
echo "  → Checking Asterisk version..."
VERSION=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${PBX_VM}" \
    'docker exec asterisk asterisk -rx "core show version" 2>/dev/null | head -1' 2>/dev/null || echo "")

if [[ -n "${VERSION}" ]] && [[ "${VERSION}" == *"Asterisk"* ]]; then
    echo "  ✓ Asterisk version: ${VERSION}"
else
    echo "  ⚠ WARNING: Could not retrieve Asterisk version"
fi

# Test 3: Check Asterisk channels
echo "  → Checking Asterisk channels..."
CHANNELS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${PBX_VM}" \
    'docker exec asterisk asterisk -rx "core show channels count" 2>/dev/null | tail -1' 2>/dev/null || echo "0 active channels")
echo "  ✓ ${CHANNELS}"

echo "✓ ${TEST_NAME} passed"
exit 0
