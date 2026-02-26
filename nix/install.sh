#!/usr/bin/env bash
# nix/install.sh - Nix installer wrapper

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

ensure_nix_conf() {
    local conf_dir="$HOME/.config/nix"
    local conf_file="$conf_dir/nix.conf"
    local required_line="experimental-features = nix-command flakes"

    mkdir -p "$conf_dir"
    if [ ! -f "$conf_file" ] || ! grep -q "experimental-features" "$conf_file"; then
        echo "$required_line" >> "$conf_file"
    fi
}

install_nix() {
    if command -v nix >/dev/null 2>&1; then
        ensure_nix_conf
        return 0
    fi

    echo "Installing Nix..."

    if ! curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
        sh -s -- install --no-confirm; then
        die "Nix installation failed"
    fi

    source_nix_profile
    ensure_nix_conf
}

install_nix
