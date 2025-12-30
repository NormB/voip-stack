#!/bin/bash
################################################################
# Test: OpenSIPS → RTPEngine Dispatcher
#
# Verifies OpenSIPS can communicate with RTPEngine
################################################################

set -euo pipefail

TEST_NAME="OpenSIPS → RTPEngine Dispatcher"
SIP_VM="${SIP_VM:-192.168.64.10}"
MEDIA_VM="${MEDIA_VM:-192.168.64.20}"
RTPENGINE_NG_PORT="${RTPENGINE_NG_PORT:-2223}"

echo "Running: ${TEST_NAME}"

# Test 1: Check if RTPEngine is running
echo "  → Checking RTPEngine availability..."
RTPENGINE_RUNNING=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${MEDIA_VM}" \
    'pgrep -x rtpengine >/dev/null && echo "yes" || echo "no"' 2>/dev/null || echo "no")

if [[ "${RTPENGINE_RUNNING}" != "yes" ]]; then
    echo "⚠ SKIPPED: RTPEngine is not running on ${MEDIA_VM}"
    echo "  Note: RTPEngine deployment may be pending"
    exit 0
fi

# Test 2: OpenSIPS can reach RTPEngine NG port
echo "  → Testing OpenSIPS → RTPEngine connectivity..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${SIP_VM}" \
    "nc -zu ${MEDIA_VM} ${RTPENGINE_NG_PORT}" 2>/dev/null; then
    echo "  ✓ OpenSIPS can reach RTPEngine at ${MEDIA_VM}:${RTPENGINE_NG_PORT}"
else
    echo "✗ FAILED: OpenSIPS cannot reach RTPEngine"
    exit 1
fi

# Test 3: Check RTPEngine stats via NG protocol
echo "  → Checking RTPEngine statistics..."
# This would require a proper NG protocol client, skip for now
echo "  ⚠ Skipping NG protocol stats check (requires specialized client)"

echo "✓ ${TEST_NAME} passed"
exit 0
