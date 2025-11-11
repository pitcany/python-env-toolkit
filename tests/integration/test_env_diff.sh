#!/usr/bin/env bash
# Integration test: env_diff.sh basic functionality

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing env_diff.sh..."

# Check if script exists and is executable
if [[ ! -x "env_diff.sh" ]]; then
    echo "SKIP: env_diff.sh not executable"
    exit 0
fi

# Check if conda is available
if ! command -v conda &>/dev/null; then
    echo "SKIP: conda not available"
    exit 0
fi

failed=0

# Test 1: Script runs with --help
if ! ./env_diff.sh --help &>/dev/null; then
    echo "FAIL: env_diff.sh --help failed"
    failed=$((failed + 1))
fi

# Test 2: Script fails properly with no arguments
if ./env_diff.sh &>/dev/null; then
    echo "FAIL: env_diff.sh should fail with no arguments"
    failed=$((failed + 1))
fi

# Test 3: Script fails properly with invalid environment
if ./env_diff.sh nonexistent_env_12345 nonexistent_env_67890 &>/dev/null; then
    echo "FAIL: env_diff.sh should fail with invalid environments"
    failed=$((failed + 1))
fi

if [[ $failed -eq 0 ]]; then
    echo "✓ env_diff.sh basic tests passed"
    exit 0
else
    echo "✗ $failed env_diff.sh tests failed"
    exit 1
fi
