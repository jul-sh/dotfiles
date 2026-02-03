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

    # Create temp file for extra config (process substitution not portable)
    local extra_conf
    extra_conf=$(mktemp)
    echo "experimental-features = nix-command flakes" > "$extra_conf"
    trap "rm -f '$extra_conf'" EXIT

    if [ "${NO_SUDO:-}" = "1" ]; then
        # Single-user mode only (no sudo)
        if ! curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes --nix-extra-conf-file "$extra_conf"; then
            die "Nix installation failed"
        fi
    else
        # Try official installer with multi-user mode first
        if curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon --yes --nix-extra-conf-file "$extra_conf"; then
            : # success
        else
            echo ""
            echo "Multi-user installation failed (requires sudo)."
            printf "Continue with single-user installation? [y/N]: "
            read -r choice < /dev/tty || choice=""
            case "$choice" in
                y|Y)
                    if ! curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes --nix-extra-conf-file "$extra_conf"; then
                        die "Nix installation failed"
                    fi
                    ;;
                *)
                    die "Installation aborted"
                    ;;
            esac
        fi
    fi

    source_nix_profile
    ensure_nix_conf
}

install_nix
