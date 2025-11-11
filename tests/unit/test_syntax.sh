#!/usr/bin/env bash
# Unit test: Syntax validation for all scripts

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Testing bash syntax for all scripts..."

# Find all shell scripts
mapfile -t scripts < <(find . -maxdepth 1 -name "*.sh" -type f)

failed=0

for script in "${scripts[@]}"; do
    if ! bash -n "$script" 2>/dev/null; then
        echo "FAIL: Syntax error in $script"
        ((failed++))
    fi
done

if [[ $failed -eq 0 ]]; then
    echo "✓ All scripts have valid syntax"
    exit 0
else
    echo "✗ $failed scripts have syntax errors"
    exit 1
fi
