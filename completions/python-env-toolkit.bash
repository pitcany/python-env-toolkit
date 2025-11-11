#!/usr/bin/env bash
# Bash completion for Python Environment Toolkit
#
# Installation:
#   1. Copy to /etc/bash_completion.d/ or ~/.bash_completion.d/
#   2. Or add to ~/.bashrc:
#      source /path/to/python-env-toolkit/completions/python-env-toolkit.bash
#   3. Reload: source ~/.bashrc or start new terminal

# Helper function to get conda environments
_get_conda_envs() {
    conda env list 2>/dev/null | awk 'NR>3 && $1 !~ /^#/ {print $1}'
}

# Helper function to get available templates
_get_templates() {
    echo "pytorch-cpu pytorch-gpu tensorflow-cpu tensorflow-gpu jax-cpu jax-gpu data-science deep-learning nlp cv minimal"
}

# Common flags used across scripts
_common_flags="--help -h --version -v"

# Completion for create_ml_env.sh
_create_ml_env_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--template --python --add --register-kernel --help"

    case "${prev}" in
        --template)
            COMPREPLY=( $(compgen -W "$(_get_templates)" -- ${cur}) )
            return 0
            ;;
        --python)
            COMPREPLY=( $(compgen -W "3.8 3.9 3.10 3.11 3.12" -- ${cur}) )
            return 0
            ;;
        --add)
            # Could potentially complete from conda packages, but that's slow
            return 0
            ;;
        *)
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Completion for clone_env.sh
_clone_env_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--python --cpu-to-gpu --gpu-to-cpu --swap-framework --add --remove --help"
    local envs=$(_get_conda_envs)

    case "${prev}" in
        --python)
            COMPREPLY=( $(compgen -W "3.8 3.9 3.10 3.11 3.12" -- ${cur}) )
            return 0
            ;;
        --swap-framework)
            COMPREPLY=( $(compgen -W "pytorch->tensorflow tensorflow->pytorch pytorch->jax" -- ${cur}) )
            return 0
            ;;
        *)
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    else
        COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
    fi
}

# Completion for env_diff.sh
_env_diff_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="--detailed --export --sync --help -d -e -s -h"
    local envs=$(_get_conda_envs)

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    else
        COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
    fi
}

# Completion for channel_manager.sh
_channel_manager_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local commands="list add remove priority reset detect-conflicts help"
    local channels="conda-forge defaults bioconda pytorch"
    local envs=$(_get_conda_envs)

    # First argument should be a command
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        return 0
    fi

    local command="${COMP_WORDS[1]}"

    case "${command}" in
        add|remove|priority)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                # Second arg is channel name
                COMPREPLY=( $(compgen -W "${channels}" -- ${cur}) )
            elif [[ ${COMP_CWORD} -eq 3 ]]; then
                # Third arg is optional env name
                COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
            fi
            ;;
        list|reset|detect-conflicts)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                # Optional env name
                COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
            fi
            ;;
    esac
}

# Completion for health_check.sh
_health_check_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="--quick --gpu-only --verbose --help"
    local envs=$(_get_conda_envs)

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    else
        COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
    fi
}

# Completion for smart_update.sh
_smart_update_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--verbose --summary --batch --name --conda-only --pip-only --check-duplicates --health-check-after --export-after --refresh --help"
    local envs=$(_get_conda_envs)

    case "${prev}" in
        --name)
            COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
            return 0
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Completion for safe_install.sh
_safe_install_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="--dry-run --yes --help"

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Completion for export_env.sh
_export_env_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--name --file-yml --file-req --help"
    local envs=$(_get_conda_envs)

    case "${prev}" in
        --name)
            COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
            return 0
            ;;
        --file-yml|--file-req)
            COMPREPLY=( $(compgen -f -- ${cur}) )
            return 0
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Completion for sync_env.sh
_sync_env_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--yml --req --prune --yes --help"

    case "${prev}" in
        --yml|--req)
            COMPREPLY=( $(compgen -f -- ${cur}) )
            return 0
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Completion for find_duplicates.sh
_find_duplicates_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="--fix --help"
    local envs=$(_get_conda_envs)

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    else
        COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
    fi
}

# Completion for manage_jupyter_kernels.sh
_manage_jupyter_kernels_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    local commands="list add remove clean sync help"
    local envs=$(_get_conda_envs)

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
    elif [[ ${COMP_CWORD} -eq 2 ]]; then
        case "${COMP_WORDS[1]}" in
            add|remove)
                COMPREPLY=( $(compgen -W "${envs}" -- ${cur}) )
                ;;
        esac
    fi
}

# Completion for validate_scripts.sh
_validate_scripts_completion() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    opts="--strict --fix --help -s -f -h"

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    fi
}

# Register completions for all scripts (with and without .sh extension)
complete -F _create_ml_env_completion create_ml_env.sh create_ml_env ./create_ml_env.sh
complete -F _clone_env_completion clone_env.sh clone_env ./clone_env.sh
complete -F _env_diff_completion env_diff.sh env_diff ./env_diff.sh
complete -F _channel_manager_completion channel_manager.sh channel_manager ./channel_manager.sh
complete -F _health_check_completion health_check.sh health_check ./health_check.sh
complete -F _smart_update_completion smart_update.sh smart_update ./smart_update.sh
complete -F _safe_install_completion safe_install.sh safe_install ./safe_install.sh
complete -F _export_env_completion export_env.sh export_env ./export_env.sh
complete -F _sync_env_completion sync_env.sh sync_env ./sync_env.sh
complete -F _find_duplicates_completion find_duplicates.sh find_duplicates ./find_duplicates.sh
complete -F _manage_jupyter_kernels_completion manage_jupyter_kernels.sh manage_jupyter_kernels ./manage_jupyter_kernels.sh
complete -F _validate_scripts_completion validate_scripts.sh validate_scripts ./validate_scripts.sh
