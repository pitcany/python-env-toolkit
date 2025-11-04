#!/usr/bin/env bash
# ---------------------------------------------------------------------
# poetry_bind_conda.sh — Safely bind Poetry to the active Conda Python
#
# Usage:
#   conda activate <your_env>
#   bash poetry_bind_conda.sh [--force]
#
# Description:
#   - Detects the active Conda environment
#   - Resolves its Python interpreter path
#   - Runs `poetry env use <path>`
#   - Auto-creates a Poetry env if missing
#   - Optionally recreates it when --force is passed
# ---------------------------------------------------------------------

set -euo pipefail

FORCE_RECREATE=false

# 🧭 Parse arguments
if [[ "${1:-}" == "--force" ]]; then
  FORCE_RECREATE=true
  echo "⚠️  Force mode enabled — existing Poetry env will be deleted and rebuilt."
fi

# 🧭 Ensure Conda environment is active
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
  echo "🚫 No Conda environment active. Please run 'conda activate <env>' first."
  exit 1
fi

echo "🔍 Active Conda environment: $CONDA_DEFAULT_ENV"

# 🐍 Resolve Python path
PY_PATH="$(which python || true)"

if [[ -z "$PY_PATH" ]]; then
  echo "🚫 No Python interpreter found. Make sure this Conda env includes Python."
  exit 1
fi

if [[ ! -x "$PY_PATH" ]]; then
  echo "🚫 Python path is not executable: $PY_PATH"
  exit 1
fi

echo "🐍 Using Python interpreter: $PY_PATH"

# 🔄 Bind Poetry to the Conda Python
echo
echo "🔗 Running: poetry env use \"$PY_PATH\""
poetry env use "$PY_PATH" || {
  echo "⚠️ Poetry failed to bind. Ensure Poetry is installed (pipx install poetry)."
  exit 1
}

# 🧱 Check if a Poetry environment exists
if poetry env info --path >/dev/null 2>&1; then
  CURRENT_PATH="$(poetry env info --path)"
  echo
  echo "🧭 Poetry environment currently located at: $CURRENT_PATH"

  if [[ "$FORCE_RECREATE" == true ]]; then
    echo "🧨 Recreating Poetry environment..."
    poetry env remove "$PY_PATH" || true
    poetry install --no-root
  else
    echo "✅ Poetry environment already exists. Skipping recreation."
  fi
else
  echo "⚙️  No Poetry environment detected. Creating one..."
  poetry install --no-root
fi

# ✅ Verify final setup
echo
echo "✅ Poetry environment info:"
poetry env info

echo
echo "🎉 Poetry successfully bound to Conda env '$CONDA_DEFAULT_ENV'!"
if [[ "$FORCE_RECREATE" == true ]]; then
  echo "💥 Environment was forcefully rebuilt from scratch."
fi
