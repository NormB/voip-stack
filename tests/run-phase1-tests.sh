#!/bin/bash
################################################################
# Phase 1 Test Runner
#
# Runs all Phase 1 tests to verify basic calling functionality
#
# Usage:
#   ./tests/run-phase1-tests.sh
#   ./tests/run-phase1-tests.sh --verbose
################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Configuration
VERBOSE=false
TEST_LOG="/tmp/voip-stack-tests-$(date +%Y%m%d-%H%M%S).log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--verbose]"
            exit 1
            ;;
    esac
done

# Functions
print_banner() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}→${NC} Running: $1"
}

print_pass() {
    echo -e "${GREEN}✓${NC} PASSED: $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}✗${NC} FAILED: $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_skip() {
    echo -e "${YELLOW}⊘${NC} SKIPPED: $1"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

run_test() {
    local test_script="$1"
    local test_name="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_test "${test_name}"

    if [[ ! -f "${test_script}" ]]; then
        print_skip "${test_name} (script not found)"
        return
    fi

    if [[ "${VERBOSE}" == "true" ]]; then
        if bash "${test_script}"; then
            print_pass "${test_name}"
        else
            print_fail "${test_name}"
        fi
    else
        if bash "${test_script}" >> "${TEST_LOG}" 2>&1; then
            print_pass "${test_name}"
        else
            print_fail "${test_name}"
            echo "  See log: ${TEST_LOG}"
        fi
    fi
}

# Main test execution
main() {
    print_banner "voip-stack Phase 1 Test Suite"
    echo "Test log: ${TEST_LOG}"
    echo ""

    # Infrastructure Tests
    print_banner "Infrastructure Tests"
    run_test "tests/integration/test-vault-integration.sh" "Vault connectivity and authentication"
    run_test "tests/integration/test-postgres-integration.sh" "PostgreSQL connectivity"
    run_test "tests/integration/test-redis-integration.sh" "Redis connectivity"
    run_test "tests/integration/test-rabbitmq-integration.sh" "RabbitMQ connectivity"
    echo ""

    # Component Tests
    print_banner "Component Tests"
    run_test "tests/integration/test-opensips-status.sh" "OpenSIPS is running"
    run_test "tests/integration/test-asterisk-status.sh" "Asterisk is running"
    run_test "tests/integration/test-rtpengine-status.sh" "RTPEngine is running"
    echo ""

    # Network Tests
    print_banner "Network Tests"
    run_test "tests/integration/test-network-connectivity.sh" "Inter-VM connectivity"
    run_test "tests/integration/test-opensips-asterisk.sh" "OpenSIPS → Asterisk routing"
    run_test "tests/integration/test-rtpengine-dispatcher.sh" "OpenSIPS → RTPEngine dispatcher"
    echo ""

    # Functional Tests (SIP)
    print_banner "Functional Tests (SIP)"
    run_test "tests/functional/test-sip-registration.sh" "SIP registration (1001)"
    run_test "tests/functional/test-sip-authentication.sh" "SIP authentication"
    run_test "tests/functional/test-basic-call.sh" "Basic call (1001 → 1002)"
    run_test "tests/functional/test-call-with-srtp.sh" "Call with SRTP encryption"
    echo ""

    # SIPp Scenarios
    print_banner "SIPp Scenarios"
    run_test "tests/sipp/scripts/run-basic-call-test.sh" "SIPp: Basic UAC → UAS"
    run_test "tests/sipp/scripts/run-registration-test.sh" "SIPp: Registration test"
    run_test "tests/sipp/scripts/run-load-test.sh" "SIPp: Load test (10 CPS)"
    echo ""

    # Security Tests
    print_banner "Security Tests"
    run_test "tests/security/test-tls-connectivity.sh" "TLS connectivity"
    run_test "tests/security/test-srtp-encryption.sh" "SRTP media encryption"
    run_test "tests/security/test-auth-rejection.sh" "Authentication rejection"
    echo ""

    # CDR Tests
    print_banner "CDR Tests"
    run_test "tests/integration/test-cdr-generation.sh" "CDR generation"
    run_test "tests/integration/test-cdr-rabbitmq.sh" "CDR publishing to RabbitMQ"
    echo ""

    # Homer Integration
    print_banner "Homer Integration"
    run_test "tests/integration/test-homer-capture.sh" "Homer HEP capture"
    echo ""

    # Monitoring Tests
    print_banner "Monitoring Tests"
    run_test "tests/integration/test-prometheus-metrics.sh" "Prometheus metrics collection"
    run_test "tests/integration/test-node-exporter.sh" "Node exporter on all VMs"
    echo ""

    # Summary
    print_banner "Test Summary"
    echo "Total Tests:  ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed:       ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed:       ${FAILED_TESTS}${NC}"
    echo -e "${YELLOW}Skipped:      ${SKIPPED_TESTS}${NC}"
    echo ""

    if [[ ${FAILED_TESTS} -eq 0 ]] && [[ ${PASSED_TESTS} -gt 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo "Test log: ${TEST_LOG}"
        exit 0
    elif [[ ${FAILED_TESTS} -gt 0 ]]; then
        echo -e "${RED}✗ Some tests failed${NC}"
        echo "Test log: ${TEST_LOG}"
        exit 1
    else
        echo -e "${YELLOW}⊘ No tests were executed${NC}"
        exit 1
    fi
}

# Run main
main
