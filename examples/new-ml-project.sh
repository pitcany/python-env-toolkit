#!/usr/bin/env bash

# new-ml-project.sh - Complete workflow for starting a new ML project
#
# This example demonstrates how to chain multiple scripts together to:
# 1. Create a new environment from a template
# 2. Install additional packages safely
# 3. Export environment specs for version control
# 4. Register as Jupyter kernel
# 5. Verify everything works with health check
#
# Usage:
#   cd /path/to/python-env-toolkit
#   ./examples/new-ml-project.sh

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory (parent of examples/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${MAGENTA}▶ Step $1: $2${NC}"
    echo ""
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

# Check if we're in the right directory
if [[ ! -f "$SCRIPT_DIR/create_ml_env.sh" ]]; then
    echo -e "${RED}Error: Cannot find toolkit scripts${NC}"
    echo "Please run this from the python-env-toolkit directory or its examples/ subdirectory"
    exit 1
fi

print_header "New ML Project Workflow"

echo -e "${CYAN}This workflow will guide you through creating a new ML environment.${NC}"
echo ""

# Step 1: Gather information
print_step "1" "Project Configuration"

read -p "Project/Environment name: " PROJECT_NAME

if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "${RED}Error: Project name is required${NC}"
    exit 1
fi

# Check if environment already exists
if conda env list | grep -q "^${PROJECT_NAME} "; then
    echo -e "${RED}Error: Environment '${PROJECT_NAME}' already exists${NC}"
    exit 1
fi

echo ""
echo "Available templates:"
echo "  1) pytorch-gpu       - PyTorch with CUDA support"
echo "  2) pytorch-cpu       - PyTorch CPU-only"
echo "  3) tensorflow-gpu    - TensorFlow with GPU support"
echo "  4) tensorflow-cpu    - TensorFlow CPU-only"
echo "  5) data-science      - Pandas, NumPy, Scikit-learn, Matplotlib"
echo "  6) nlp               - NLP stack with Transformers"
echo "  7) cv                - Computer Vision stack"
echo ""
read -p "Select template (1-7): " TEMPLATE_CHOICE

case $TEMPLATE_CHOICE in
    1) TEMPLATE="pytorch-gpu" ;;
    2) TEMPLATE="pytorch-cpu" ;;
    3) TEMPLATE="tensorflow-gpu" ;;
    4) TEMPLATE="tensorflow-cpu" ;;
    5) TEMPLATE="data-science" ;;
    6) TEMPLATE="nlp" ;;
    7) TEMPLATE="cv" ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
read -p "Python version (default: 3.10): " PYTHON_VERSION
PYTHON_VERSION=${PYTHON_VERSION:-3.10}

echo ""
read -p "Additional packages (comma-separated, or leave empty): " EXTRA_PACKAGES

# Step 2: Create environment
print_step "2" "Creating Environment"

CREATE_CMD="$SCRIPT_DIR/create_ml_env.sh $PROJECT_NAME --template $TEMPLATE --python $PYTHON_VERSION --yes --register-kernel"

echo -e "${CYAN}Running: create_ml_env.sh${NC}"
echo ""

if eval "$CREATE_CMD"; then
    print_success "Environment created successfully!"
else
    echo -e "${RED}Failed to create environment${NC}"
    exit 1
fi

# Step 3: Install additional packages if specified
if [[ -n "$EXTRA_PACKAGES" ]]; then
    print_step "3" "Installing Additional Packages"

    # Convert comma-separated to space-separated
    PACKAGES=$(echo "$EXTRA_PACKAGES" | tr ',' ' ')

    echo -e "${CYAN}Installing: $PACKAGES${NC}"
    echo ""

    # Activate environment and install
    if conda run -n "$PROJECT_NAME" "$SCRIPT_DIR/safe_install.sh" $PACKAGES --yes; then
        print_success "Additional packages installed!"
    else
        print_warning "Some packages failed to install"
    fi
fi

# Step 4: Export environment specs
print_step "4" "Exporting Environment Specifications"

echo -e "${CYAN}Creating environment.yml and requirements.txt for version control${NC}"
echo ""

if conda run -n "$PROJECT_NAME" "$SCRIPT_DIR/export_env.sh" --name "$PROJECT_NAME"; then
    print_success "Environment specs exported!"
    print_info "Files created: environment.yml, requirements.txt"
    echo ""
    print_info "💡 Tip: Add these to your project's git repository"
else
    print_warning "Failed to export environment specs"
fi

# Step 5: Run health check
print_step "5" "Health Check"

echo -e "${CYAN}Verifying environment configuration${NC}"
echo ""

if "$SCRIPT_DIR/health_check.sh" "$PROJECT_NAME"; then
    echo ""
    print_success "Environment is healthy!"
else
    echo ""
    print_warning "Health check found some issues (see above)"
fi

# Final summary
print_header "Setup Complete!"

echo -e "${GREEN}✅ Environment '${PROJECT_NAME}' is ready!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo -e "  1. Activate your environment:"
echo -e "     ${YELLOW}conda activate $PROJECT_NAME${NC}"
echo ""
echo -e "  2. Start Jupyter:"
echo -e "     ${YELLOW}jupyter lab${NC}"
echo -e "     (Your environment will appear as a kernel option)"
echo ""
echo -e "  3. Verify GPU access (if using GPU template):"
if [[ "$TEMPLATE" == *"pytorch"* ]]; then
    echo -e "     ${YELLOW}python -c 'import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")'${NC}"
elif [[ "$TEMPLATE" == *"tensorflow"* ]]; then
    echo -e "     ${YELLOW}python -c 'import tensorflow as tf; print(f\"GPUs: {len(tf.config.list_physical_devices(\"GPU\"))}'${NC}"
fi
echo ""
echo -e "  4. Add environment specs to git:"
echo -e "     ${YELLOW}git add environment.yml requirements.txt${NC}"
echo -e "     ${YELLOW}git commit -m \"Add environment specifications\"${NC}"
echo ""
echo -e "${CYAN}📚 Documentation:${NC}"
echo -e "  - View environment: ${YELLOW}conda list -n $PROJECT_NAME${NC}"
echo -e "  - Health check: ${YELLOW}$SCRIPT_DIR/health_check.sh $PROJECT_NAME${NC}"
echo -e "  - Update packages safely: ${YELLOW}$SCRIPT_DIR/safe_install.sh <package> --dry-run${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
