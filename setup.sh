#!/bin/sh
# setup.sh - POSIX compliant entrypoint that ensures Nix and runs modular setup

set -eu

# Ensure we are in the repo root
cd "$(dirname "$0")"

# --- Helpers ---
die() { printf "error: %s\n" "$1" >&2; exit 1; }

# =============================================================================
# PHASE 1: Install Nix (logic moved to nix/install.sh)
# =============================================================================

if ! command -v nix >/dev/null 2>&1; then
    sh ./nix/install.sh
fi

# =============================================================================
# PHASE 2: Main setup (logic moved to nix/setup-internal.sh)
# =============================================================================

if [ "${IN_NIX_SHELL:-}" = "1" ]; then
    bash ./nix/setup-internal.sh
else
    echo "Entering Nix environment..."
    # Execute nix develop and run the internal setup script
    exec nix develop ./nix --command bash -c "IN_NIX_SHELL=1 bash ./nix/setup-internal.sh"
fi
