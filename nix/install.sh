#!/bin/sh
# nix/install.sh - POSIX compliant Nix installer wrapper

set -eu

die() { printf "error: %s\n" "$1" >&2; exit 1; }

source_nix_profile() {
    for p in "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
             "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [ -f "$p" ]; then
            . "$p"
            return 0
        fi
    done
    die "Nix profile not found. Restart terminal and re-run."
}

install_nix() {
    if command -v nix >/dev/null 2>&1; then
        return 0
    fi

    echo "Installing Nix..."
    # Try Determinate Systems installer first
    if ! curl --proto '=https' --tlsv1.2 -L https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm; then
        # Fallback to official installer
        if ! curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --extra-conf "experimental-features = nix-command flakes"; then
            die "Nix installation failed"
        fi
    fi
    source_nix_profile
}

install_nix
