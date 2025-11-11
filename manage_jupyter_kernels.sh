#!/usr/bin/env bash

# manage_jupyter_kernels.sh - Unified Jupyter kernel management
#
# Usage:
#   ./manage_jupyter_kernels.sh [COMMAND] [OPTIONS]
#
# Commands:
#   list                List all Jupyter kernels and their status
#   add [env_name]      Register environment as Jupyter kernel (uses active env if not specified)
#   remove <kernel>     Remove a specific Jupyter kernel
#   clean               Remove all orphaned kernels
#   sync                Register all conda environments as kernels
#
# Options:
#   --yes               Skip confirmation prompts
#   --display-name      Custom display name for kernel (with 'add' command)
#   --help, -h          Show this help message
#
# Description:
#   Manage Jupyter kernels for conda environments:
#   - Discover all kernels and validate their environment paths
#   - Detect orphaned kernels from deleted environments
#   - Register new environments as kernels
#   - Clean up old/broken kernels

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
COMMAND=""
TARGET_ENV=""
SKIP_CONFIRM=false
DISPLAY_NAME=""

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
        list|add|remove|clean|sync)
            COMMAND="$1"
            shift
            ;;
        --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        --display-name)
            DISPLAY_NAME="$2"
            shift 2
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
            TARGET_ENV="$1"
            shift
            ;;
    esac
done

# Validate command
if [[ -z "$COMMAND" ]]; then
    print_error "No command specified"
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo "Use --help for more information"
    exit 1
fi

# Check dependencies
if ! command -v jupyter &> /dev/null; then
    print_error "jupyter command not found"
    echo "Install Jupyter: pip install jupyter or conda install jupyter"
    exit 1
fi

if ! command -v conda &> /dev/null; then
    print_error "conda command not found"
    exit 1
fi

# Get jupyter kernel directory
KERNEL_DIR=$(jupyter --data-dir)/kernels

