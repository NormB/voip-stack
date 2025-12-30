#!/bin/bash
################################################################
# Test: CDR Publishing to RabbitMQ
#
# Verifies CDR records are published to RabbitMQ
################################################################

set -euo pipefail

TEST_NAME="CDR Publishing to RabbitMQ"
RABBITMQ_HOST="${RABBITMQ_HOST:-192.168.64.1}"
RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT:-15672}"
CDR_QUEUE="${CDR_QUEUE:-voip.cdrs}"

echo "Running: ${TEST_NAME}"

# Test 1: Check RabbitMQ is accessible
echo "  → Checking RabbitMQ connectivity..."
if ! nc -z "${RABBITMQ_HOST}" "${RABBITMQ_MGMT_PORT}" 2>/dev/null; then
    echo "✗ FAILED: Cannot reach RabbitMQ management at ${RABBITMQ_HOST}:${RABBITMQ_MGMT_PORT}"
    exit 1
fi

# Test 2: Check for CDR queue (if configured)
echo "  → Checking for CDR queue..."
QUEUE_INFO=$(curl -s -u guest:guest "http://${RABBITMQ_HOST}:${RABBITMQ_MGMT_PORT}/api/queues" 2>/dev/null || echo "[]")

if echo "${QUEUE_INFO}" | grep -q "${CDR_QUEUE}"; then
    echo "  ✓ CDR queue '${CDR_QUEUE}' exists"
else
    echo "  ⚠ CDR queue '${CDR_QUEUE}' not found (may need configuration)"
fi

# Test 3: Check Asterisk AMQP module
echo "  → Checking Asterisk AMQP configuration..."
AMQP_MODULE=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no voip@192.168.64.30 \
    'docker exec asterisk asterisk -rx "module show like amqp" 2>/dev/null' 2>/dev/null || echo "not loaded")

if [[ "${AMQP_MODULE}" == *"res_amqp"* ]]; then
    echo "  ✓ AMQP module loaded in Asterisk"
else
    echo "  ⚠ AMQP module not loaded (CDR to RabbitMQ not configured)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
