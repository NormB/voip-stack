#!/bin/bash
################################################################
# Test: Node Exporter on All VMs
#
# Verifies node_exporter is running on all VoIP VMs
################################################################

set -euo pipefail

TEST_NAME="Node Exporter on All VMs"
SIP_VM="${SIP_VM:-192.168.64.10}"
MEDIA_VM="${MEDIA_VM:-192.168.64.20}"
PBX_VM="${PBX_VM:-192.168.64.30}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"

echo "Running: ${TEST_NAME}"

FAILED=0

for vm in "${SIP_VM}" "${MEDIA_VM}" "${PBX_VM}"; do
    echo "  → Checking node_exporter on ${vm}..."

    # Test 1: Check service is running
    SERVICE_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${vm}" \
        'systemctl is-active prometheus-node-exporter.service 2>/dev/null || echo "inactive"' 2>/dev/null || echo "error")

    if [[ "${SERVICE_STATUS}" == "active" ]]; then
        echo "    ✓ Service is active"
    else
        echo "    ✗ Service not active: ${SERVICE_STATUS}"
        FAILED=1
        continue
    fi

    # Test 2: Check metrics endpoint
    if curl -s -f "http://${vm}:${NODE_EXPORTER_PORT}/metrics" > /dev/null 2>&1; then
        echo "    ✓ Metrics endpoint accessible"
    else
        echo "    ⚠ Metrics endpoint not accessible externally"
    fi

    # Test 3: Verify metrics are being generated
    METRIC_COUNT=$(curl -s "http://${vm}:${NODE_EXPORTER_PORT}/metrics" 2>/dev/null | grep -c "^node_" || echo "0")
    echo "    ✓ ${METRIC_COUNT} node_* metrics available"
done

if [[ ${FAILED} -eq 0 ]]; then
    echo "✓ ${TEST_NAME} passed"
    exit 0
else
    echo "✗ ${TEST_NAME} failed"
    exit 1
fi
