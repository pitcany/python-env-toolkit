#!/usr/bin/env bash

# safe_install.sh - Safe package installation with dry-run preview and auto-rollback
#
# Usage:
#   ./safe_install.sh [OPTIONS] <package1> [package2 ...]
#
# Options:
#   --dry-run           Only show what would be installed/changed (no actual install)
#   --pip               Use pip instead of conda
#   --yes               Skip confirmation prompts
#   --no-snapshot       Don't create conda revision snapshot before install
#   --help, -h          Show this help message
#
# Description:
#   Safely install packages with preview and rollback capabilities:
#   1. Shows dry-run preview of what will change
#   2. Creates conda revision snapshot (automatic rollback point)
#   3. Performs installation
#   4. Offers instant rollback if problems occur

set -euo pipefail

# Signal handler for Ctrl+C
cleanup() {
    echo ""
    echo -e "\033[1;33m⚠️  Installation interrupted by user\033[0m"
    echo "If packages were partially installed, you can rollback with:"
    echo "  ./conda_rollback.sh"
    exit 130
}
trap cleanup INT TERM

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
DRY_RUN=false
USE_PIP=false
SKIP_CONFIRM=false
CREATE_SNAPSHOT=true
PACKAGES=()

# Function to print colored output
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --pip)
            USE_PIP=true
            shift
            ;;
        --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        --no-snapshot)
            CREATE_SNAPSHOT=false
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
            PACKAGES+=("$1")
            shift
            ;;
    esac
done

# Validate inputs
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    print_error "No packages specified"
    echo "Usage: $0 [OPTIONS] <package1> [package2 ...]"
    echo "Use --help for more information"
    exit 1
fi

# Check if conda is available (unless using pip only)
if [[ "$USE_PIP" == false ]]; then
    if ! command -v conda &> /dev/null; then
        print_error "conda command not found"
        exit 1
    fi
fi

# Check if pip is available (if using pip)
if [[ "$USE_PIP" == true ]]; then
    if ! command -v pip &> /dev/null; then
        print_error "pip command not found"
        exit 1
    fi
fi

# Check if an environment is active
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
    print_error "No conda environment is active (or base is active)"
    echo "Please activate an environment first: conda activate <env_name>"
    exit 1
fi

ENV_NAME="${CONDA_DEFAULT_ENV}"

echo ""
print_header "Safe Package Installation"
echo ""
print_info "Environment: ${ENV_NAME}"
print_info "Package manager: $([ "$USE_PIP" == true ] && echo "pip" || echo "conda")"
print_info "Packages to install: ${PACKAGES[*]}"
echo ""

# Step 1: Dry-run preview
print_header "Step 1: Preview Changes"
echo ""

if [[ "$USE_PIP" == true ]]; then
    print_info "Running pip dry-run to preview changes..."
    echo ""

    # pip doesn't have a true dry-run, but we can use --dry-run for some info
    # Better approach: use pip install --dry-run or pip-compile
    for pkg in "${PACKAGES[@]}"; do
        echo -e "${CYAN}Preview for: ${pkg}${NC}"
        pip install --dry-run --ignore-installed "$pkg" 2>&1 || true
        echo ""
    done
else
    print_info "Running conda dry-run to preview changes..."
    echo ""

    # Conda dry-run
    if conda install --dry-run --name "${ENV_NAME}" "${PACKAGES[@]}" 2>&1; then
        print_success "Dry-run completed successfully"
    else
        exit_code=$?
        print_error "Dry-run failed - conflicts detected!"
        echo ""
        print_warning "The packages you want to install have conflicts with your current environment."
        exit $exit_code
    fi
fi

echo ""

# Exit if only dry-run requested
if [[ "$DRY_RUN" == true ]]; then
    print_info "Dry-run mode: No changes made"
    exit 0
fi

# Step 2: Confirm installation
if [[ "$SKIP_CONFIRM" == false ]]; then
    echo ""
    print_warning "Review the changes above."
    read -p "Proceed with installation? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
fi

# Step 3: Create snapshot (conda only)
SNAPSHOT_CREATED=false
if [[ "$USE_PIP" == false ]] && [[ "$CREATE_SNAPSHOT" == true ]]; then
    echo ""
    print_header "Step 2: Creating Snapshot"
    echo ""

    # Get current revision
    BEFORE_REVISION=$(conda list --revisions | grep "^rev" | tail -1 | awk '{print $2}')
    print_info "Current revision: ${BEFORE_REVISION}"
    print_success "Conda will automatically create a new revision point"
    SNAPSHOT_CREATED=true
    echo ""
fi

# Step 4: Install packages
echo ""
print_header "Step $([ "$SNAPSHOT_CREATED" == true ] && echo "3" || echo "2"): Installing Packages"
echo ""

INSTALL_SUCCESS=false

if [[ "$USE_PIP" == true ]]; then
    print_info "Installing with pip..."
    echo ""

    if pip install "${PACKAGES[@]}"; then
        INSTALL_SUCCESS=true
        echo ""
        print_success "Installation completed successfully!"
    else
        echo ""
        print_error "Installation failed!"
    fi
else
    print_info "Installing with conda..."
    echo ""

    if conda install --name "${ENV_NAME}" --yes "${PACKAGES[@]}"; then
        INSTALL_SUCCESS=true
        echo ""
        print_success "Installation completed successfully!"
    else
        echo ""
        print_error "Installation failed!"
    fi
fi

echo ""

# Step 5: Offer rollback if available and installation succeeded
if [[ "$INSTALL_SUCCESS" == true ]] && [[ "$SNAPSHOT_CREATED" == true ]]; then
    AFTER_REVISION=$(conda list --revisions | grep "^rev" | tail -1 | awk '{print $2}')

    print_header "Step 4: Post-Installation"
    echo ""
    print_info "New revision: ${AFTER_REVISION}"
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "If you encounter any issues, you can rollback with:"
    echo -e "  ${CYAN}conda install --revision ${BEFORE_REVISION}${NC}"
    echo ""
    echo "Or use the rollback script:"
    echo -e "  ${CYAN}./conda_rollback.sh${NC}"
    echo ""
elif [[ "$INSTALL_SUCCESS" == true ]]; then
    print_success "Installation complete!"
    echo ""
    if [[ "$USE_PIP" == true ]]; then
        print_info "Note: pip doesn't support automatic snapshots"
        print_warning "Consider using 'pip freeze > backup.txt' before major changes"
    fi
    echo ""
elif [[ "$SNAPSHOT_CREATED" == true ]]; then
    # Installation failed, offer immediate rollback
    echo ""
    print_warning "Installation failed. Your environment may be in an inconsistent state."
    echo ""

    if [[ "$SKIP_CONFIRM" == false ]]; then
        read -p "Rollback to revision ${BEFORE_REVISION}? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Rolling back to revision ${BEFORE_REVISION}..."
            conda install --name "${ENV_NAME}" --revision "${BEFORE_REVISION}" --yes
            print_success "Rollback complete! Environment restored."
        else
            print_info "Skipped rollback. You can manually rollback with:"
            echo -e "  ${CYAN}conda install --revision ${BEFORE_REVISION}${NC}"
        fi
    else
        print_info "Auto-rollback skipped in non-interactive mode"
        print_info "Manual rollback: conda install --revision ${BEFORE_REVISION}"
    fi
    echo ""
    exit 1
else
    print_error "Installation failed"
    exit 1
fi
