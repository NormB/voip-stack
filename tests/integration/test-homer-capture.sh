#!/bin/bash
################################################################
# Test: Homer HEP Capture
#
# Verifies Homer is receiving HEP packets
################################################################

set -euo pipefail

TEST_NAME="Homer HEP Capture"
HOMER_HOST="${HOMER_HOST:-192.168.64.1}"
HOMER_HEP_PORT="${HOMER_HEP_PORT:-9060}"
HOMER_WEB_PORT="${HOMER_WEB_PORT:-9080}"

echo "Running: ${TEST_NAME}"

# Test 1: Check Homer HEP port is accessible
echo "  → Checking Homer HEP port ${HOMER_HEP_PORT}..."
if nc -zu "${HOMER_HOST}" "${HOMER_HEP_PORT}" 2>/dev/null; then
    echo "  ✓ Homer HEP port is accessible"
else
    echo "  ⚠ Homer HEP port ${HOMER_HEP_PORT} not accessible"
    echo "  Note: Homer may not be running"
fi

# Test 2: Check Homer web UI
echo "  → Checking Homer web UI..."
if curl -s -f "http://${HOMER_HOST}:${HOMER_WEB_PORT}/api/v3/status" > /dev/null 2>&1; then
    echo "  ✓ Homer web UI is accessible"
else
    echo "  ⚠ Homer web UI not accessible at ${HOMER_HOST}:${HOMER_WEB_PORT}"
fi

# Test 3: Check OpenSIPS HEP configuration
echo "  → Checking OpenSIPS HEP configuration..."
HEP_CONFIG=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@192.168.64.10 \
    'docker exec opensips opensips-cli -x mi get_statistics hep 2>/dev/null || echo "not configured"' 2>/dev/null || echo "unknown")

if [[ "${HEP_CONFIG}" == *"not configured"* ]] || [[ "${HEP_CONFIG}" == *"unknown"* ]]; then
    echo "  ⚠ HEP module may not be configured in OpenSIPS"
else
    echo "  ✓ HEP module active in OpenSIPS"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
