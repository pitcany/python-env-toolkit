#!/usr/bin/env bash
# ---------------------------------------------------------------------
# clean_env_full.sh — Remove all packages except core ones (python, pip, setuptools, wheel)
# Handles both Conda-managed and Pip-installed packages.
#
# Usage:
#   conda activate myenv
#   bash clean_env_full.sh
# ---------------------------------------------------------------------

set -euo pipefail

echo "🧭 Active environment: $CONDA_DEFAULT_ENV"
echo "📦 Cleaning packages... (Conda + Pip)"
echo

# --- 1️⃣ Remove Conda packages ---
conda_pkgs=$(conda list --export \
  | grep -vE '^(#|$)' \
  | cut -d= -f1 \
  | grep -vE '^(python|pip|setuptools|wheel)$' \
  || true)

if [[ -n "$conda_pkgs" ]]; then
  echo "🧹 Conda packages to remove:"
  echo "$conda_pkgs" | sed 's/^/  - /'
  read -rp "Proceed with conda removals? [y/N] " c
  if [[ "${c,,}" == "y" ]]; then
    echo "$conda_pkgs" | xargs -r conda remove -y || true
  else
    echo "⏩ Skipping conda removals."
  fi
else
  echo "✅ No conda packages to remove."
fi

echo

# --- 2️⃣ Remove Pip packages ---
echo "📦 Checking pip packages..."
pip_pkgs=$(pip list --format=freeze \
  | cut -d= -f1 \
  | grep -vE '^(python|pip|setuptools|wheel)$' \
  || true)

if [[ -n "$pip_pkgs" ]]; then
  echo "🧹 Pip packages to uninstall:"
  echo "$pip_pkgs" | sed 's/^/  - /'
  read -rp "Proceed with pip uninstalls? [y/N] " p
  if [[ "${p,,}" == "y" ]]; then
    echo "$pip_pkgs" | xargs -r pip uninstall -y || true
  else
    echo "⏩ Skipping pip uninstalls."
  fi
else
  echo "✅ No pip packages to uninstall."
fi

echo
echo "✨ Environment cleaned!"
echo "Remaining packages:"
conda list | grep -E '^(python|pip|setuptools|wheel)'
