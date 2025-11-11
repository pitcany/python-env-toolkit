#!/usr/bin/env bash
# ---------------------------------------------------------------------
# run_tests.sh - Main test runner for Python Environment Toolkit
#
# Usage:
#   ./tests/run_tests.sh              # Run all tests
#   ./tests/run_tests.sh unit         # Run only unit tests
#   ./tests/run_tests.sh integration  # Run only integration tests
#   ./tests/run_tests.sh --verbose    # Run with verbose output
# ---------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
VERBOSE=false
TEST_TYPE="all"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --verbose|-v)
            VERBOSE=true
            ;;
        unit)
            TEST_TYPE="unit"
            ;;
        integration)
            TEST_TYPE="integration"
            ;;
        --help|-h)
            sed -n '2,10p' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
    esac
done

# Print functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_test_start() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${YELLOW}▶ $1${NC}"
    else
        echo -n "Testing $1... "
    fi
}

print_test_pass() {
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}"
    else
        echo -e "${GREEN}✓ PASS${NC}"
    fi
}

print_test_fail() {
    local message=$1
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${RED}✗ FAIL: $message${NC}"
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo -e "  ${RED}$message${NC}"
    fi
}

print_test_skip() {
    local reason=$1
    ((SKIPPED_TESTS++))
    ((TOTAL_TESTS++))
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${YELLOW}⊘ SKIP: $reason${NC}"
    else
        echo -e "${YELLOW}⊘ SKIP${NC}"
    fi
}

# Run a test file
run_test_file() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sh)

    print_test_start "$test_name"

    if [[ "$VERBOSE" == true ]]; then
        if bash "$test_file"; then
            print_test_pass
        else
            print_test_fail "Test script failed"
        fi
    else
        if output=$(bash "$test_file" 2>&1); then
            print_test_pass
        else
            print_test_fail "$output"
        fi
    fi
}

# Run unit tests
run_unit_tests() {
    print_header "Unit Tests"

    local unit_tests
    mapfile -t unit_tests < <(find "$TEST_DIR/unit" -name "test_*.sh" -type f | sort)

    if [[ ${#unit_tests[@]} -eq 0 ]]; then
        echo "No unit tests found"
        return
    fi

    for test_file in "${unit_tests[@]}"; do
        run_test_file "$test_file"
    done

    echo ""
}

# Run integration tests
run_integration_tests() {
    print_header "Integration Tests"

    local integration_tests
    mapfile -t integration_tests < <(find "$TEST_DIR/integration" -name "test_*.sh" -type f | sort)

    if [[ ${#integration_tests[@]} -eq 0 ]]; then
        echo "No integration tests found"
        return
    fi

    for test_file in "${integration_tests[@]}"; do
        run_test_file "$test_file"
    done

    echo ""
}

# Print summary
print_summary() {
    print_header "Test Summary"

    echo "Total tests run: $TOTAL_TESTS"
    echo -e "${GREEN}Passed:  $PASSED_TESTS${NC}"
    echo -e "${RED}Failed:   $FAILED_TESTS${NC}"
    echo -e "${YELLOW}Skipped:  $SKIPPED_TESTS${NC}"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    cd "$ROOT_DIR"

    echo ""
    print_header "🧪 Python Environment Toolkit Test Suite"
    echo "Running tests from: $TEST_DIR"
    echo "Test type: $TEST_TYPE"
    echo ""

    # Run tests based on type
    case "$TEST_TYPE" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        all)
            run_unit_tests
            run_integration_tests
            ;;
    esac

    # Print summary and exit
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

main
