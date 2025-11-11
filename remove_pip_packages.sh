#!/bin/bash

# Script to remove all pip-installed packages from a conda environment
# Usage: ./remove_pip_packages.sh [conda_env_name] [--yes]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
CONDA_ENV=""
AUTO_YES=false

for arg in "$@"; do
    if [[ "$arg" == "--yes" ]] || [[ "$arg" == "-y" ]]; then
        AUTO_YES=true
    else
        CONDA_ENV="$arg"
    fi
done

# Function to check if conda is available
check_conda() {
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Error: conda is not installed or not in PATH${NC}"
        exit 1
    fi
}

# Function to activate conda environment
activate_env() {
    if [ -n "$CONDA_ENV" ]; then
        echo -e "${GREEN}Activating conda environment: $CONDA_ENV${NC}"
        eval "$(conda shell.bash hook)"
        conda activate "$CONDA_ENV"
    else
        echo -e "${YELLOW}Using current conda environment: ${CONDA_DEFAULT_ENV:-base}${NC}"
    fi
}

# Function to get pip packages
get_pip_packages() {
    # Get all pip packages excluding essential ones
    # Handle both standard (pkg==ver) and URL (pkg @ url) formats
    pip freeze | \
        grep -v "^-e" | \
        sed 's/ @.*//' | \
        sed 's/==.*//' | \
        grep -v "^$" | \
        grep -v -E "^(pip|setuptools|wheel)$"
}

# Function to remove packages
remove_packages() {
    local packages="$1"

    if [ -z "$packages" ]; then
        echo -e "${YELLOW}No pip packages to remove.${NC}"
        exit 0
    fi

    echo -e "${GREEN}Found the following pip packages:${NC}"
    echo "$packages"
    echo ""

    # Count packages
    local count=$(echo "$packages" | wc -l)
    echo -e "${YELLOW}Total packages to remove: $count${NC}"
    echo ""

    # Confirm removal
    if [ "$AUTO_YES" = false ]; then
        read -p "Do you want to remove these packages? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Aborted.${NC}"
            exit 0
        fi
    fi

    # Remove packages
    echo -e "${GREEN}Removing packages...${NC}"
    echo "$packages" | xargs -r pip uninstall -y

    echo -e "${GREEN}Successfully removed all pip packages!${NC}"
}

# Main execution
main() {
    check_conda
    activate_env

    echo -e "${GREEN}Collecting pip-installed packages...${NC}"
    packages=$(get_pip_packages)

    remove_packages "$packages"
}

# Run main function
main
