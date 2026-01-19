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
    # Try official installer with multi-user mode first
    if ! curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon --yes --nix-extra-conf-file <(echo "experimental-features = nix-command flakes"); then
        # Fallback to single-user mode
        if ! curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes --nix-extra-conf-file <(echo "experimental-features = nix-command flakes"); then
            die "Nix installation failed"
        fi
    fi
    source_nix_profile
}

install_nix
