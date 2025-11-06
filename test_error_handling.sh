#!/usr/bin/env bash
#
# Test script for smart_update.sh error handling
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing smart_update.sh Error Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_test() {
    local test_name=$1
    local command=$2
    local expected_exit_code=${3:-1}  # Default expect failure

    echo -n "Testing: $test_name ... "

    if eval "$command" >/dev/null 2>&1; then
        actual_exit=0
    else
        actual_exit=$?
    fi

    if [[ $actual_exit -eq $expected_exit_code ]]; then
        echo -e "${GREEN}✅ PASS${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ FAIL${NC} (expected exit $expected_exit_code, got $actual_exit)"
        ((failed++))
    fi
}

# Test 1: Invalid environment name
run_test "Invalid environment name" \
    "./smart_update.sh --name nonexistent_env_12345" \
    1

# Test 2: No active environment (base environment check)
run_test "Help flag works" \
    "./smart_update.sh --help" \
    0

# Test 3: Version parsing
run_test "Version parsing test" \
    "./smart_update.sh --test" \
    0

# Test 4: Invalid argument
run_test "Invalid argument handling" \
    "./smart_update.sh --invalid-flag-xyz" \
    1

# Test 5: Script is executable
if [[ -x "./smart_update.sh" ]]; then
    echo -e "Testing: Script is executable ... ${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "Testing: Script is executable ... ${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 6: Check for syntax errors
echo -n "Testing: No bash syntax errors ... "
if bash -n ./smart_update.sh 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 7: Check required functions exist
echo -n "Testing: Required functions defined ... "
required_funcs=(
    "check_internet_connectivity"
    "check_required_tools"
    "parse_arguments"
    "detect_environment"
    "initialize_cache"
    "assess_package_risk"
    "execute_update"
    "execute_approved_updates"
)

all_found=true
for func in "${required_funcs[@]}"; do
    if ! grep -q "^${func}()" ./smart_update.sh; then
        echo -e "${RED}❌ FAIL${NC} (missing function: $func)"
        all_found=false
        break
    fi
done

if [[ "$all_found" == true ]]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    ((failed++))
fi

# Test 8: Check error handling patterns exist
echo -n "Testing: Error handling patterns present ... "
error_patterns=(
    "set -euo pipefail"
    "|| true"
    "2>/dev/null"
    "if.*then"
)

all_found=true
for pattern in "${error_patterns[@]}"; do
    if ! grep -q "$pattern" ./smart_update.sh; then
        echo -e "${RED}❌ FAIL${NC} (missing pattern: $pattern)"
        all_found=false
        break
    fi
done

if [[ "$all_found" == true ]]; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    ((failed++))
fi

# Test 9: Check graceful degradation for missing tools
echo -n "Testing: Graceful degradation messages ... "
if grep -q "Warning.*jq not installed" ./smart_update.sh && \
   grep -q "Warning.*curl.*wget" ./smart_update.sh && \
   grep -q "Warning.*pip not" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 10: Check cache error handling
echo -n "Testing: Cache error handling ... "
if grep -q "Could not create cache directory" ./smart_update.sh && \
   grep -q "Cache file not readable" ./smart_update.sh && \
   grep -q "mktemp -d" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 11: Check network error handling
echo -n "Testing: Network error handling ... "
if grep -q "network.*error\|Network error" ./smart_update.sh && \
   grep -q "timeout\|--max-time" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 12: Check installation error handling
echo -n "Testing: Installation error categorization ... "
if grep -q "PackagesNotFoundError" ./smart_update.sh && \
   grep -q "conflict\|incompatible" ./smart_update.sh && \
   grep -q "Failed to install" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 13: Check pre-flight checks are called
echo -n "Testing: Pre-flight checks integration ... "
if grep -q "check_required_tools" ./smart_update.sh && \
   grep -q "check_internet_connectivity" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Test 14: Check post-update actions
echo -n "Testing: Post-update actions exist ... "
if grep -q "Post-Update Actions" ./smart_update.sh && \
   grep -q "Update Process Complete" ./smart_update.sh && \
   grep -q "Recommendations\|Troubleshooting" ./smart_update.sh; then
    echo -e "${GREEN}✅ PASS${NC}"
    ((passed++))
else
    echo -e "${RED}❌ FAIL${NC}"
    ((failed++))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Passed: $passed${NC}"
echo -e "${RED}❌ Failed: $failed${NC}"
echo "   Total: $((passed + failed))"
echo ""

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Review the output above.${NC}"
    exit 1
fi
