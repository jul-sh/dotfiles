#!/usr/bin/env bash
# macos/setup.sh - macOS-only setup steps invoked by nix/setup-internal.sh

set -euo pipefail

# Ensure we are in the repo root
cd "$(dirname "$0")/.."

die() { echo "error: $1" >&2; exit 1; }

install_desktop_apps() {
    echo "Installing desktop apps..."
    echo "Ensuring desktop apps are managed by Homebrew..."
    local casks=("wezterm" "zed" "jul-sh/clipkitty/clipkitty")
    for cask in "${casks[@]}"; do
        local base_name="${cask##*/}"
        # Check if installed
        if ! brew list --cask | grep -q "^${base_name}$"; then
            echo "Installing $cask..."
            brew install --cask "$cask"
        else
            # Check if outdated
            if brew outdated --cask --quiet "$cask" >/dev/null 2>&1; then
                if pgrep -ix "$base_name" >/dev/null; then
                    echo "  $base_name is currently running. Scheduling update for when it closes..."
                    (
                        while pgrep -ix "$base_name" >/dev/null; do
                            sleep 60
                        done
                        echo "  $base_name closed. Starting Homebrew update..."
                        brew upgrade --cask "$cask"
                    ) & disown
                else
                    echo "Updating $base_name..."
                    brew upgrade --cask "$cask" || true
                fi
            else
                echo "  $base_name is up to date."
            fi
        fi
    done
}

build_spotlight_scripts() {
    local script="./macos/raycast_scripts/build_spotlight_apps.sh"
    if [[ -f "$script" ]]; then
        echo "Building Spotlight apps..."
        bash "$script"
    fi
}

install_launchagent() {
    local script_src="$1" plist_src="$2"
    local script_name plist_name script_dst plist_dst
    script_name=$(basename "$script_src")
    plist_name=$(basename "$plist_src")
    script_dst="$HOME/.local/bin/$script_name"
    plist_dst="$HOME/Library/LaunchAgents/$plist_name"

    mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"

    local transformed_plist
    transformed_plist=$(sed "s|/Library/Scripts|$HOME/.local/bin|g" "$plist_src")

    local files_changed=false
    if ! cmp -s "$script_src" "$script_dst" || [[ "$transformed_plist" != "$(cat "$plist_dst" 2>/dev/null)" ]]; then
        files_changed=true
    fi

    if $files_changed; then
        echo "Installing ${plist_name}..."
        launchctl unload "$plist_dst" 2>/dev/null || true
        cp "$script_src" "$script_dst"
        chmod +x "$script_dst"
        echo "$transformed_plist" > "$plist_dst"
    fi

    launchctl load -w "$plist_dst" 2>/dev/null || true
}

install_launchdaemon() {
    local script_src="$1" script_dst="$2" plist_src="$3" plist_dst="$4"
    local plist_name
    plist_name=$(basename "$plist_dst")

    local files_changed=false
    if ! cmp -s "$script_src" "$script_dst" || ! cmp -s "$plist_src" "$plist_dst"; then
        files_changed=true
    fi

    if $files_changed; then
        echo "Installing ${plist_name}..."
        # Unload first if updating
        sudo launchctl unload "$plist_dst" 2>/dev/null || true
        sudo cp "$script_src" "$script_dst"
        sudo chmod +x "$script_dst"
        sudo cp "$plist_src" "$plist_dst"
    fi

    # Always ensure daemon is loaded (idempotent - fails silently if already loaded)
    sudo launchctl load -w "$plist_dst" 2>/dev/null || true
}

configure_user_defaults() {
    install_launchagent ./macos/capslock_to_backspace.sh ./macos/com.capslock_to_backspace.plist

    defaults write com.apple.screencapture location -string "${HOME}/Downloads"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.dock show-recents -int 0
    defaults write com.apple.dock minimize-to-application -int 0
    defaults write com.apple.dock tilesize -int 34
    defaults write com.apple.dock orientation -string "left"

    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 30 "
    <dict>
        <key>enabled</key><true/>
        <key>value</key>
        <dict>
            <key>parameters</key>
            <array>
                <integer>115</integer>
                <integer>1</integer>
                <integer>1572864</integer>
            </array>
            <key>type</key><string>standard</string>
        </dict>
    </dict>"

    killall Dock 2>/dev/null || true
}

configure_system_defaults() {
    # Clean up old LaunchDaemon for capslock (now a user LaunchAgent)
    if [[ -f /Library/LaunchDaemons/com.capslock_to_backspace.plist ]]; then
        sudo launchctl unload /Library/LaunchDaemons/com.capslock_to_backspace.plist 2>/dev/null || true
        sudo rm -f /Library/LaunchDaemons/com.capslock_to_backspace.plist /Library/Scripts/capslock_to_backspace.sh
    fi

    install_launchdaemon \
        ./macos/sleep_on_lid_close.sh /Library/Scripts/sleep_on_lid_close.sh \
        ./macos/com.julsh.sleeponlidclose.plist /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist

    sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
        "—ฅ/ᐠ. ̫.ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"
}

main() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        die "macos/setup.sh invoked on non-macOS system"
    fi
    if [[ $# -ne 0 ]]; then
        die "macos/setup.sh does not accept arguments"
    fi

    install_desktop_apps
    build_spotlight_scripts
    echo "Configuring user defaults..."
    configure_user_defaults
    if [[ "${NO_SUDO:-}" = "1" ]]; then
        echo "Skipping system configuration (--no-sudo)"
    else
        echo "Configuring system defaults (requires sudo)..."
        if sudo -v; then
            configure_system_defaults
        else
            echo ""
            printf "Skip system configuration and continue? [y/N]: "
            read -r choice < /dev/tty || choice=""
            case "$choice" in
                y|Y) echo "Skipping system configuration." ;;
                *) die "Setup aborted" ;;
            esac
        fi
    fi
}

main "$@"
