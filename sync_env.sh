#!/usr/bin/env bash

# sync_env.sh - Sync Conda environment from YAML file
#
# Usage:
#   ./sync_env.sh [--yml <file>] [--req <file>] [--prune] [--yes]
#
# Options:
#   --yml <file>    Path to environment.yml file (default: environment.yml)
#   --req <file>    Path to requirements.txt file (optional)
#   --prune         Remove packages not in the spec files
#   --yes           Skip confirmation prompts
#
# Description:
#   Syncs the active Conda environment to match specifications in YAML and/or
#   requirements files. Updates existing packages, installs missing ones, and
#   optionally removes extra packages (with --prune).

set -euo pipefail

# Default values
YML_FILE="environment.yml"
REQ_FILE=""
PRUNE=false
SKIP_CONFIRM=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yml)
            YML_FILE="$2"
            shift 2
            ;;
        --req)
            REQ_FILE="$2"
            shift 2
            ;;
        --prune)
            PRUNE=true
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
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "🚫 Error: conda command not found"
    exit 1
fi

# Check if an environment is active
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
    echo "🚫 Error: No conda environment is active (or base is active)"
    echo "Please activate an environment first: conda activate <env_name>"
    exit 1
fi

ENV_NAME="${CONDA_DEFAULT_ENV}"
echo "🧭 Active environment: ${ENV_NAME}"
echo ""

# Validate input files
if [[ ! -f "${YML_FILE}" ]] && [[ -z "${REQ_FILE}" ]]; then
    echo "🚫 Error: No input files found"
    echo "Expected ${YML_FILE} or specify files with --yml and/or --req"
    exit 1
fi

# Show sync plan
echo "📋 Sync Plan:"
if [[ -f "${YML_FILE}" ]]; then
    echo "  ✓ Conda packages from: ${YML_FILE}"
fi
if [[ -n "${REQ_FILE}" ]] && [[ -f "${REQ_FILE}" ]]; then
    echo "  ✓ Pip packages from: ${REQ_FILE}"
fi
if [[ "${PRUNE}" == true ]]; then
    echo "  ⚠️  Prune mode: packages not in spec will be removed"
fi
echo ""

# Confirm unless --yes flag
if [[ "${SKIP_CONFIRM}" == false ]]; then
    read -p "Proceed with sync? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Sync cancelled"
        exit 0
    fi
fi

# Sync conda packages
if [[ -f "${YML_FILE}" ]]; then
    echo "🔄 Syncing Conda packages..."

    if [[ "${PRUNE}" == true ]]; then
        # Full sync with prune
        conda env update --name "${ENV_NAME}" --file "${YML_FILE}" --prune
    else
        # Update only (add/update packages)
        conda env update --name "${ENV_NAME}" --file "${YML_FILE}"
    fi

    echo "✅ Conda packages synced"
    echo ""
fi

# Sync pip packages
if [[ -n "${REQ_FILE}" ]] && [[ -f "${REQ_FILE}" ]]; then
    echo "🔄 Syncing pip packages..."

    # Install/update from requirements file
    pip install -r "${REQ_FILE}"

    # Prune pip packages if requested
    if [[ "${PRUNE}" == true ]]; then
        echo "🧹 Pruning pip packages not in ${REQ_FILE}..."

        # Get list of required packages (normalized names)
        required_packages=$(grep -v "^#" "${REQ_FILE}" | grep -v "^$" | sed 's/[>=<~!].*//' | sed 's/\[.*\]//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')

        # Get currently installed pip packages (excluding core ones)
        installed_packages=$(pip list --format=freeze | grep -v "^pip==" | grep -v "^setuptools==" | grep -v "^wheel==" | cut -d'=' -f1 | tr '[:upper:]' '[:lower:]' | tr '_' '-')

        # Find packages to remove
        to_remove=()
        for pkg in ${installed_packages}; do
            if ! echo "${required_packages}" | grep -q "^${pkg}$"; then
                to_remove+=("${pkg}")
            fi
        done

        if [[ ${#to_remove[@]} -gt 0 ]]; then
            echo "Removing: ${to_remove[*]}"
            pip uninstall -y "${to_remove[@]}"
        else
            echo "No packages to prune"
        fi
    fi

    echo "✅ Pip packages synced"
    echo ""
fi

# Show final summary
echo "✅ Sync complete!"
echo ""
echo "Environment '${ENV_NAME}' is now synchronized"
echo ""
echo "📊 Current state:"
echo "  Conda packages: $(conda list | grep -v "^#" | wc -l)"
echo "  Pip packages: $(pip list --format=freeze | wc -l)"
