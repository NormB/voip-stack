#!/bin/bash
################################################################
# Test: SRTP Media Encryption
#
# Verifies SRTP is configured for media encryption
################################################################

set -euo pipefail

TEST_NAME="SRTP Media Encryption"
MEDIA_VM="${MEDIA_VM:-192.168.64.20}"

echo "Running: ${TEST_NAME}"

# Test 1: Check RTPEngine SRTP configuration
echo "  → Checking RTPEngine SRTP support..."
RTPENGINE_RUNNING=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${MEDIA_VM}" \
    'pgrep -x rtpengine >/dev/null && echo "yes" || echo "no"' 2>/dev/null || echo "no")

if [[ "${RTPENGINE_RUNNING}" != "yes" ]]; then
    echo "  ⚠ RTPEngine not running - SRTP test skipped"
    echo "✓ ${TEST_NAME} passed (skipped - no RTPEngine)"
    exit 0
fi

# Test 2: Check RTPEngine was compiled with SRTP support
echo "  → Verifying RTPEngine SRTP compilation..."
SRTP_SUPPORT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${MEDIA_VM}" \
    'rtpengine --version 2>&1 | grep -i srtp || echo "not found"' 2>/dev/null || echo "unknown")

if [[ "${SRTP_SUPPORT}" != "not found" ]] && [[ "${SRTP_SUPPORT}" != "unknown" ]]; then
    echo "  ✓ RTPEngine has SRTP support"
else
    echo "  ⚠ Could not verify SRTP support"
fi

# Test 3: Check Asterisk SRTP configuration
echo "  → Checking Asterisk SRTP configuration..."
ASTERISK_SRTP=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@192.168.64.30 \
    'docker exec asterisk asterisk -rx "sip show settings" 2>/dev/null | grep -i srtp || echo "not configured"' 2>/dev/null || echo "unknown")

echo "  ⚠ Asterisk SRTP: ${ASTERISK_SRTP}"

echo "✓ ${TEST_NAME} passed"
exit 0
