#!/usr/bin/env bash
# ------------------------------------------------------------------
# conda_rollback.sh — Interactively roll back a conda environment
#
# Usage:
#   conda activate <env_name>
#   bash conda_rollback.sh
#
# Description:
#   - Lists all revision snapshots for the active environment
#   - Prompts for which revision to roll back to
#   - Confirms before applying
# ------------------------------------------------------------------

set -euo pipefail

# 🧭 Detect active environment
if [[ -z "${CONDA_DEFAULT_ENV:-}" ]]; then
  echo "🚫 No conda environment active. Run 'conda activate <env>' first."
  exit 1
fi

echo "🔁 Rolling back environment: ${CONDA_DEFAULT_ENV}"
echo "------------------------------------------------------------"
echo

# 🧱 List revisions
conda list --revisions

echo
read -rp "Enter revision number to roll back to (e.g. 1): " rev

if [[ -z "$rev" ]]; then
  echo "🚫 No revision entered. Aborting."
  exit 1
fi

echo
echo "⚠️  You are about to roll back '${CONDA_DEFAULT_ENV}' to revision $rev"
read -rp "Proceed? [y/N] " confirm

if [[ "${confirm,,}" != "y" ]]; then
  echo "🚫 Aborted."
  exit 0
fi

echo
echo "🔄 Applying rollback..."
conda install --revision "$rev" -y

echo
echo "✅ Rollback complete!"
echo "Current environment state:"
conda list | head -n 20
echo "..."
