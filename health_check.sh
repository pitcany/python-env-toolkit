#!/usr/bin/env bash

# health_check.sh - Comprehensive environment health diagnostics
#
# Usage:
#   ./health_check.sh [env_name] [OPTIONS]
#
# Arguments:
#   env_name            Environment to check (uses active env if not specified)
#
# Options:
#   --quick             Quick check (skip detailed package analysis)
#   --gpu-only          Only check GPU/CUDA setup
#   --verbose           Show detailed output
#   --help, -h          Show this help message
#
# Description:
#   Comprehensive diagnostics for ML/data science environments:
#   - GPU/CUDA/cuDNN validation and compatibility
#   - ML framework configuration (PyTorch, TensorFlow, JAX)
#   - Common package conflict detection
#   - Jupyter kernel status
#   - Disk space analysis
#   - Python version and critical packages
#   - Environment health score

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default options
TARGET_ENV=""
QUICK_MODE=false
GPU_ONLY=false
VERBOSE=false

# Health score tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Functions for colored output
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "${MAGENTA}▶ $1${NC}"
}

print_info() {
    echo -e "${CYAN}  ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}  ❌ $1${NC}"
}

check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    print_success "$1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    print_error "$1"
}

check_warn() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    print_warning "$1"
}

# Show help
show_help() {
    grep "^#" "$0" | grep -v "^#!/" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --gpu-only)
            GPU_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
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

# Determine environment
if [[ -n "$TARGET_ENV" ]]; then
    ENV_NAME="$TARGET_ENV"
else
    if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
        echo "🚫 Error: No environment specified and no environment is active"
        echo "Usage: $0 [env_name]"
        exit 1
    fi
    ENV_NAME="${CONDA_DEFAULT_ENV}"
fi

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "🚫 Error: conda command not found"
    exit 1
fi

# Validate environment exists
if ! conda env list | grep -q "^${ENV_NAME} "; then
    echo "🚫 Error: Environment '${ENV_NAME}' not found"
    exit 1
fi

# Get environment path
ENV_PATH=$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')
PYTHON_CMD="$ENV_PATH/bin/python"

if [[ ! -f "$PYTHON_CMD" ]]; then
    echo "🚫 Error: Python not found in environment"
    exit 1
fi

echo ""
print_header "Environment Health Check"
echo ""
echo -e "${CYAN}Environment: ${ENV_NAME}${NC}"
echo -e "${CYAN}Location: ${ENV_PATH}${NC}"
echo ""

# ============================================================================
# GPU / CUDA / cuDNN Check
# ============================================================================
print_section "GPU & CUDA Configuration"
echo ""

