#!/usr/bin/env bash

# create_ml_env.sh - Quick ML environment creation from templates
#
# Usage:
#   ./create_ml_env.sh <env_name> --template <template_name> [OPTIONS]
#
# Required:
#   env_name                Name for the new environment
#   --template <name>       Template to use (see list below)
#
# Options:
#   --python <version>      Python version (default: 3.10)
#   --add <package>         Add extra packages (can be used multiple times)
#   --register-kernel       Auto-register as Jupyter kernel
#   --yes                   Skip confirmation prompts
#   --help, -h              Show this help message
#
# Available Templates:
#   pytorch-cpu             PyTorch (CPU-only) + common ML libraries
#   pytorch-gpu             PyTorch (CUDA) + common ML libraries
#   tensorflow-cpu          TensorFlow (CPU-only) + common ML libraries
#   tensorflow-gpu          TensorFlow (GPU) + common ML libraries
#   jax-cpu                 JAX (CPU-only) + common ML libraries
#   jax-gpu                 JAX (GPU) + common ML libraries
#   data-science            Pandas, NumPy, Scikit-learn, Matplotlib, Seaborn
#   deep-learning           PyTorch + TensorFlow + visualization
#   nlp                     Transformers, spaCy, NLTK + PyTorch
#   cv                      Computer Vision: PyTorch, OpenCV, PIL, torchvision
#   minimal                 Minimal Python environment
#
# Description:
#   Quickly create pre-configured ML/data science environments with proper
#   CUDA versions, framework compatibility, and common packages.
#
# Examples:
#   # PyTorch GPU environment
#   ./create_ml_env.sh ml-project --template pytorch-gpu
#
#   # Data science with extra packages
#   ./create_ml_env.sh analysis --template data-science --add plotly --add dash
#
#   # NLP environment with Jupyter kernel
#   ./create_ml_env.sh nlp-research --template nlp --register-kernel

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
ENV_NAME=""
TEMPLATE=""
PYTHON_VERSION="3.10"
EXTRA_PACKAGES=()
REGISTER_KERNEL=false
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
        --template)
            TEMPLATE="$2"
            shift 2
            ;;
        --python)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        --add)
            EXTRA_PACKAGES+=("$2")
            shift 2
            ;;
        --register-kernel)
            REGISTER_KERNEL=true
            shift
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
            if [[ -z "$ENV_NAME" ]]; then
                ENV_NAME="$1"
            else
                print_error "Too many positional arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate inputs
if [[ -z "$ENV_NAME" ]]; then
    print_error "No environment name specified"
    echo "Usage: $0 <env_name> --template <template_name>"
    echo "Use --help for more information"
    exit 1
fi

if [[ -z "$TEMPLATE" ]]; then
    print_error "No template specified"
    echo "Use --template <name> to specify a template"
    echo "Use --help to see available templates"
    exit 1
fi

# Check if conda is available
if ! command -v conda &> /dev/null; then
    print_error "conda command not found"
    exit 1
fi

# Check if environment already exists
if conda env list | grep -q "^${ENV_NAME} "; then
    print_error "Environment '${ENV_NAME}' already exists"
    exit 1
fi

