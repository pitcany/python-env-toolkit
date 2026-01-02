#!/usr/bin/env bash

# clone_env.sh - Smart environment cloning with modifications
#
# Usage:
#   ./clone_env.sh <source_env> <new_env> [OPTIONS]
#
# Options:
#   --python <version>      Change Python version (e.g., 3.10, 3.11)
#   --swap-framework <fw>   Swap ML framework (pytorch->tensorflow, tensorflow->pytorch, pytorch->jax)
#   --cpu-to-gpu            Switch from CPU to GPU packages
#   --gpu-to-cpu            Switch from GPU to CPU packages
#   --remove <package>      Remove specific package(s) (can be used multiple times)
#   --add <package>         Add specific package(s) (can be used multiple times)
#   --yes                   Skip confirmation prompts
#   --help, -h              Show this help message
#
# Description:
#   Clone a conda environment with intelligent modifications:
#   - Change Python version
#   - Swap ML frameworks (PyTorch, TensorFlow, JAX)
#   - Switch between CPU and GPU variants
#   - Add or remove specific packages
#
# Examples:
#   # Clone with newer Python
#   ./clone_env.sh myenv myenv-py311 --python 3.11
#
#   # Clone and switch to GPU
#   ./clone_env.sh myenv-cpu myenv-gpu --cpu-to-gpu
#
#   # Clone and swap PyTorch for TensorFlow
#   ./clone_env.sh pytorch-env tf-env --swap-framework pytorch->tensorflow

set -euo pipefail

# Source common library for cross-platform compatibility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
SOURCE_ENV=""
NEW_ENV=""
PYTHON_VERSION=""
SWAP_FRAMEWORK=""
CPU_TO_GPU=false
GPU_TO_CPU=false
REMOVE_PACKAGES=()
ADD_PACKAGES=()
SKIP_CONFIRM=false

# Functions for colored output
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}🚫 $1${NC}"
}

# Show help
show_help() {
    grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --python)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        --swap-framework)
            SWAP_FRAMEWORK="$2"
            shift 2
            ;;
        --cpu-to-gpu)
            CPU_TO_GPU=true
            shift
            ;;
        --gpu-to-cpu)
            GPU_TO_CPU=true
            shift
            ;;
        --remove)
            REMOVE_PACKAGES+=("$2")
            shift 2
            ;;
        --add)
            ADD_PACKAGES+=("$2")
            shift 2
            ;;
        --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [[ -z "$SOURCE_ENV" ]]; then
                SOURCE_ENV="$1"
            elif [[ -z "$NEW_ENV" ]]; then
                NEW_ENV="$1"
            else
                print_error "Too many positional arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$SOURCE_ENV" ]] || [[ -z "$NEW_ENV" ]]; then
    print_error "Missing required arguments"
    echo "Usage: $0 <source_env> <new_env> [OPTIONS]"
    echo "Use --help for more information"
    exit 1
fi

# Check if conda is available
if ! command -v conda &> /dev/null; then
    print_error "conda command not found"
    exit 1
fi

# Validate source environment exists
if ! conda env list | grep -q "^${SOURCE_ENV} "; then
    print_error "Source environment '${SOURCE_ENV}' not found"
    exit 1
fi

# Check if new environment already exists
if conda env list | grep -q "^${NEW_ENV} "; then
    print_error "Target environment '${NEW_ENV}' already exists"
    exit 1
fi

# Validate conflicting options
if [[ "$CPU_TO_GPU" == true ]] && [[ "$GPU_TO_CPU" == true ]]; then
    print_error "Cannot use both --cpu-to-gpu and --gpu-to-cpu"
    exit 1
fi

echo ""
print_header "Smart Environment Cloning"
echo ""
print_info "Source: $SOURCE_ENV"
print_info "Target: $NEW_ENV"
echo ""

