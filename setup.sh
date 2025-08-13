#!/usr/bin/env bash
#
# This script sets up a new development environment by:
# 1. Symlinking dotfiles.
# 2. Installing packages for macOS or Linux.
# 3. Installing common cross-platform tools (Rust, etc.).
# 4. Configuring OS-specific settings.
# 5. Installing fonts.
#
# It is designed to be idempotent and can be run multiple times.

# Set options:
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the exit status of the last command
#              that exited with a non-zero status, or zero if all commands succeed.
# Note: -e (exit on error) is deliberately removed to allow the script to continue
#       and instead rely on the ERR trap for warnings.
set -uo pipefail

# Global error handler: Prints a warning if a command fails, but does not exit the script.
_handle_error() {
    local exit_code=$?
    local cmd="$BASH_COMMAND"
    local line_num=${BASH_LINENO[0]}
    # FUNCNAME[0] is _handle_error itself, FUNCNAME[1] is the function that called the failing command.
    local func_name=${FUNCNAME[1]:-"main script"}
    echo "WARNING: Command failed (exit code $exit_code) in '${func_name}' on line $line_num: '$cmd'. Continuing anyway." >&2
}

# Trap ERR: Executes _handle_error function whenever a command exits with a non-zero status.
# Commands within `[[ ... ]]` or `if` conditions, or those explicitly followed by `|| true`,
# `|| { ... }`, or `!` are typically exempt from triggering the ERR trap.
trap '_handle_error' ERR

# --- Setup Functions ---

setup_shell() {
    echo "--- Setting up shell and symlinking dotfiles ---"
    touch "${HOME}/.hushlogin"

    local dotfiles_dir
    dotfiles_dir="$(pwd)/dotfiles"

    if [[ ! -d "$dotfiles_dir" ]]; then
        echo "ERROR: 'dotfiles' directory not found in the current directory. Exiting." >&2
        exit 1
    fi

    echo "Symlinking dotfiles from ${dotfiles_dir} to ${HOME}"
    for filepath in "${dotfiles_dir}"/.*; do
        local filename
        filename=$(basename "${filepath}")

        # Skip ., .., and .DS_Store
        case "$filename" in
            .|..|.DS_Store)
                continue
                ;;
        esac
        ln -sfv "${filepath}" "${HOME}/${filename}"
    done
}

install_packages() {
    echo "--- Starting package installation ---"

    curl -sS https://starship.rs/install.sh | sh -s -- --force

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS detected. Installing Homebrew and packages..."

        if ! command -v brew &>/dev/null; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            echo "Homebrew already installed."
        fi

        if command -v brew &>/dev/null; then
            local brew_bin
            brew_bin=$(brew --prefix)/bin/brew
            "$brew_bin" install --cask --force raycast zed
        else
            echo "WARNING: Homebrew not found after attempted installation. Skipping Homebrew package installation." >&2
        fi

    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux detected. Installing packages with apt..."

        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg && \
        echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list > /dev/null && \
        sudo apt update && \
        sudo apt install -y wezterm

        curl -f https://zed.dev/install.sh | sh

        type -p wget >/dev/null || (sudo apt-get update && sudo apt-get install -y wget) && \
        sudo mkdir -p -m 755 /etc/apt/keyrings && \
        wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
        echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
        sudo apt update && \
        sudo apt install -y gh
    else
        echo "Unsupported OS: $OSTYPE. Skipping OS-specific package installation." >&2
    fi

    # --- Install common tools (Rust, Cargo packages) ---
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain none -y

    # Rustup post-install setup
    if [ -f "${HOME}/.cargo/env" ]; then
        # shellcheck source=/dev/null
        source "${HOME}/.cargo/env"
        rustup toolchain install nightly --allow-downgrade --profile minimal --component clippy
    else
        echo "WARNING: .cargo/env not found after Rust installation. Skipping Rust toolchain setup." >&2
    fi

    curl -LsSf https://astral.sh/uv/install.sh | sh

    echo "Installing Rust-based tools via cargo..."
    local cargo_packages=("zellij" "aichat")
    for pkg in "${cargo_packages[@]}"; do
        cargo install "${pkg}"
    done

    echo "Installing shell-based tools via curl..."
    echo "Installing Atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

    echo "Package installation complete!"
}

configure_os() {
    echo "--- Applying OS-specific configurations ---"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Configuring macOS..."

        # Remap Caps Lock to Backspace
        sudo cp ./macos/capslock_to_backspace.sh /Library/Scripts/
        sudo chmod +x /Library/Scripts/capslock_to_backspace.sh
        sudo cp ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist

        # Finder & General UI
        defaults write com.apple.screencapture location -string "${HOME}/Desktop"
        defaults write com.apple.TextEdit NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
        defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
        defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

        # Dock
        defaults write com.apple.dock show-recents -int 0
        defaults write com.apple.dock minimize-to-application -int 1
        defaults write com.apple.dock tilesize -int 34
        defaults write com.apple.dock orientation -string "left"

        # Login Window
        sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
            "—ฅ/ᐠ. ̫.ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"

        echo "Restarting Dock and Finder to apply settings..."
        # These `killall` commands are expected to fail if the process isn't running,
        # so `|| true` prevents the ERR trap from firing for this specific case.
        killall Dock &>/dev/null || true
        killall Finder &>/dev/null || true
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux-specific configurations not implemented yet."
    fi
}

install_fonts() {
    echo "--- Installing fonts ---"
    local font_dir

    if [[ "$OSTYPE" == "darwin"* ]]; then
        font_dir="${HOME}/Library/Fonts"
    else
        font_dir="${HOME}/.local/share/fonts"
    fi

    echo "Copying fonts to ${font_dir}"
    mkdir -p "$font_dir"
    find fonts -name "*.ttf" -exec cp {} "$font_dir/" \;

    # Update font cache on Linux after copying new fonts
    if [[ "$OSTYPE" != "darwin"* ]] && command -v fc-cache &>/dev/null; then
        echo "Updating font cache..."
        fc-cache -f -v
    fi
}

main() {
    setup_shell
    install_packages
    install_fonts
    configure_os

    echo "🎉 Setup complete! Please restart your terminal."
}

main
