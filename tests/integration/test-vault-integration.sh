#!/bin/bash
################################################################
# Test: Vault Integration
#
# Verifies Vault connectivity and authentication from VMs
################################################################

set -euo pipefail

TEST_NAME="Vault Integration"
VAULT_ADDR="${VAULT_ADDR:-http://192.168.64.1:8200}"

echo "Running: ${TEST_NAME}"

# Test 1: Vault is accessible
echo "  → Testing Vault accessibility..."
if ! curl -s -f "${VAULT_ADDR}/v1/sys/health" > /dev/null; then
    echo "✗ FAILED: Cannot reach Vault at ${VAULT_ADDR}"
    exit 1
fi

# Test 2: Check Vault status
echo "  → Checking Vault status..."
VAULT_STATUS=$(curl -s "${VAULT_ADDR}/v1/sys/health")
SEALED=$(echo "${VAULT_STATUS}" | grep -o '"sealed":[^,]*' | cut -d':' -f2)

if [[ "${SEALED}" == "true" ]]; then
    echo "✗ FAILED: Vault is sealed"
    exit 1
fi

# Test 3: Verify AppRole auth method is enabled
echo "  → Verifying AppRole auth method..."
if ! curl -s -H "X-Vault-Token: ${VAULT_TOKEN:-}" \
    "${VAULT_ADDR}/v1/sys/auth" | grep -q "approle"; then
    echo "⚠ WARNING: AppRole auth method not found (expected for initial setup)"
fi

# Test 4: Test VM can authenticate (if role_id and secret_id are set)
if [[ -n "${VAULT_ROLE_ID:-}" ]] && [[ -n "${VAULT_SECRET_ID:-}" ]]; then
    echo "  → Testing AppRole authentication..."
    AUTH_RESPONSE=$(curl -s -X POST \
        -d "{\"role_id\":\"${VAULT_ROLE_ID}\",\"secret_id\":\"${VAULT_SECRET_ID}\"}" \
        "${VAULT_ADDR}/v1/auth/approle/login")

    if echo "${AUTH_RESPONSE}" | grep -q "client_token"; then
        echo "  ✓ AppRole authentication successful"
    else
        echo "✗ FAILED: AppRole authentication failed"
        exit 1
    fi
fi

echo "✓ ${TEST_NAME} passed"
exit 0
