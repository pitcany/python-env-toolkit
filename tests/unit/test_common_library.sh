#!/usr/bin/env bash
# Unit test: Test common library functions

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing common library..."

# Check if common library exists
if [[ ! -f "lib/common.sh" ]]; then
    echo "✗ lib/common.sh not found"
    exit 1
fi

# Source the common library
# shellcheck disable=SC1091
source "lib/common.sh"

failed=0

# Test 1: show_version function exists
if ! declare -f show_version >/dev/null; then
    echo "FAIL: show_version function not defined"
    failed=$((failed + 1))
fi

# Test 2: VERSION file can be loaded
if [[ -z "${TOOLKIT_VERSION:-}" ]]; then
    echo "FAIL: TOOLKIT_VERSION not set after sourcing common.sh"
    failed=$((failed + 1))
fi

# Test 3: Error functions exist
for func in error_env_not_found error_command_not_found error_invalid_flag; do
    if ! declare -f "$func" >/dev/null; then
        echo "FAIL: $func function not defined"
        failed=$((failed + 1))
    fi
done

# Test 4: Validation functions exist
for func in validate_conda_env check_required_dependency check_optional_dependency; do
    if ! declare -f "$func" >/dev/null; then
        echo "FAIL: $func function not defined"
        failed=$((failed + 1))
    fi
done

if [[ $failed -eq 0 ]]; then
    echo "✓ Common library functions exist and load correctly"
    exit 0
else
    echo "✗ $failed common library tests failed"
    exit 1
fi
