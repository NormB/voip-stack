#!/bin/bash
################################################################
# Test: Network Connectivity
#
# Verifies inter-VM connectivity
################################################################

set -euo pipefail

TEST_NAME="Network Connectivity"
SIP_VM="${SIP_VM:-192.168.64.10}"
MEDIA_VM="${MEDIA_VM:-192.168.64.20}"
PBX_VM="${PBX_VM:-192.168.64.30}"
HOST_IP="${HOST_IP:-192.168.64.1}"

echo "Running: ${TEST_NAME}"

# Test 1: Host can reach all VMs
echo "  → Testing host → VM connectivity..."
for vm in "${SIP_VM}" "${MEDIA_VM}" "${PBX_VM}"; do
    if nc -z "${vm}" 22 2>/dev/null; then
        echo "  ✓ Host can reach ${vm}"
    else
        echo "✗ FAILED: Host cannot reach ${vm}"
        exit 1
    fi
done

# Test 2: VMs can reach host (devstack-core)
echo "  → Testing VM → host connectivity..."
for vm in "${SIP_VM}" "${MEDIA_VM}" "${PBX_VM}"; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${vm}" \
        "nc -z ${HOST_IP} 8200" 2>/dev/null; then
        echo "  ✓ ${vm} can reach host"
    else
        echo "✗ FAILED: ${vm} cannot reach host at ${HOST_IP}"
        exit 1
    fi
done

# Test 3: Inter-VM connectivity
echo "  → Testing inter-VM connectivity..."
# sip-1 → pbx-1
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${SIP_VM}" \
    "nc -z ${PBX_VM} 22" 2>/dev/null; then
    echo "  ✓ sip-1 can reach pbx-1"
else
    echo "✗ FAILED: sip-1 cannot reach pbx-1"
    exit 1
fi

# sip-1 → media-1
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@"${SIP_VM}" \
    "nc -z ${MEDIA_VM} 22" 2>/dev/null; then
    echo "  ✓ sip-1 can reach media-1"
else
    echo "✗ FAILED: sip-1 cannot reach media-1"
    exit 1
fi

echo "✓ ${TEST_NAME} passed"
exit 0
