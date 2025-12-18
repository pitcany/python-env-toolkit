#!/usr/bin/env bash
# ---------------------------------------------------------------------
# export_env.sh — Export active Conda environment to YAML and pip requirements
#
# Usage:
#   conda activate <env_name>
#   bash export_env.sh [--name <env_name>] [--file-yml <path>] [--file-req <path>]
#
# Description:
#   - Detects the active Conda environment or uses the provided name
#   - Exports Conda dependencies (no build numbers) to a YAML file
#   - Exports pip-installed packages to a requirements.txt file
# ---------------------------------------------------------------------

set -euo pipefail

# Check if conda is available
if ! command -v conda &> /dev/null; then
    echo "🚫 Error: conda command not found"
    exit 1
fi

# Default output filenames
YML_FILE="environment.yml"
REQ_FILE="requirements.txt"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      shift
      ENV_NAME="$1"
      shift
      ;;
    --file-yml)
      shift
      YML_FILE="$1"
      shift
      ;;
    --file-req)
      shift
      REQ_FILE="$1"
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--name <env_name>] [--file-yml <path>] [--file-req <path>]

Options:
  --name     Name of the Conda environment to export (default: active)
  --file-yml Output path for the Conda environment YAML (default: environment.yml)
  --file-req Output path for pip requirements (default: requirements.txt)
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Determine environment name
if [[ -z "${ENV_NAME:-}" ]]; then
  if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
    echo "🚫 No Conda environment active. Please activate one or use --name."
    exit 1
  fi
  ENV_NAME="$CONDA_DEFAULT_ENV"
fi

echo "🔍 Exporting Conda environment '$ENV_NAME' to '$YML_FILE'..."
conda env export -n "$ENV_NAME" --no-builds > "$YML_FILE"
echo "✅ Conda environment exported: $YML_FILE"

echo
echo "🔍 Exporting pip packages to '$REQ_FILE'..."
# Use pip from the active environment to list packages
pip freeze | sed '/^-e /d' > "$REQ_FILE"
echo "✅ Pip requirements exported: $REQ_FILE"
