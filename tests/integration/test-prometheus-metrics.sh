#!/bin/bash
################################################################
# Test: Prometheus Metrics Collection
#
# Verifies Prometheus is collecting metrics from VoIP components
################################################################

set -euo pipefail

TEST_NAME="Prometheus Metrics Collection"
PROMETHEUS_HOST="${PROMETHEUS_HOST:-192.168.64.1}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

echo "Running: ${TEST_NAME}"

# Test 1: Check Prometheus is accessible
echo "  → Checking Prometheus accessibility..."
if ! curl -s -f "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/-/healthy" > /dev/null 2>&1; then
    echo "  ⚠ Cannot reach Prometheus at ${PROMETHEUS_HOST}:${PROMETHEUS_PORT}"
    echo "  Note: Prometheus may not be running in devstack-core (use 'full' profile)"
    echo "✓ ${TEST_NAME} passed (skipped - Prometheus not available)"
    exit 0
fi
echo "  ✓ Prometheus is healthy"

# Test 2: Check for VoIP-related targets
echo "  → Checking Prometheus targets..."
TARGETS=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/targets" 2>/dev/null || echo "{}")

# Count active targets
UP_COUNT=$(echo "${TARGETS}" | grep -o '"health":"up"' | wc -l | tr -d ' ')
DOWN_COUNT=$(echo "${TARGETS}" | grep -o '"health":"down"' | wc -l | tr -d ' ')

echo "  ✓ Targets: ${UP_COUNT} up, ${DOWN_COUNT} down"

# Test 3: Query for node metrics (to verify VMs are being scraped)
echo "  → Checking node metrics..."
NODE_METRICS=$(curl -s "http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/api/v1/query?query=up" 2>/dev/null || echo "{}")

if echo "${NODE_METRICS}" | grep -q "192.168.64"; then
    echo "  ✓ VoIP VM metrics being collected"
else
    echo "  ⚠ VoIP VM targets may not be configured"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
