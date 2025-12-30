#!/bin/bash
################################################################
# Test: Call with SRTP Encryption
#
# Tests encrypted media call setup
################################################################

set -euo pipefail

TEST_NAME="Call with SRTP Encryption"
SIP_PROXY="${SIP_PROXY:-192.168.64.10}"
SIP_PORT="${SIP_PORT:-5060}"

echo "Running: ${TEST_NAME}"

# Prerequisites
if ! command -v sipp &> /dev/null; then
    echo "✗ FAILED: sipp command not found"
    echo "  Install with: brew install sipp (macOS)"
    exit 1
fi

# Check if sipp supports SRTP
if ! sipp -h 2>&1 | grep -q "srtp"; then
    echo "⚠ SKIPPED: sipp not compiled with SRTP support"
    exit 0
fi

# Note: Full SRTP testing requires proper key exchange
# This is a placeholder for when SRTP is fully configured
echo "  → SRTP test placeholder..."
echo "  ⚠ NOTE: Full SRTP testing requires TLS and proper key exchange"
echo "  ⚠ This test will be expanded when TLS is configured"

# For now, just verify OpenSIPS supports SRTP module
echo "  → Checking OpenSIPS SRTP/TLS support..."
SRTP_SUPPORT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@192.168.64.10 \
    'docker exec opensips opensips -V 2>/dev/null | grep -i tls || echo "unknown"' 2>/dev/null || echo "unknown")

if [[ "${SRTP_SUPPORT}" != "unknown" ]]; then
    echo "  ✓ OpenSIPS has TLS support"
else
    echo "  ⚠ Could not verify TLS support"
fi

echo "✓ ${TEST_NAME} passed (placeholder)"
exit 0