# Command: list
if [[ "$COMMAND" == "list" ]]; then
    echo ""
    print_header "Jupyter Kernels"
    echo ""

    if [[ ! -d "$KERNEL_DIR" ]]; then
        print_info "No kernels found (kernel directory doesn't exist)"
        exit 0
    fi

    # Get list of conda environments (for future use in orphan detection)
    # declare -A conda_envs
    # while IFS= read -r line; do
    #     if [[ $line =~ ^#.* ]] || [[ -z $line ]]; then
    #         continue
    #     fi
    #     env_name=$(echo "$line" | awk '{print $1}')
    #     env_path=$(echo "$line" | awk '{print $NF}')
    #     conda_envs["$env_path"]="$env_name"
    # done < <(conda env list)

    # List all kernels
    kernel_count=0
    orphaned_count=0

    printf "%-30s %-15s %-40s\n" "Kernel Name" "Status" "Python Path"
    printf "%-30s %-15s %-40s\n" "-----------" "------" "-----------"

    for kernel in "$KERNEL_DIR"/*; do
        if [[ ! -d "$kernel" ]]; then
            continue
        fi

        kernel_name=$(basename "$kernel")
        kernel_count=$((kernel_count + 1))

        # Read kernel.json to get python path
        if [[ -f "$kernel/kernel.json" ]]; then
            python_path=$(grep -o '"argv"[[:space:]]*:[[:space:]]*\[[[:space:]]*"[^"]*"' "$kernel/kernel.json" | sed 's/.*"\([^"]*\)"/\1/' || echo "unknown")

            # Check if python executable exists
            if [[ -f "$python_path" ]]; then
                status="${GREEN}✓ Valid${NC}"
            else
                status="${RED}✗ Orphaned${NC}"
                orphaned_count=$((orphaned_count + 1))
            fi

            # Shorten path for display
            display_path="$python_path"
            if [[ ${#display_path} -gt 40 ]]; then
                display_path="...${display_path: -37}"
            fi

            printf "%-30s %-24b %-40s\n" "$kernel_name" "$status" "$display_path"
        else
            printf "%-30s %-24b %-40s\n" "$kernel_name" "${YELLOW}? No config${NC}" "N/A"
        fi
    done

    echo ""
    print_info "Total kernels: $kernel_count"
    if [[ $orphaned_count -gt 0 ]]; then
        print_warning "Orphaned kernels: $orphaned_count (run 'clean' to remove)"
    else
        print_success "No orphaned kernels found"
    fi
    echo ""

# Command: add
elif [[ "$COMMAND" == "add" ]]; then
    # Determine environment
    if [[ -n "$TARGET_ENV" ]]; then
        ENV_NAME="$TARGET_ENV"
    else
        if [[ -z "${CONDA_DEFAULT_ENV:-}" ]] || [[ "${CONDA_DEFAULT_ENV}" == "base" ]]; then
            print_error "No environment specified and no environment is active"
            echo "Usage: $0 add [env_name]"
            exit 1
        fi
        ENV_NAME="${CONDA_DEFAULT_ENV}"
    fi

    echo ""
    print_header "Register Jupyter Kernel"
    echo ""
    print_info "Environment: $ENV_NAME"

    # Get environment python path
    ENV_PATH=$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')
    if [[ -z "$ENV_PATH" ]]; then
        print_error "Environment '$ENV_NAME' not found"
        exit 1
    fi

    PYTHON_PATH="$ENV_PATH/bin/python"
    if [[ ! -f "$PYTHON_PATH" ]]; then
        print_error "Python not found in environment: $PYTHON_PATH"
        exit 1
    fi

    # Check if ipykernel is installed
    if ! "$PYTHON_PATH" -c "import ipykernel" 2>/dev/null; then
        print_warning "ipykernel not installed in environment '$ENV_NAME'"
        echo ""
        print_info "Installing ipykernel..."
        conda install -n "$ENV_NAME" ipykernel -y
        print_success "ipykernel installed"
        echo ""
    fi

    # Set display name
    if [[ -z "$DISPLAY_NAME" ]]; then
        DISPLAY_NAME="Python ($ENV_NAME)"
    fi

    print_info "Display name: $DISPLAY_NAME"
    echo ""

    # Register kernel
    print_info "Registering kernel..."
    "$PYTHON_PATH" -m ipykernel install --user --name="$ENV_NAME" --display-name="$DISPLAY_NAME"

    echo ""
    print_success "Kernel registered successfully!"
    print_info "Kernel name: $ENV_NAME"
    echo ""

# Command: remove
elif [[ "$COMMAND" == "remove" ]]; then
    if [[ -z "$TARGET_ENV" ]]; then
        print_error "No kernel specified"
        echo "Usage: $0 remove <kernel_name>"
        exit 1
    fi

    KERNEL_NAME="$TARGET_ENV"
    KERNEL_PATH="$KERNEL_DIR/$KERNEL_NAME"

    echo ""
    print_header "Remove Jupyter Kernel"
    echo ""

    if [[ ! -d "$KERNEL_PATH" ]]; then
        print_error "Kernel '$KERNEL_NAME' not found"
        exit 1
    fi

    print_info "Kernel: $KERNEL_NAME"
    print_info "Path: $KERNEL_PATH"
    echo ""

    # Confirm removal
    if [[ "$SKIP_CONFIRM" == false ]]; then
        read -p "Remove this kernel? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removal cancelled"
            exit 0
        fi
    fi

    jupyter kernelspec remove "$KERNEL_NAME" -y
    print_success "Kernel removed successfully"
    echo ""

# Command: clean
elif [[ "$COMMAND" == "clean" ]]; then
    echo ""
    print_header "Clean Orphaned Kernels"
    echo ""

    if [[ ! -d "$KERNEL_DIR" ]]; then
        print_info "No kernels found"
        exit 0
    fi

    # Find orphaned kernels
    orphaned_kernels=()

    for kernel in "$KERNEL_DIR"/*; do
        if [[ ! -d "$kernel" ]]; then
            continue
        fi

        kernel_name=$(basename "$kernel")

        # Read kernel.json to get python path
        if [[ -f "$kernel/kernel.json" ]]; then
            python_path=$(grep -o '"argv"[[:space:]]*:[[:space:]]*\[[[:space:]]*"[^"]*"' "$kernel/kernel.json" | sed 's/.*"\([^"]*\)"/\1/' || echo "")

            # Check if python executable exists
            if [[ -n "$python_path" ]] && [[ ! -f "$python_path" ]]; then
                orphaned_kernels+=("$kernel_name")
            fi
        fi
    done

    if [[ ${#orphaned_kernels[@]} -eq 0 ]]; then
        print_success "No orphaned kernels found"
        exit 0
    fi

    print_warning "Found ${#orphaned_kernels[@]} orphaned kernel(s):"
    for kernel in "${orphaned_kernels[@]}"; do
        echo "  - $kernel"
    done
    echo ""

    # Confirm cleanup
    if [[ "$SKIP_CONFIRM" == false ]]; then
        read -p "Remove all orphaned kernels? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cleanup cancelled"
            exit 0
        fi
    fi

    # Remove orphaned kernels
    for kernel in "${orphaned_kernels[@]}"; do
        print_info "Removing: $kernel"
        jupyter kernelspec remove "$kernel" -y 2>/dev/null || true
    done

    echo ""
    print_success "Cleanup complete! Removed ${#orphaned_kernels[@]} orphaned kernel(s)"
    echo ""

# Command: sync
elif [[ "$COMMAND" == "sync" ]]; then
    echo ""
    print_header "Sync All Conda Environments"
    echo ""
    print_info "This will register all conda environments as Jupyter kernels"
    echo ""

    # Get all conda environments (excluding base)
    env_list=()
    while IFS= read -r line; do
        if [[ $line =~ ^#.* ]] || [[ -z $line ]] || [[ $line =~ base ]]; then
            continue
        fi
        env_name=$(echo "$line" | awk '{print $1}')
        env_list+=("$env_name")
    done < <(conda env list)

    if [[ ${#env_list[@]} -eq 0 ]]; then
        print_info "No environments to sync (excluding base)"
        exit 0
    fi

    print_info "Found ${#env_list[@]} environment(s) to sync:"
    for env in "${env_list[@]}"; do
        echo "  - $env"
    done
    echo ""

    # Confirm sync
    if [[ "$SKIP_CONFIRM" == false ]]; then
        read -p "Register all as Jupyter kernels? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Sync cancelled"
            exit 0
        fi
    fi

    # Register each environment
    success_count=0
    for env in "${env_list[@]}"; do
        echo ""
        print_info "Processing: $env"

        ENV_PATH=$(conda env list | grep "^${env} " | awk '{print $NF}')
        PYTHON_PATH="$ENV_PATH/bin/python"

        if [[ ! -f "$PYTHON_PATH" ]]; then
            print_warning "  Python not found, skipping"
            continue
        fi

        # Install ipykernel if needed
        if ! "$PYTHON_PATH" -c "import ipykernel" 2>/dev/null; then
            print_info "  Installing ipykernel..."
            conda install -n "$env" ipykernel -y -q
        fi

        # Register kernel
        "$PYTHON_PATH" -m ipykernel install --user --name="$env" --display-name="Python ($env)" 2>/dev/null
        print_success "  Registered: $env"
        success_count=$((success_count + 1))
    done

    echo ""
    print_success "Sync complete! Registered $success_count out of ${#env_list[@]} environment(s)"
    echo ""
fi
