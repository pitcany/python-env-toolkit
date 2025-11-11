#!/usr/bin/env bash

# find_duplicates.sh - Find packages installed in both Conda and pip
#
# Usage:
#   ./find_duplicates.sh [env_name] [--fix] [--yes]
#
# Arguments:
#   env_name        Optional: target environment name (uses active env if not specified)
#
# Options:
#   --fix           Remove pip duplicates (keeps Conda versions)
#   --yes           Skip confirmation prompts when using --fix
#
# Description:
#   Detects packages installed via both Conda and pip, which can cause conflicts.
#   Shows package names and versions from both sources. Optionally removes pip
#   versions to avoid conflicts (Conda versions are kept as they're better integrated).

set -euo pipefail

# Default values
TARGET_ENV=""
FIX_MODE=false
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            TARGET_ENV="$1"
            shift
            ;;
    esac
done

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "🚫 Error: conda command not found"
    exit 1
fi

# Determine which environment to use
if [[ -n "${TARGET_ENV}" ]]; then
    ENV_NAME="${TARGET_ENV}"
    echo "🧭 Checking environment: ${ENV_NAME}"
else
    if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
        echo "🚫 Error: No conda environment specified and no environment is active"
        echo "Usage: $0 [env_name] or activate an environment first"
        exit 1
    fi
    ENV_NAME="${CONDA_DEFAULT_ENV}"
    echo "🧭 Checking active environment: ${ENV_NAME}"
fi
echo ""

# Get conda packages (normalize names: lowercase, replace _ with -)
echo "📦 Analyzing Conda packages..."
conda_packages=$(conda list --name "${ENV_NAME}" | grep -v "^#" | awk '{print $1}' | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sort)

# Get pip packages (normalize names)
echo "📦 Analyzing pip packages..."
if [[ -n "${TARGET_ENV}" ]]; then
    # Use conda run for specified environment
    pip_packages=$(conda run --name "${ENV_NAME}" pip list --format=freeze | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sort)
else
    # Use pip directly for active environment
    pip_packages=$(pip list --format=freeze | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sort)
fi

# Find duplicates
echo "🔍 Searching for duplicates..."
echo ""

duplicates=()
duplicate_info=()

for pkg in ${conda_packages}; do
    if echo "${pip_packages}" | grep -q "^${pkg}$"; then
        duplicates+=("${pkg}")

        # Get version info
        conda_version=$(conda list --name "${ENV_NAME}" | grep -i "^${pkg}" | head -1 | awk '{print $2}')

        if [[ -n "${TARGET_ENV}" ]]; then
            pip_version=$(conda run --name "${ENV_NAME}" pip show "${pkg}" 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "unknown")
        else
            pip_version=$(pip show "${pkg}" 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "unknown")
        fi

        duplicate_info+=("${pkg}|conda:${conda_version}|pip:${pip_version}")
    fi
done

# Display results
if [[ ${#duplicates[@]} -eq 0 ]]; then
    echo "✅ No duplicates found!"
    echo "All packages are installed via either Conda or pip, but not both."
    exit 0
fi

echo "⚠️  Found ${#duplicates[@]} package(s) installed in both Conda and pip:"
echo ""
printf "%-30s %-20s %-20s\n" "Package" "Conda Version" "Pip Version"
printf "%-30s %-20s %-20s\n" "-------" "-------------" "-----------"

for info in "${duplicate_info[@]}"; do
    IFS='|' read -r pkg conda_ver pip_ver <<< "${info}"
    conda_ver_clean=$(echo "${conda_ver}" | sed 's/conda://')
    pip_ver_clean=$(echo "${pip_ver}" | sed 's/pip://')
    printf "%-30s %-20s %-20s\n" "${pkg}" "${conda_ver_clean}" "${pip_ver_clean}"
done

echo ""
echo "💡 Why this matters:"
echo "   Having packages installed via both Conda and pip can cause:"
echo "   - Version conflicts and unexpected behavior"
echo "   - Dependency resolution issues"
echo "   - Difficulty tracking package sources"
echo ""

# Fix mode
if [[ "${FIX_MODE}" == true ]]; then
    echo "🔧 Fix mode enabled: Will remove pip versions (keeping Conda versions)"
    echo ""

    # Confirm unless --yes flag
    if [[ "${SKIP_CONFIRM}" == false ]]; then
        read -p "Remove ${#duplicates[@]} pip package(s)? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Fix cancelled"
            exit 0
        fi
    fi

    echo "🧹 Removing pip duplicates..."

    # Remove duplicates from pip
    for pkg in "${duplicates[@]}"; do
        echo "  Removing: ${pkg} (pip)"
        if [[ -n "${TARGET_ENV}" ]]; then
            conda run --name "${ENV_NAME}" pip uninstall -y "${pkg}" 2>/dev/null || echo "    Warning: could not remove ${pkg}"
        else
            pip uninstall -y "${pkg}" 2>/dev/null || echo "    Warning: could not remove ${pkg}"
        fi
    done

    echo ""
    echo "✅ Cleanup complete!"
    echo "   Conda versions retained, pip duplicates removed"
else
    echo "💡 To automatically fix this, run:"
    if [[ -n "${TARGET_ENV}" ]]; then
        echo "   $0 ${ENV_NAME} --fix"
    else
        echo "   $0 --fix"
    fi
    echo ""
    echo "   Or manually remove pip versions: pip uninstall <package>"
fi
