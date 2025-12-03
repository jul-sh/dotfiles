#!/usr/bin/env bash
#
# Bootstrapper for a new development environment.
#
# 1. Installs prerequisites.
# 2. Applies the declarative shell environment using Nix Flakes and Home Manager.
# 3. Installs OS-specific GUI applications.
# 4. Configures system-level settings that require sudo.

set -euo pipefail

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

# --- Prerequisite Installation ---
install_prereqs() {
    info "Installing prerequisites..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &>/dev/null; then
            info "Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            info "Homebrew is already installed."
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        info "Updating apt and installing git and curl..."
        sudo apt-get update
        sudo apt-get install -y git curl
    else
        error "Unsupported OS: $OSTYPE"
    fi

    # Install Nix if not already installed
    if ! command -v nix &>/dev/null; then
        info "Nix not found. Attempting multi-user installation..."
        # Try the Determinate Systems installer (multi-user) first.
        if curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm; then
            info "Multi-user Nix installation successful."
            # Source the multi-user profile script to make 'nix' available in this session.
            local nix_profile="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
            if [ -f "$nix_profile" ]; then
                info "Sourcing Nix profile for multi-user install..."
                . "$nix_profile"
            else
                error "Multi-user Nix installation seemed to succeed, but its profile script was not found. Please start a new terminal and re-run this script."
            fi
        else
            warn "Multi-user installation failed. Falling back to official single-user installer."
            # Fallback to the official installer (single-user).
            if curl -L https://nixos.org/nix/install | sh -s -- --no-daemon; then
                info "Single-user Nix installation successful."
                # Source the single-user profile script.
                local nix_profile="$HOME/.nix-profile/etc/profile.d/nix.sh"
                if [ -f "$nix_profile" ]; then
                    info "Sourcing Nix profile for single-user install..."
                    . "$nix_profile"
                else
                    error "Single-user Nix installation seemed to succeed, but its profile script was not found. Please start a new terminal and re-run this script."
                fi
            else
                error "Both multi-user and single-user Nix installation methods failed. Please check the logs and try again."
            fi
        fi
    else
        info "Nix is already installed."
    fi
}

# --- Nix Configuration ---
apply_nix_config() {
    info "Applying Nix Home Manager configuration..."

    local system
    system=$(get_nix_system)
    info "Detected Nix system: $system"

    # Construct the flake reference dynamically, e.g., ./nix#julsh@x86_64-linux
    local flake_ref="./nix#${USER}@${system}"
    info "Applying flake configuration: $flake_ref"

    # We are running from the root of the repo, so we point to the 'nix' directory
    nix run home-manager/master -- switch --flake "$flake_ref" -b backup
}

# --- OS-Specific Tasks (Not managed by Nix) ---
install_desktop_apps() {
    info "Installing GUI applications..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Installing Raycast and Zed via Homebrew Cask..."
        brew install --cask --force raycast zed
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        info "Installing Zed editor..."
        curl -f https://zed.dev/install.sh | sh
    fi
}

setup_local_rc_files() {
    info "Setting up local shell rc files..."

    # Create local .profile that sources .profile.shared
    if [[ ! -f "${HOME}/.profile" ]]; then
        info "Creating local .profile..."
        cat > "${HOME}/.profile" <<'EOF'
# Source shared profile configuration
if [ -f "${HOME}/.profile.shared" ]; then
  . "${HOME}/.profile.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    else
        info "Local .profile already exists, skipping creation"
    fi

    # Create local .bashrc that sources .bashrc.shared
    if [[ ! -f "${HOME}/.bashrc" ]]; then
        info "Creating local .bashrc..."
        cat > "${HOME}/.bashrc" <<'EOF'
# Source shared bash configuration
if [ -f "${HOME}/.bashrc.shared" ]; then
  . "${HOME}/.bashrc.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    else
        info "Local .bashrc already exists, skipping creation"
    fi

    # Create local .zshrc that sources .zshrc.shared
    if [[ ! -f "${HOME}/.zshrc" ]]; then
        info "Creating local .zshrc..."
        cat > "${HOME}/.zshrc" <<'EOF'
# Source shared zsh configuration
if [ -f "${HOME}/.zshrc.shared" ]; then
  source "${HOME}/.zshrc.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    else
        info "Local .zshrc already exists, skipping creation"
    fi
}

configure_os() {
    info "Applying OS-specific configurations..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Configuring macOS system settings..."
        # NOTE: This section contains 'sudo' commands and cannot be managed by Home Manager.
        # It is copied directly from your original script.

        # Remap Caps Lock to Backspace
        sudo cp ./macos/capslock_to_backspace.sh /Library/Scripts/
        sudo chmod +x /Library/Scripts/capslock_to_backspace.sh
        sudo cp ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist || warn "Failed to load capslock LaunchDaemon. It might already be loaded."

        # Configure sleep on lid close
        sudo cp ./macos/sleep_on_lid_close.sh /Library/Scripts/
        sudo chmod +x /Library/Scripts/sleep_on_lid_close.sh
        sudo cp ./macos/com.julsh.sleeponlidclose.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist || warn "Failed to load sleep on lid close LaunchDaemon. It might already be loaded."

        # Finder, Dock, & General UI
        defaults write com.apple.screencapture location -string "${HOME}/Desktop"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write com.apple.dock show-recents -int 0
        defaults write com.apple.dock minimize-to-application -int 1
        defaults write com.apple.dock tilesize -int 34
        defaults write com.apple.dock orientation -string "left"
        killall Dock || true

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