# Export source environment to temporary file
# Use portable mktemp syntax (BSD mktemp doesn't support --suffix)
TEMP_YML=$(mktemp)
mv "$TEMP_YML" "${TEMP_YML}.yml"
TEMP_YML="${TEMP_YML}.yml"
trap 'rm -f "$TEMP_YML"' EXIT

print_info "Exporting source environment..."
conda env export -n "$SOURCE_ENV" --no-builds > "$TEMP_YML"
print_success "Environment exported"
echo ""

# Show planned modifications
HAS_MODIFICATIONS=false

if [[ -n "$PYTHON_VERSION" ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: Python version → $PYTHON_VERSION"
fi

if [[ -n "$SWAP_FRAMEWORK" ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: Framework swap → $SWAP_FRAMEWORK"
fi

if [[ "$CPU_TO_GPU" == true ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: CPU → GPU packages"
fi

if [[ "$GPU_TO_CPU" == true ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: GPU → CPU packages"
fi

if [[ ${#REMOVE_PACKAGES[@]} -gt 0 ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: Remove packages → ${REMOVE_PACKAGES[*]}"
fi

if [[ ${#ADD_PACKAGES[@]} -gt 0 ]]; then
    HAS_MODIFICATIONS=true
    print_info "Modification: Add packages → ${ADD_PACKAGES[*]}"
fi

if [[ "$HAS_MODIFICATIONS" == false ]]; then
    print_info "No modifications specified (standard clone)"
fi

echo ""

# Apply modifications to YAML
# Use portable mktemp syntax (BSD mktemp doesn't support --suffix)
MODIFIED_YML=$(mktemp)
mv "$MODIFIED_YML" "${MODIFIED_YML}.yml"
MODIFIED_YML="${MODIFIED_YML}.yml"
trap 'rm -f "$TEMP_YML" "$MODIFIED_YML"' EXIT

cp "$TEMP_YML" "$MODIFIED_YML"

# Change Python version
if [[ -n "$PYTHON_VERSION" ]]; then
    print_info "Applying: Python version change..."
    sed_inplace "s|^  - python=.*|  - python=$PYTHON_VERSION|" "$MODIFIED_YML"
fi

# Swap frameworks
if [[ -n "$SWAP_FRAMEWORK" ]]; then
    print_info "Applying: Framework swap..."

    case "$SWAP_FRAMEWORK" in
        pytorch-\>tensorflow|pytorch-\>tf)
            # Remove PyTorch packages
            sed_inplace '/pytorch/d' "$MODIFIED_YML"
            sed_inplace '/torchvision/d' "$MODIFIED_YML"
            sed_inplace '/torchaudio/d' "$MODIFIED_YML"
            # Add TensorFlow (let conda resolve version)
            sed_inplace '/^dependencies:/a\  - tensorflow' "$MODIFIED_YML"
            ;;
        tensorflow-\>pytorch|tf-\>pytorch)
            # Remove TensorFlow packages
            sed_inplace '/tensorflow/d' "$MODIFIED_YML"
            sed_inplace '/keras/d' "$MODIFIED_YML"
            # Add PyTorch (let conda resolve version)
            sed_inplace '/^dependencies:/a\  - pytorch\n  - torchvision' "$MODIFIED_YML"
            ;;
        pytorch-\>jax)
            # Remove PyTorch packages
            sed_inplace '/pytorch/d' "$MODIFIED_YML"
            sed_inplace '/torchvision/d' "$MODIFIED_YML"
            sed_inplace '/torchaudio/d' "$MODIFIED_YML"
            # Add JAX (pip package usually)
            sed_inplace '/^dependencies:/a\  - pip:\n    - jax\n    - jaxlib' "$MODIFIED_YML"
            ;;
        *)
            print_error "Unsupported framework swap: $SWAP_FRAMEWORK"
            exit 1
            ;;
    esac
fi

# CPU to GPU
if [[ "$CPU_TO_GPU" == true ]]; then
    print_info "Applying: CPU to GPU conversion..."
    # PyTorch: cpuonly -> cudatoolkit
    sed_inplace 's/cpuonly/cudatoolkit=11.8/' "$MODIFIED_YML"
    # TensorFlow: add GPU suffix if not present
    sed_inplace 's/tensorflow=\([0-9.]*\)$/tensorflow-gpu=\1/' "$MODIFIED_YML"
fi

# GPU to CPU
if [[ "$GPU_TO_CPU" == true ]]; then
    print_info "Applying: GPU to CPU conversion..."
    # PyTorch: remove cudatoolkit, add cpuonly
    sed_inplace '/cudatoolkit/d' "$MODIFIED_YML"
    sed_inplace '/^dependencies:/a\  - cpuonly' "$MODIFIED_YML"
    # TensorFlow: remove GPU suffix
    sed_inplace 's/tensorflow-gpu/tensorflow/' "$MODIFIED_YML"
fi

# Remove packages
for pkg in "${REMOVE_PACKAGES[@]}"; do
    print_info "Applying: Remove $pkg..."
    # Escape special regex characters in package name
    escaped_pkg=$(printf '%s\n' "$pkg" | sed 's/[.[\*^$]/\\&/g')
    # Remove from conda dependencies
    sed_inplace "/^  - ${escaped_pkg}/d" "$MODIFIED_YML"
    # Remove from pip dependencies
    sed_inplace "/    - ${escaped_pkg}/d" "$MODIFIED_YML"
done

# Add packages
if [[ ${#ADD_PACKAGES[@]} -gt 0 ]]; then
    print_info "Applying: Add packages..."
    for pkg in "${ADD_PACKAGES[@]}"; do
        # Escape special characters for sed
        escaped_pkg=$(printf '%s\n' "$pkg" | sed 's/[\/&]/\\&/g')
        # Add to conda dependencies (after dependencies: line)
        sed_inplace "/^dependencies:/a\\  - $escaped_pkg" "$MODIFIED_YML"
    done
fi

echo ""

# Show diff if modifications were made
if [[ "$HAS_MODIFICATIONS" == true ]]; then
    print_header "Changes Preview"
    echo ""
    print_info "Key changes in environment specification:"
    echo ""

    # Show Python version change
    if [[ -n "$PYTHON_VERSION" ]]; then
        echo "Python:"
        grep "python=" "$TEMP_YML" | head -1 || true
        echo "  ↓"
        grep "python=" "$MODIFIED_YML" | head -1 || true
        echo ""
    fi

    # Show framework changes
    if [[ -n "$SWAP_FRAMEWORK" ]]; then
        echo "ML Framework:"
        grep -E "(pytorch|tensorflow|jax)" "$TEMP_YML" | head -3 || echo "  (none)"
        echo "  ↓"
        grep -E "(pytorch|tensorflow|jax)" "$MODIFIED_YML" | head -3 || echo "  (none)"
        echo ""
    fi

    echo ""
fi

# Confirm cloning
if [[ "$SKIP_CONFIRM" == false ]]; then
    read -p "Proceed with cloning? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cloning cancelled"
        exit 0
    fi
    echo ""
fi

# Create new environment from modified YAML
print_header "Creating Environment"
echo ""
print_info "Creating '$NEW_ENV' from modified specification..."
echo ""

if conda env create -n "$NEW_ENV" -f "$MODIFIED_YML"; then
    echo ""
    print_success "Environment cloned successfully!"
    echo ""
    print_info "New environment: $NEW_ENV"
    print_info "Activate with: conda activate $NEW_ENV"
    echo ""

    # Show package count
    pkg_count=$(conda list -n "$NEW_ENV" | grep -vc "^#")
    print_info "Total packages: $pkg_count"
    echo ""
else
    echo ""
    print_error "Environment creation failed"
    print_warning "The modified specification may have conflicts"
    print_info "Check the temporary file for details: $MODIFIED_YML"
    # Don't delete temp file on error
    trap - EXIT
    echo ""
    exit 1
fi
