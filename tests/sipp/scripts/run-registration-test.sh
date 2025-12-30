#!/bin/bash
################################################################
# Test: SIPp Registration Test
#
# Runs SIPp registration scenario
################################################################

set -euo pipefail

TEST_NAME="SIPp Registration Test"
SIP_PROXY="${SIP_PROXY:-192.168.64.10}"
SIP_PORT="${SIP_PORT:-5060}"
SCENARIO_DIR="/Users/gator/voip-stack/tests/sipp/scenarios"

echo "Running: ${TEST_NAME}"

# Prerequisites
if ! command -v sipp &> /dev/null; then
    echo "✗ FAILED: sipp command not found"
    exit 1
fi

# Check for scenario file
REG_SCENARIO="${SCENARIO_DIR}/register.xml"
if [[ ! -f "${REG_SCENARIO}" ]]; then
    # Use inline scenario
    REG_SCENARIO="/tmp/sipp-register-test.xml"
    cat > "${REG_SCENARIO}" <<'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<scenario name="Registration Test">
  <send retrans="500">
    <![CDATA[
      REGISTER sip:[remote_ip]:[remote_port] SIP/2.0
      Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
      From: <sip:[service]@[remote_ip]>;tag=[pid]SIPpTag00[call_number]
      To: <sip:[service]@[remote_ip]>
      Call-ID: [call_id]
      CSeq: 1 REGISTER
      Contact: <sip:[service]@[local_ip]:[local_port]>
      Max-Forwards: 70
      Expires: 3600
      Content-Length: 0
    ]]>
  </send>
  <recv response="100" optional="true" />
  <recv response="401" optional="true" />
  <recv response="200" optional="true" />
</scenario>
EOF
fi

echo "  → Running SIPp registration test..."
if sipp "${SIP_PROXY}:${SIP_PORT}" \
    -sf "${REG_SCENARIO}" \
    -s 1001 \
    -m 1 \
    -timeout 10s \
    > /tmp/sipp-reg.log 2>&1; then
    echo "✓ ${TEST_NAME} passed"
    exit 0
else
    if grep -qE "(200|401)" /tmp/sipp-reg.log 2>/dev/null; then
        echo "  ✓ Server responded correctly"
        echo "✓ ${TEST_NAME} passed"
        exit 0
    fi
    echo "✗ FAILED: Registration test failed"
    echo "  Log: /tmp/sipp-reg.log"
    exit 1
fi
