#!/bin/bash
################################################################
# Test: RabbitMQ Integration
#
# Verifies RabbitMQ connectivity from test host
################################################################

set -euo pipefail

TEST_NAME="RabbitMQ Integration"
RABBITMQ_HOST="${RABBITMQ_HOST:-192.168.64.1}"
RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"
RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT:-15672}"

echo "Running: ${TEST_NAME}"

# Test 1: RabbitMQ AMQP port is accessible
echo "  → Testing RabbitMQ AMQP port..."
if ! nc -z "${RABBITMQ_HOST}" "${RABBITMQ_PORT}" 2>/dev/null; then
    echo "✗ FAILED: Cannot reach RabbitMQ at ${RABBITMQ_HOST}:${RABBITMQ_PORT}"
    exit 1
fi

# Test 2: RabbitMQ Management API is accessible
echo "  → Testing RabbitMQ Management API..."
if curl -s -f "http://${RABBITMQ_HOST}:${RABBITMQ_MGMT_PORT}/api/overview" -u guest:guest > /dev/null 2>&1; then
    echo "  ✓ RabbitMQ Management API accessible"
else
    echo "  ⚠ WARNING: Management API not accessible (may require different credentials)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
