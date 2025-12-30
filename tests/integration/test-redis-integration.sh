#!/bin/bash
################################################################
# Test: Redis Integration
#
# Verifies Redis connectivity from test host
################################################################

set -euo pipefail

TEST_NAME="Redis Integration"
REDIS_HOST="${REDIS_HOST:-192.168.64.1}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo "Running: ${TEST_NAME}"

# Test 1: Redis is accessible
echo "  → Testing Redis accessibility..."
if ! nc -z "${REDIS_HOST}" "${REDIS_PORT}" 2>/dev/null; then
    echo "✗ FAILED: Cannot reach Redis at ${REDIS_HOST}:${REDIS_PORT}"
    exit 1
fi

# Test 2: Can PING Redis (if redis-cli available)
if command -v redis-cli &> /dev/null; then
    echo "  → Testing Redis PING..."
    if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" PING 2>/dev/null | grep -q "PONG"; then
        echo "  ✓ Redis PING successful"
    else
        echo "  ⚠ WARNING: Redis PING failed (may require authentication)"
    fi
else
    echo "  ⚠ Skipping PING test (redis-cli not installed)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