# Check NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | head -1)
    if [[ -n "$gpu_info" ]]; then
        check_pass "NVIDIA GPU detected"
        if [[ "$VERBOSE" == true ]]; then
            print_info "GPU: $gpu_info"
        fi

        # Get CUDA version from nvidia-smi
        cuda_version=$(nvidia-smi | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/' || echo "unknown")
        if [[ "$cuda_version" != "unknown" ]]; then
            check_pass "CUDA driver: $cuda_version"
        else
            check_warn "CUDA driver version not detected"
        fi
    else
        check_warn "nvidia-smi found but no GPU info"
    fi
else
    check_warn "No NVIDIA GPU detected (nvidia-smi not found)"
fi

# Check CUDA toolkit in environment
cuda_env=$("$PYTHON_CMD" -c "import os; print(os.environ.get('CUDA_HOME', 'not set'))" 2>/dev/null || echo "not set")
if [[ "$cuda_env" != "not set" ]]; then
    check_pass "CUDA_HOME set: $cuda_env"
else
    if conda list -n "$ENV_NAME" | grep -q "cudatoolkit"; then
        cuda_pkg_ver=$(conda list -n "$ENV_NAME" | grep "^cudatoolkit" | awk '{print $2}')
        check_pass "CUDA toolkit installed: $cuda_pkg_ver"
    else
        print_info "No CUDA toolkit in environment (CPU-only setup)"
    fi
fi

# Check PyTorch CUDA
if "$PYTHON_CMD" -c "import torch" 2>/dev/null; then
    pytorch_cuda=$("$PYTHON_CMD" -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
    if [[ "$pytorch_cuda" == "True" ]]; then
        pytorch_cuda_ver=$("$PYTHON_CMD" -c "import torch; print(torch.version.cuda)" 2>/dev/null)
        check_pass "PyTorch CUDA available: $pytorch_cuda_ver"

        # Check if GPU is actually accessible
        gpu_count=$("$PYTHON_CMD" -c "import torch; print(torch.cuda.device_count())" 2>/dev/null)
        check_pass "PyTorch GPU count: $gpu_count"
    else
        check_warn "PyTorch installed but CUDA not available (CPU-only)"
    fi
fi

# Check TensorFlow GPU
if "$PYTHON_CMD" -c "import tensorflow as tf" 2>/dev/null; then
    tf_gpu=$("$PYTHON_CMD" -c "import tensorflow as tf; print(len(tf.config.list_physical_devices('GPU')))" 2>/dev/null)
    if [[ "$tf_gpu" -gt 0 ]]; then
        check_pass "TensorFlow GPU available: $tf_gpu device(s)"
    else
        check_warn "TensorFlow installed but no GPU devices (CPU-only)"
    fi
fi

echo ""

# Exit early if GPU-only mode
if [[ "$GPU_ONLY" == true ]]; then
    print_header "Health Check Complete (GPU-only mode)"
    echo ""
    exit 0
fi

# ============================================================================
# Python & Core Packages
# ============================================================================
print_section "Python & Core Packages"
echo ""

# Python version
python_ver=$("$PYTHON_CMD" --version 2>&1 | awk '{print $2}')
check_pass "Python: $python_ver"

# Check important packages
important_packages=("numpy" "pandas" "matplotlib" "scikit-learn" "jupyter")
for pkg in "${important_packages[@]}"; do
    if "$PYTHON_CMD" -c "import $pkg" 2>/dev/null; then
        pkg_ver=$("$PYTHON_CMD" -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "unknown")
        if [[ "$VERBOSE" == true ]]; then
            print_success "$pkg: $pkg_ver"
        fi
    fi
done

echo ""

# ============================================================================
# ML Frameworks
# ============================================================================
print_section "ML Frameworks"
echo ""

# PyTorch
if "$PYTHON_CMD" -c "import torch" 2>/dev/null; then
    torch_ver=$("$PYTHON_CMD" -c "import torch; print(torch.__version__)" 2>/dev/null)
    check_pass "PyTorch: $torch_ver"
else
    print_info "PyTorch: not installed"
fi

# TensorFlow
if "$PYTHON_CMD" -c "import tensorflow as tf" 2>/dev/null; then
    tf_ver=$("$PYTHON_CMD" -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    check_pass "TensorFlow: $tf_ver"
else
    print_info "TensorFlow: not installed"
fi

# JAX
if "$PYTHON_CMD" -c "import jax" 2>/dev/null; then
    jax_ver=$("$PYTHON_CMD" -c "import jax; print(jax.__version__)" 2>/dev/null)
    check_pass "JAX: $jax_ver"
else
    print_info "JAX: not installed"
fi

echo ""

# ============================================================================
# Package Conflicts
# ============================================================================
if [[ "$QUICK_MODE" == false ]]; then
    print_section "Package Conflict Detection"
    echo ""

    # Check for conda/pip duplicates
    duplicate_count=0
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/find_duplicates.sh" ]]; then
        # Run find_duplicates silently and count
        duplicate_output=$("$SCRIPT_DIR/find_duplicates.sh" "$ENV_NAME" 2>/dev/null | grep "Found.*package" || echo "")
        if [[ "$duplicate_output" =~ Found\ ([0-9]+)\ package ]]; then
            duplicate_count="${BASH_REMATCH[1]}"
        fi
    fi

    if [[ $duplicate_count -eq 0 ]]; then
        check_pass "No conda/pip duplicates found"
    else
        check_warn "Found $duplicate_count package(s) in both conda and pip"
        print_info "Run './find_duplicates.sh $ENV_NAME' for details"
    fi

    # Check for known problematic combinations
    has_pytorch=$("$PYTHON_CMD" -c "import torch; print('yes')" 2>/dev/null || echo "no")
    has_tensorflow=$("$PYTHON_CMD" -c "import tensorflow; print('yes')" 2>/dev/null || echo "no")

    if [[ "$has_pytorch" == "yes" ]] && [[ "$has_tensorflow" == "yes" ]]; then
        check_warn "Both PyTorch and TensorFlow installed (potential conflicts)"
        print_info "Consider using separate environments for each framework"
    fi

    echo ""
fi

# ============================================================================
# Jupyter Integration
# ============================================================================
print_section "Jupyter Integration"
echo ""

# Check if ipykernel is installed
if "$PYTHON_CMD" -c "import ipykernel" 2>/dev/null; then
    check_pass "ipykernel installed"

    # Check if registered as Jupyter kernel
    if command -v jupyter &> /dev/null; then
        if jupyter kernelspec list 2>/dev/null | grep -q "$ENV_NAME"; then
            check_pass "Registered as Jupyter kernel"
        else
            check_warn "Not registered as Jupyter kernel"
            print_info "Run './manage_jupyter_kernels.sh add $ENV_NAME' to register"
        fi
    fi
else
    check_warn "ipykernel not installed (Jupyter notebooks won't work)"
    print_info "Install with: conda install -n $ENV_NAME ipykernel"
fi

echo ""

# ============================================================================
# Disk Space
# ============================================================================
print_section "Disk Space"
echo ""

# Environment size
if command -v du &> /dev/null; then
    env_size=$(du -sh "$ENV_PATH" 2>/dev/null | awk '{print $1}')
    print_info "Environment size: $env_size"
fi

# Conda cache
conda_cache_size=$(du -sh "$(conda info --base)/pkgs" 2>/dev/null | awk '{print $1}' || echo "unknown")
print_info "Conda cache: $conda_cache_size"

# Available disk space
if command -v df &> /dev/null; then
    disk_avail=$(df -h "$ENV_PATH" | tail -1 | awk '{print $4}')
    disk_percent=$(df -h "$ENV_PATH" | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ $disk_percent -gt 90 ]]; then
        check_warn "Disk usage high: ${disk_percent}% used (${disk_avail} available)"
    else
        check_pass "Disk space OK: ${disk_avail} available"
    fi
fi

echo ""

# ============================================================================
# Package Count & Statistics
# ============================================================================
if [[ "$QUICK_MODE" == false ]]; then
    print_section "Package Statistics"
    echo ""

    conda_pkg_count=$(conda list -n "$ENV_NAME" --no-pip 2>/dev/null | grep -v "^#" | wc -l)
    pip_pkg_count=$(conda list -n "$ENV_NAME" --export 2>/dev/null | grep "# pip" | wc -l || echo "0")

    print_info "Conda packages: $conda_pkg_count"
    print_info "Pip packages: $pip_pkg_count"
    print_info "Total packages: $((conda_pkg_count + pip_pkg_count))"

    echo ""
fi

# ============================================================================
# Health Score Summary
# ============================================================================
print_header "Health Check Summary"
echo ""

# Calculate score
if [[ $TOTAL_CHECKS -gt 0 ]]; then
    score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    score=0
fi

echo -e "${CYAN}Checks performed: $TOTAL_CHECKS${NC}"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

# Overall health status
if [[ $score -ge 90 ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Health Score: ${score}% - EXCELLENT${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
elif [[ $score -ge 70 ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Health Score: ${score}% - GOOD${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  Health Score: ${score}% - NEEDS ATTENTION${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo ""

# Exit with appropriate code
if [[ $FAILED_CHECKS -gt 0 ]]; then
    exit 1
else
    exit 0
fi
