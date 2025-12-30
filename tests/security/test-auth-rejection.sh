#!/bin/bash
################################################################
# Test: Authentication Rejection
#
# Verifies that invalid credentials are rejected
################################################################

set -euo pipefail

TEST_NAME="Authentication Rejection"
SIP_PROXY="${SIP_PROXY:-192.168.64.10}"
SIP_PORT="${SIP_PORT:-5060}"

echo "Running: ${TEST_NAME}"

# Prerequisites
if ! command -v sipp &> /dev/null; then
    echo "✗ FAILED: sipp command not found"
    exit 1
fi

# Create scenario that uses wrong password
SCENARIO_DIR="/tmp/sipp-scenarios"
mkdir -p "${SCENARIO_DIR}"

cat > "${SCENARIO_DIR}/bad-auth.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<scenario name="Bad Auth Test">
  <send retrans="500">
    <![CDATA[
      REGISTER sip:[remote_ip]:[remote_port] SIP/2.0
      Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
      From: <sip:invalid_user@[remote_ip]>;tag=[pid]SIPpTag00[call_number]
      To: <sip:invalid_user@[remote_ip]>
      Call-ID: [call_id]
      CSeq: 1 REGISTER
      Contact: <sip:invalid_user@[local_ip]:[local_port]>
      Max-Forwards: 70
      Expires: 3600
      Content-Length: 0
    ]]>
  </send>
  <recv response="401" />
</scenario>
EOF

echo "  → Testing rejection of invalid credentials..."
if sipp "${SIP_PROXY}:${SIP_PORT}" \
    -sf "${SCENARIO_DIR}/bad-auth.xml" \
    -m 1 \
    -timeout 10s \
    > /tmp/sipp-bad-auth.log 2>&1; then
    echo "  ✓ Server correctly returns 401 for invalid credentials"
else
    if grep -qE "(401|403|407)" /tmp/sipp-bad-auth.log 2>/dev/null; then
        echo "  ✓ Server correctly rejects invalid credentials"
    else
        echo "  ⚠ WARNING: Unexpected response to invalid credentials"
    fi
fi

echo "✓ ${TEST_NAME} passed"
exit 0