echo ""
print_header "ML Environment Creation"
echo ""
print_info "Environment: $ENV_NAME"
print_info "Template: $TEMPLATE"
print_info "Python: $PYTHON_VERSION"
if [[ ${#EXTRA_PACKAGES[@]} -gt 0 ]]; then
    print_info "Extra packages: ${EXTRA_PACKAGES[*]}"
fi
echo ""

# Define template packages
declare -A TEMPLATES

TEMPLATES["pytorch-cpu"]="pytorch torchvision torchaudio cpuonly numpy pandas matplotlib scikit-learn jupyter ipykernel"
TEMPLATES["pytorch-gpu"]="pytorch torchvision torchaudio pytorch-cuda=11.8 numpy pandas matplotlib scikit-learn jupyter ipykernel -c pytorch -c nvidia"
TEMPLATES["tensorflow-cpu"]="tensorflow numpy pandas matplotlib scikit-learn jupyter ipykernel"
TEMPLATES["tensorflow-gpu"]="tensorflow-gpu numpy pandas matplotlib scikit-learn jupyter ipykernel"
TEMPLATES["jax-cpu"]="numpy pandas matplotlib scikit-learn jupyter ipykernel pip:jax pip:jaxlib"
TEMPLATES["jax-gpu"]="numpy pandas matplotlib scikit-learn jupyter ipykernel pip:jax[cuda11_pip] pip:jaxlib"
TEMPLATES["data-science"]="numpy pandas matplotlib seaborn scikit-learn scipy statsmodels jupyter ipykernel plotly openpyxl xlrd"
TEMPLATES["deep-learning"]="pytorch torchvision tensorflow numpy pandas matplotlib seaborn scikit-learn jupyter ipykernel tensorboard"
TEMPLATES["nlp"]="pytorch transformers tokenizers datasets spacy nltk numpy pandas matplotlib jupyter ipykernel"
TEMPLATES["cv"]="pytorch torchvision opencv pillow scikit-image albumentations numpy pandas matplotlib jupyter ipykernel"
TEMPLATES["minimal"]="numpy pandas matplotlib jupyter ipykernel"

# Validate template exists
if [[ ! -v "TEMPLATES[$TEMPLATE]" ]]; then
    print_error "Unknown template: $TEMPLATE"
    echo ""
    echo "Available templates:"
    for tmpl in "${!TEMPLATES[@]}"; do
        echo "  - $tmpl"
    done | sort
    exit 1
fi

# Get packages for template
TEMPLATE_PACKAGES="${TEMPLATES[$TEMPLATE]}"

# Show what will be installed
print_header "Package List"
echo ""
print_info "The following packages will be installed:"
echo ""

# Parse and display packages
conda_packages=()
pip_packages=()
conda_channels=()

for pkg in $TEMPLATE_PACKAGES; do
    if [[ $pkg == pip:* ]]; then
        pip_pkg="${pkg#pip:}"
        pip_packages+=("$pip_pkg")
        echo "  📦 $pip_pkg (pip)"
    elif [[ $pkg == -c ]]; then
        continue
    elif [[ ${#conda_packages[@]} -gt 0 ]] && [[ "${conda_packages[-1]}" == "-c" ]]; then
        conda_channels+=("$pkg")
    else
        conda_packages+=("$pkg")
        echo "  📦 $pkg (conda)"
    fi
done

# Add extra packages
for pkg in "${EXTRA_PACKAGES[@]}"; do
    conda_packages+=("$pkg")
    echo "  📦 $pkg (conda, extra)"
done

echo ""

# Confirm creation
if [[ "$SKIP_CONFIRM" == false ]]; then
    read -p "Create environment '$ENV_NAME'? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Environment creation cancelled"
        exit 0
    fi
    echo ""
fi

# Create environment
print_header "Creating Environment"
echo ""
print_info "Creating conda environment with Python $PYTHON_VERSION..."
echo ""

# Build conda command as array (safer than eval)
conda_cmd=(conda create -n "$ENV_NAME" "python=$PYTHON_VERSION")

# Add channels if specified (must come before packages)
if [[ ${#conda_channels[@]} -gt 0 ]]; then
    for channel in "${conda_channels[@]}"; do
        conda_cmd+=(-c "$channel")
    done
fi

# Add conda packages
if [[ ${#conda_packages[@]} -gt 0 ]]; then
    conda_cmd+=("${conda_packages[@]}")
fi

# Add -y flag
conda_cmd+=(-y)

# Execute conda create
if "${conda_cmd[@]}"; then
    echo ""
    print_success "Conda packages installed successfully!"
else
    echo ""
    print_error "Failed to create environment"
    exit 1
fi

# Install pip packages if any
if [[ ${#pip_packages[@]} -gt 0 ]]; then
    echo ""
    print_info "Installing pip packages..."
    echo ""

    ENV_PATH=$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')
    PIP_CMD="$ENV_PATH/bin/pip"

    if "$PIP_CMD" install "${pip_packages[@]}"; then
        print_success "Pip packages installed successfully!"
    else
        print_error "Failed to install pip packages"
        echo ""
        print_warning "Environment created but some pip packages failed"
    fi
fi

echo ""

# Register Jupyter kernel if requested
if [[ "$REGISTER_KERNEL" == true ]]; then
    print_header "Registering Jupyter Kernel"
    echo ""
    print_info "Registering environment as Jupyter kernel..."

    ENV_PATH=$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')
    PYTHON_CMD="$ENV_PATH/bin/python"

    if "$PYTHON_CMD" -m ipykernel install --user --name="$ENV_NAME" --display-name="Python ($ENV_NAME)"; then
        print_success "Jupyter kernel registered!"
    else
        print_warning "Failed to register Jupyter kernel"
    fi
    echo ""
fi

# Run health check if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/health_check.sh" ]]; then
    print_header "Running Health Check"
    echo ""
    "$SCRIPT_DIR/health_check.sh" "$ENV_NAME" --quick || true
    echo ""
fi

# Final summary
print_header "Environment Ready!"
echo ""
print_success "Environment '$ENV_NAME' created successfully!"
echo ""
print_info "Next steps:"
echo "  1. Activate: conda activate $ENV_NAME"

if [[ "$REGISTER_KERNEL" == false ]]; then
    echo "  2. (Optional) Register Jupyter kernel:"
    echo "     ./manage_jupyter_kernels.sh add $ENV_NAME"
fi

echo ""
print_info "Package counts:"
pkg_count=$(conda list -n "$ENV_NAME" | grep -vc "^#")
echo "  Total packages: $pkg_count"
echo ""

# Template-specific tips
case "$TEMPLATE" in
    pytorch-*)
        print_info "PyTorch tips:"
        echo "  - Test GPU: python -c 'import torch; print(torch.cuda.is_available())'"
        echo "  - Check version: python -c 'import torch; print(torch.__version__)'"
        ;;
    tensorflow-*)
        print_info "TensorFlow tips:"
        echo "  - Test GPU: python -c 'import tensorflow as tf; print(tf.config.list_physical_devices())'"
        echo "  - Check version: python -c 'import tensorflow as tf; print(tf.__version__)'"
        ;;
    nlp)
        print_info "NLP tips:"
        echo "  - Download spaCy model: python -m spacy download en_core_web_sm"
        echo "  - Download NLTK data: python -c 'import nltk; nltk.download(\"popular\")'"
        ;;
esac

echo ""
