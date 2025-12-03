#!/usr/bin/env bash
#
# Bootstrapper for a new development environment.
#
# 1. Installs prerequisites.
# 2. Applies the declarative shell environment using Nix Flakes and Home Manager.
# 3. Installs OS-specific GUI applications.
# 4. Configures system-level settings that require sudo.

set -euo pipefail

# Resolve the directory containing this script (works even if called via symlink)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Helper Functions ---
info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1" >&2
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

get_nix_system() {
    local os
    case "$OSTYPE" in
        linux-gnu*) os="linux" ;;
        darwin*)    os="darwin" ;;
        *)          error "Unsupported OS for Nix: $OSTYPE" ;;
    esac

    local arch
    case "$(uname -m)" in
        x86_64)        arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)             error "Unsupported architecture for Nix: $(uname -m)" ;;
    esac
    echo "${arch}-${os}"
}

# Generate a local host flake that sets home directory to the detected $HOME
ensure_local_host_flake() {
    local target="nix/hosts/local/flake.nix"
    mkdir -p "$(dirname "$target")"
    cat > "$target" <<EOF
{
  outputs = { ... }: {
    homeModules.default = { lib, ... }: {
      home.homeDirectory = lib.mkForce "$HOME";
    };
  };
}
EOF
}

# Source Nix profile to make 'nix' available in current session
source_nix_profile() {
    local profile
    for profile in \
        "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [[ -f "$profile" ]]; then
            info "Sourcing Nix profile..."
            . "$profile"
            return 0
        fi
    done
    error "Nix profile not found. Please restart your terminal and re-run."
}

install_nix() {
    info "Installing Nix..."
    # Try Determinate Systems installer first (multi-user), fall back to official
    if curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm; then
        info "Nix installed (multi-user)."
    elif curl -L https://nixos.org/nix/install | sh -s -- --no-daemon; then
        info "Nix installed (single-user)."
    else
        error "Nix installation failed."
    fi
    source_nix_profile
}

# --- Prerequisite Installation ---
install_prereqs() {
    # macOS: ensure Homebrew
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &>/dev/null; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    # Linux: ensure git and curl
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
            if command -v apt-get &>/dev/null; then
                info "Installing git and curl via apt..."
                sudo apt-get update && sudo apt-get install -y git curl
            else
                warn "apt-get not found, skipping (not Debian-based?)"
            fi
        fi
    else
        error "Unsupported OS: $OSTYPE"
    fi

    # All platforms: ensure Nix
    if ! command -v nix &>/dev/null; then
        install_nix
    fi
}

# --- Nix Configuration ---
apply_nix_config() {
    info "Applying Nix Home Manager configuration..."

    local system
    system=$(get_nix_system)
    info "Detected Nix system: $system"

    # Generate local host flake with detected HOME path
    ensure_local_host_flake
    info "Using detected HOME: $HOME"

    # Construct the flake reference dynamically, e.g., ./nix#julsh@x86_64-linux
    local flake_ref="./nix#${USER}@${system}"
    info "Applying flake configuration: $flake_ref"

    # Override host input to use generated local flake (gitignored, can't be in lock file)
    nix run home-manager/master -- switch --flake "$flake_ref" -b backup \
        --override-input host "path:./nix/hosts/local"
}

# --- OS-Specific Tasks (Not managed by Nix) ---
install_desktop_apps() {
    info "Installing GUI applications..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Installing Raycast and Zed via Homebrew Cask..."
        brew install --cask --force raycast zed
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v zed &>/dev/null; then
            info "Zed is already installed."
        else
            info "Installing Zed editor..."
            curl -f https://zed.dev/install.sh | sh
        fi
    fi
}

setup_local_rc_files() {
    info "Setting up local shell rc files..."

    # Each rc file sources its .shared counterpart managed by Home Manager
    local -A rc_files=(
        [".profile"]=".profile.shared"
        [".bashrc"]=".bashrc.shared"
        [".zshrc"]=".zshrc.shared"
    )

    for rc in "${!rc_files[@]}"; do
        local shared="${rc_files[$rc]}"
        local target="${HOME}/${rc}"

        if [[ -f "$target" ]]; then
            info "Local $rc already exists, skipping"
            continue
        fi

        info "Creating local $rc..."
        cat > "$target" <<EOF
# Source shared configuration (managed by Nix Home Manager)
if [ -f "\${HOME}/${shared}" ]; then
  . "\${HOME}/${shared}"
fi

# Machine-specific configuration below this line

EOF
    done
}

# Helper to install a macOS LaunchDaemon only if changed
install_launchdaemon() {
    local script_src="$1" script_dst="$2" plist_src="$3" plist_dst="$4"

    # Skip if both files are identical to installed versions
    if cmp -s "$script_src" "$script_dst" && cmp -s "$plist_src" "$plist_dst"; then
        info "$(basename "$plist_src") already installed, skipping"
        return 0
    fi

    info "Installing $(basename "$plist_src")..."
    sudo cp "$script_src" "$script_dst"
    sudo chmod +x "$script_dst"
    sudo cp "$plist_src" "$plist_dst"
    sudo launchctl load -w "$plist_dst" 2>/dev/null || true
}

configure_os() {
    info "Applying OS-specific configurations..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # LaunchDaemons (requires sudo, can't be managed by Home Manager)
        install_launchdaemon \
            ./macos/capslock_to_backspace.sh /Library/Scripts/capslock_to_backspace.sh \
            ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/com.capslock_to_backspace.plist

        install_launchdaemon \
            ./macos/sleep_on_lid_close.sh /Library/Scripts/sleep_on_lid_close.sh \
            ./macos/com.julsh.sleeponlidclose.plist /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist

        # Finder, Dock, & General UI (these are already idempotent)
        defaults write com.apple.screencapture location -string "${HOME}/Desktop"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write com.apple.dock show-recents -int 0
        defaults write com.apple.dock minimize-to-application -int 1
        defaults write com.apple.dock tilesize -int 34
        defaults write com.apple.dock orientation -string "left"
        killall Dock 2>/dev/null || true

        # Login Window Text
        sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
            "—ฅ/ᐠ. ̫.ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        info "No Linux-specific system configurations to apply."
    fi
}

main() {
    install_prereqs
    apply_nix_config
    setup_local_rc_files
    install_desktop_apps
    configure_os

    info "🎉 Setup complete! Please restart your terminal to ensure all changes take effect."
}

main
