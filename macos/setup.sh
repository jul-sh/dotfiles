#!/usr/bin/env bash
# macos/setup.sh - macOS-only setup steps invoked by nix/setup-internal.sh

set -euo pipefail

# Ensure we are in the repo root
cd "$(dirname "$0")/.."

die() { echo "error: $1" >&2; exit 1; }

SCOPE_FILE=".setup_scope"

resolve_setup_scope() {
    if [[ -n "${SETUP_SCOPE:-}" ]]; then
        # Explicit env var: use it and persist
        echo "$SETUP_SCOPE" > "$SCOPE_FILE"
    elif [[ -f "$SCOPE_FILE" ]]; then
        SETUP_SCOPE=$(<"$SCOPE_FILE")
    else
        SETUP_SCOPE=system
        echo "$SETUP_SCOPE" > "$SCOPE_FILE"
    fi
    echo "Setup scope: $SETUP_SCOPE"
}

install_desktop_apps() {
    echo "Installing desktop apps..."
    echo "Ensuring desktop apps are managed by Homebrew..."
    local casks=("wezterm" "zed" "jul-sh/clipkitty/clipkitty")
    for cask in "${casks[@]}"; do
        local base_name="${cask##*/}"
        # Check if installed
        if ! brew list --cask | grep -q "^${base_name}$"; then
            echo "Installing $cask..."
            brew install --cask "$cask" || echo "  warning: failed to install $cask"
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
                        brew upgrade --cask "$cask" || echo "  warning: failed to update $cask"
                    ) & disown
                else
                    echo "Updating $base_name..."
                    brew upgrade --cask "$cask" || echo "  warning: failed to update $cask"
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

install_capslock_remap() {
    local swift_src="./macos/capslock_remap.swift"
    local bin_dst="$HOME/.local/bin/capslock-remap"
    local plist_dst="$HOME/Library/LaunchAgents/com.julsh.capslock_remap.plist"
    local label="com.julsh.capslock_remap"

    mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"

    # Compile if source is newer or binary missing
    if [[ "$swift_src" -nt "$bin_dst" ]] || [[ ! -f "$bin_dst" ]]; then
        echo "Compiling capslock remap agent..."
        swiftc -O "$swift_src" -o "$bin_dst"
    fi

    # Clean up old one-shot agent if present
    local old_agent="$HOME/Library/LaunchAgents/com.capslock_to_backspace.plist"
    if [[ -f "$old_agent" ]]; then
        launchctl unload "$old_agent" 2>/dev/null || true
        rm -f "$old_agent"
        rm -f "$HOME/.local/bin/capslock_to_backspace.sh"
    fi

    # Generate plist
    local plist_content
    plist_content=$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>Program</key>
    <string>${bin_dst}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLISTEOF
    )

    if [[ "$plist_content" != "$(cat "$plist_dst" 2>/dev/null)" ]]; then
        echo "Installing capslock remap agent..."
        launchctl unload "$plist_dst" 2>/dev/null || true
        echo "$plist_content" > "$plist_dst"
    fi

    launchctl load -w "$plist_dst" 2>/dev/null || true
}

install_capslock_remap_system() {
    local swift_src="./macos/capslock_remap.swift"
    local bin_dst="/Library/Scripts/capslock-remap"
    local plist_dst="/Library/LaunchDaemons/com.julsh.capslock_remap.plist"
    local label="com.julsh.capslock_remap"

    # Compile to temp then install with sudo
    local tmp_bin
    tmp_bin=$(mktemp)
    if [[ "$swift_src" -nt "$bin_dst" ]] || [[ ! -f "$bin_dst" ]]; then
        echo "Compiling capslock remap daemon..."
        swiftc -O "$swift_src" -o "$tmp_bin"
        sudo cp "$tmp_bin" "$bin_dst"
        sudo chmod +x "$bin_dst"
        rm -f "$tmp_bin"
    fi

    # Clean up old shell-script daemon if present
    local old_daemon="/Library/LaunchDaemons/com.capslock_to_backspace.plist"
    if [[ -f "$old_daemon" ]]; then
        sudo launchctl unload "$old_daemon" 2>/dev/null || true
        sudo rm -f "$old_daemon"
        sudo rm -f /Library/Scripts/capslock_to_backspace.sh
    fi

    # Generate plist
    local plist_content
    plist_content=$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${bin_dst}</string>
        <string>--oneshot</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
</dict>
</plist>
PLISTEOF
    )

    if [[ "$plist_content" != "$(sudo cat "$plist_dst" 2>/dev/null)" ]]; then
        echo "Installing capslock remap daemon..."
        sudo launchctl unload "$plist_dst" 2>/dev/null || true
        echo "$plist_content" | sudo tee "$plist_dst" > /dev/null
    fi

    sudo launchctl load -w "$plist_dst" 2>/dev/null || true
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
    if [[ "$SETUP_SCOPE" == "user" ]]; then
        install_capslock_remap
        install_launchagent ./macos/sleep_on_lid_close.sh ./macos/com.julsh.sleeponlidclose.plist
    fi

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
    local capslock_agent="$HOME/Library/LaunchAgents/com.capslock_to_backspace.plist"
    local capslock_remap_agent="$HOME/Library/LaunchAgents/com.julsh.capslock_remap.plist"
    local sleep_agent="$HOME/Library/LaunchAgents/com.julsh.sleeponlidclose.plist"

    if [[ "$SETUP_SCOPE" == "system" ]]; then
        # Install capslock remap as LaunchDaemon (all users, oneshot)
        install_capslock_remap_system
        install_launchdaemon \
            ./macos/sleep_on_lid_close.sh /Library/Scripts/sleep_on_lid_close.sh \
            ./macos/com.julsh.sleeponlidclose.plist /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist
        # Clean up per-user LaunchAgents if present
        for agent in "$capslock_agent" "$capslock_remap_agent" "$sleep_agent"; do
            if [[ -f "$agent" ]]; then
                launchctl unload "$agent" 2>/dev/null || true
                rm -f "$agent"
            fi
        done
        rm -f "$HOME/.local/bin/capslock_to_backspace.sh" "$HOME/.local/bin/capslock-remap" "$HOME/.local/bin/sleep_on_lid_close.sh"
    else
        # Clean up system-wide LaunchDaemons if present
        for daemon in com.capslock_to_backspace.plist com.julsh.capslock_remap.plist com.julsh.sleeponlidclose.plist; do
            if [[ -f "/Library/LaunchDaemons/$daemon" ]]; then
                sudo launchctl unload "/Library/LaunchDaemons/$daemon" 2>/dev/null || true
                sudo rm -f "/Library/LaunchDaemons/$daemon"
            fi
        done
        sudo rm -f /Library/Scripts/capslock_to_backspace.sh /Library/Scripts/capslock-remap /Library/Scripts/sleep_on_lid_close.sh
    fi

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

    resolve_setup_scope
    install_desktop_apps
    build_spotlight_scripts
    echo "Configuring user defaults..."
    configure_user_defaults
    if [[ "$SETUP_SCOPE" == "user" ]]; then
        echo "Skipping system configuration (SETUP_SCOPE=user)"
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
