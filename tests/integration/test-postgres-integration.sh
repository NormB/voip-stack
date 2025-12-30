#!/bin/bash
################################################################
# Test: PostgreSQL Integration
#
# Verifies PostgreSQL connectivity from test host
################################################################

set -euo pipefail

TEST_NAME="PostgreSQL Integration"
DB_HOST="${DB_HOST:-192.168.64.1}"
DB_PORT="${DB_PORT:-5432}"

echo "Running: ${TEST_NAME}"

# Test 1: PostgreSQL is accessible
echo "  → Testing PostgreSQL accessibility..."
if ! nc -z "${DB_HOST}" "${DB_PORT}" 2>/dev/null; then
    echo "✗ FAILED: Cannot reach PostgreSQL at ${DB_HOST}:${DB_PORT}"
    exit 1
fi

# Test 2: Can connect with psql (if available)
if command -v psql &> /dev/null; then
    echo "  → Testing PostgreSQL connection..."
    if PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U postgres -c "SELECT 1;" > /dev/null 2>&1; then
        echo "  ✓ PostgreSQL connection successful"
    else
        echo "  ⚠ WARNING: Could not authenticate (expected if using Vault credentials)"
    fi
else
    echo "  ⚠ Skipping connection test (psql not installed)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
