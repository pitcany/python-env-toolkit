#!/usr/bin/env bash
# Unit test: Verify all scripts have working --help flags

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing --help flags..."

# Scripts that should have --help
scripts=(
    "create_ml_env.sh"
    "clone_env.sh"
    "env_diff.sh"
    "channel_manager.sh"
    "health_check.sh"
    "smart_update.sh"
    "safe_install.sh"
    "validate_scripts.sh"
    "manage_jupyter_kernels.sh"
)

failed=0

for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "SKIP: $script not found"
        continue
    fi

    # Test --help flag (some scripts exit with error code even when showing help)
    help_output=$("./$script" --help 2>&1 || true)
    if echo "$help_output" | grep -q "Usage:"; then
        : # Help works
    else
        echo "FAIL: $script --help failed"
        ((failed++))
    fi

    # Test -h flag
    help_output=$("./$script" -h 2>&1 || true)
    if echo "$help_output" | grep -q "Usage:\|usage:"; then
        : # Help works
    else
        echo "FAIL: $script -h failed"
        ((failed++))
    fi
done

if [[ $failed -eq 0 ]]; then
    echo "✓ All --help flags work"
    exit 0
else
    echo "✗ $failed help flag tests failed"
    exit 1
fi
