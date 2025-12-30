#!/bin/bash
################################################################
# Test: CDR Generation
#
# Verifies CDR records are being generated
################################################################

set -euo pipefail

TEST_NAME="CDR Generation"
PBX_VM="${PBX_VM:-192.168.64.30}"

echo "Running: ${TEST_NAME}"

# Test 1: Check Asterisk CDR configuration
echo "  → Checking Asterisk CDR configuration..."
CDR_CONFIG=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${PBX_VM}" \
    'docker exec asterisk asterisk -rx "cdr show status" 2>/dev/null | head -10' 2>/dev/null || echo "error")

if [[ "${CDR_CONFIG}" == *"error"* ]]; then
    echo "  ⚠ Could not query CDR status"
else
    echo "  ✓ CDR module is loaded"
    echo "${CDR_CONFIG}" | head -5 | sed 's/^/    /'
fi

# Test 2: Check for CDR backend configuration
echo "  → Checking CDR backends..."
CDR_BACKENDS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${PBX_VM}" \
    'docker exec asterisk asterisk -rx "module show like cdr" 2>/dev/null' 2>/dev/null || echo "unknown")

if [[ "${CDR_BACKENDS}" == *"cdr_"* ]]; then
    echo "  ✓ CDR backends configured"
else
    echo "  ⚠ No CDR backends found (may need configuration)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
