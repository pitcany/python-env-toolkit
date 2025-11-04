#!/usr/bin/env bash

# clean_poetry_env.sh
# Removes and recreates Poetry virtual environment to reset to defaults
# Allows fresh reinstallation from pyproject.toml file
#
# Usage:
#   ./clean_poetry_env.sh [OPTIONS]
#
# Options:
#   --yes, -y           Skip confirmation prompts
#   --keep-lock         Keep poetry.lock file (default: prompt to remove)
#   --no-install        Don't reinstall dependencies after cleaning
#   --help, -h          Show this help message

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
SKIP_CONFIRM=false
KEEP_LOCK=false
NO_INSTALL=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
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

# Function to show help
show_help() {
    cat << EOF
clean_poetry_env.sh - Clean and reset Poetry virtual environment

Usage:
    ./clean_poetry_env.sh [OPTIONS]

Description:
    Removes the Poetry virtual environment and optionally the lock file,
    then recreates a fresh environment. This allows you to reinstall
    dependencies from scratch using pyproject.toml.

Options:
    --yes, -y           Skip all confirmation prompts
    --keep-lock         Keep poetry.lock file (don't prompt to remove)
    --no-install        Don't reinstall dependencies after cleaning
    --help, -h          Show this help message

Examples:
    # Interactive mode (prompts for confirmation)
    ./clean_poetry_env.sh

    # Non-interactive mode with automatic reinstall
    ./clean_poetry_env.sh --yes

    # Clean but don't reinstall yet
    ./clean_poetry_env.sh --no-install

    # Keep lock file and reinstall
    ./clean_poetry_env.sh --keep-lock
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --keep-lock)
            KEEP_LOCK=true
            shift
            ;;
        --no-install)
            NO_INSTALL=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if Poetry is installed
if ! command -v poetry &> /dev/null; then
    print_error "Poetry is not installed or not in PATH"
    echo "Install Poetry from: https://python-poetry.org/docs/#installation"
    exit 1
fi

# Check if pyproject.toml exists
if [[ ! -f "pyproject.toml" ]]; then
    print_error "No pyproject.toml found in current directory"
    echo "Please run this script from a Poetry project directory"
    exit 1
fi

print_info "Poetry environment cleanup utility"
echo ""

# Get Poetry environment info
print_info "Detecting Poetry environment..."
if poetry env info --path &> /dev/null; then
    env_path=$(poetry env info --path)
    env_name=$(basename "$env_path")
    python_version=$(poetry env info --python 2>/dev/null || echo "unknown")

    print_success "Found Poetry environment:"
    echo "  Name: $env_name"
    echo "  Path: $env_path"
    echo "  Python: $python_version"
else
    print_warning "No Poetry environment found"
    echo "Nothing to clean. Run 'poetry install' to create an environment."
    exit 0
fi

echo ""

# Check for poetry.lock
lock_file_exists=false
if [[ -f "poetry.lock" ]]; then
    lock_file_exists=true
    print_info "Found poetry.lock file"
fi

echo ""

# Confirm removal
if [[ "$SKIP_CONFIRM" == false ]]; then
    print_warning "This will remove the Poetry virtual environment:"
    echo "  $env_path"
    echo ""
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
fi

# Remove Poetry environment
print_info "Removing Poetry environment..."
if poetry env remove --all &> /dev/null; then
    print_success "Poetry environment removed successfully"
else
    # Try alternative method if --all doesn't work
    if poetry env remove python &> /dev/null; then
        print_success "Poetry environment removed successfully"
    else
        print_error "Failed to remove Poetry environment"
        exit 1
    fi
fi

# Handle poetry.lock file
remove_lock=false
if [[ "$lock_file_exists" == true && "$KEEP_LOCK" == false ]]; then
    echo ""
    if [[ "$SKIP_CONFIRM" == false ]]; then
        print_warning "Found poetry.lock file"
        echo "Removing it will cause Poetry to resolve dependencies from scratch."
        echo "Keeping it will reinstall the exact same versions."
        echo ""
        read -p "Remove poetry.lock? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_lock=true
        fi
    else
        # In non-interactive mode, keep lock by default
        print_info "Keeping poetry.lock file (use --keep-lock to suppress this message)"
    fi

    if [[ "$remove_lock" == true ]]; then
        rm -f poetry.lock
        print_success "Removed poetry.lock"
    else
        print_info "Kept poetry.lock"
    fi
fi

# Reinstall dependencies
if [[ "$NO_INSTALL" == false ]]; then
    echo ""
    print_info "Creating fresh Poetry environment and installing dependencies..."
    echo ""

    if poetry install; then
        echo ""
        print_success "Poetry environment recreated successfully!"

        # Show new environment info
        new_env_path=$(poetry env info --path)
        new_python=$(poetry env info --python 2>/dev/null || echo "unknown")
        echo ""
        print_info "New environment details:"
        echo "  Path: $new_env_path"
        echo "  Python: $new_python"
    else
        echo ""
        print_error "Failed to install dependencies"
        echo "You can try manually with: poetry install"
        exit 1
    fi
else
    echo ""
    print_success "Environment cleaned!"
    print_info "Run 'poetry install' when ready to recreate the environment"
fi

echo ""
print_success "Done! 🎉"
