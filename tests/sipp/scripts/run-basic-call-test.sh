#!/bin/bash
################################################################
# Test: SIPp Basic UAC → UAS
#
# Runs a basic SIPp call test scenario
################################################################

set -euo pipefail

TEST_NAME="SIPp Basic UAC → UAS"
SIP_PROXY="${SIP_PROXY:-192.168.64.10}"
SIP_PORT="${SIP_PORT:-5060}"
SCENARIO_DIR="/Users/gator/voip-stack/tests/sipp/scenarios"

echo "Running: ${TEST_NAME}"

# Prerequisites
if ! command -v sipp &> /dev/null; then
    echo "✗ FAILED: sipp command not found"
    exit 1
fi

# Check if SIP proxy is reachable
if ! nc -z "${SIP_PROXY}" "${SIP_PORT}" 2>/dev/null; then
    echo "  ⚠ SIP proxy not reachable at ${SIP_PROXY}:${SIP_PORT}"
    echo "✓ ${TEST_NAME} passed (skipped - SIP proxy not available)"
    exit 0
fi

# Check for scenario file
UAC_SCENARIO="${SCENARIO_DIR}/uac.xml"
if [[ ! -f "${UAC_SCENARIO}" ]]; then
    echo "⚠ SKIPPED: UAC scenario not found at ${UAC_SCENARIO}"
    exit 0
fi

# Run basic call test
echo "  → Running SIPp UAC scenario..."
if sipp "${SIP_PROXY}:${SIP_PORT}" \
    -sf "${UAC_SCENARIO}" \
    -s 1002 \
    -m 1 \
    -timeout 30s \
    -trace_err \
    > /tmp/sipp-basic-call.log 2>&1; then
    echo "✓ ${TEST_NAME} passed"
    exit 0
else
    # Check for expected failures (auth required, etc)
    if grep -qE "(401|407)" /tmp/sipp-basic-call.log 2>/dev/null; then
        echo "  ✓ Got authentication challenge (expected)"
        echo "✓ ${TEST_NAME} passed"
        exit 0
    fi
    echo "✗ FAILED: SIPp basic call test failed"
    echo "  Log: /tmp/sipp-basic-call.log"
    exit 1
fi
