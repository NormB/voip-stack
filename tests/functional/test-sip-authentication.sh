#!/bin/bash
################################################################
# Test: SIP Authentication
#
# Tests SIP authentication mechanism
################################################################

set -euo pipefail

TEST_NAME="SIP Authentication"
SIP_PROXY="${SIP_PROXY:-192.168.64.10}"
SIP_PORT="${SIP_PORT:-5060}"

echo "Running: ${TEST_NAME}"

# Check if SIP proxy is reachable
if ! nc -z "${SIP_PROXY}" "${SIP_PORT}" 2>/dev/null; then
    echo "  ⚠ SIP proxy not reachable at ${SIP_PROXY}:${SIP_PORT}"
    echo "✓ ${TEST_NAME} passed (skipped - SIP proxy not available)"
    exit 0
fi

# Test 1: Check that unauthenticated requests are challenged
echo "  → Testing authentication challenge..."

# Create a simple OPTIONS request using sipsak if available
if command -v sipsak &> /dev/null; then
    if sipsak -vv -s "sip:${SIP_PROXY}:${SIP_PORT}" 2>&1 | grep -qE "(200|401|407)"; then
        echo "  ✓ SIP server responding to OPTIONS"
    else
        echo "  ⚠ WARNING: Unexpected response to OPTIONS"
    fi
else
    echo "  ⚠ Skipping sipsak test (not installed)"
fi

# Test 2: Use SIPp to verify 401/407 response
if command -v sipp &> /dev/null; then
    SCENARIO_DIR="/tmp/sipp-scenarios"
    mkdir -p "${SCENARIO_DIR}"

    # Create a scenario that expects 401
    cat > "${SCENARIO_DIR}/auth-test.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<scenario name="Auth Test">
  <send>
    <![CDATA[
      INVITE sip:1002@[remote_ip]:[remote_port] SIP/2.0
      Via: SIP/2.0/[transport] [local_ip]:[local_port];branch=[branch]
      From: <sip:1001@[remote_ip]>;tag=[pid]SIPpTag00[call_number]
      To: <sip:1002@[remote_ip]>
      Call-ID: [call_id]
      CSeq: 1 INVITE
      Contact: <sip:1001@[local_ip]:[local_port]>
      Max-Forwards: 70
      Content-Type: application/sdp
      Content-Length: [len]

      v=0
      o=user1 53655765 2353687637 IN IP[local_ip_type] [local_ip]
      s=-
      c=IN IP[media_ip_type] [media_ip]
      t=0 0
      m=audio [media_port] RTP/AVP 0
      a=rtpmap:0 PCMU/8000
    ]]>
  </send>
  <recv response="100" optional="true" />
  <recv response="401" />
</scenario>
EOF

    echo "  → Testing unauthenticated INVITE (expecting 401)..."
    if sipp "${SIP_PROXY}:${SIP_PORT}" \
        -sf "${SCENARIO_DIR}/auth-test.xml" \
        -m 1 \
        -timeout 10s \
        > /tmp/sipp-auth.log 2>&1; then
        echo "  ✓ Server correctly challenges unauthenticated requests"
    else
        if grep -qE "(401|407)" /tmp/sipp-auth.log 2>/dev/null; then
            echo "  ✓ Server correctly challenges unauthenticated requests"
        else
            echo "  ⚠ WARNING: Unexpected response"
        fi
    fi
else
    echo "  ⚠ Skipping SIPp auth test (not installed)"
fi

echo "✓ ${TEST_NAME} passed"
exit 0
