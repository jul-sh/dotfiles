#!/usr/bin/env bash
# macos/setup.sh - macOS-only setup steps invoked by nix/setup-internal.sh

set -euo pipefail

# Ensure we are in the repo root
cd "$(dirname "$0")/.."

die() { echo "error: $1" >&2; exit 1; }

check_app_updates() {
    local lockfile="./external.lock.json"

    local locked_wezterm
    locked_wezterm=$(jq -r '.wezterm.version' "$lockfile")
    local latest_wezterm
    latest_wezterm=$(curl -fsSL "https://api.github.com/repos/wez/wezterm/releases/latest" 2>/dev/null | jq -r '.tag_name' || echo "$locked_wezterm")
    if [[ "$latest_wezterm" != "$locked_wezterm" ]]; then
        echo "warning: WezTerm $latest_wezterm available (locked: $locked_wezterm). Run ./update.sh to update."
    fi

    local locked_zed
    locked_zed=$(jq -r '.zed.version' "$lockfile")
    local latest_zed
    latest_zed=$(curl -fsSL "https://api.github.com/repos/zed-industries/zed/releases/latest" 2>/dev/null | jq -r '.tag_name' || echo "$locked_zed")
    if [[ "$latest_zed" != "$locked_zed" ]]; then
        echo "warning: Zed $latest_zed available (locked: $locked_zed). Run ./update.sh to update."
    fi
}

finalize_app_install() {
    local source_bundle="$1" app_name="$2"
    echo "  Finalizing $app_name installation..."
    sudo rm -rf "/Applications/${app_name}.app"
    sudo mv "$source_bundle" "/Applications/${app_name}.app"
    sudo xattr -dr com.apple.quarantine "/Applications/${app_name}.app" 2>/dev/null || true
}

install_app_logic() {
    local new_bundle="$1" app_name="$2"

    if pgrep -x "$app_name" >/dev/null; then
        local staging_dir="$HOME/.local/share/clipkitty/update_staging"
        mkdir -p "$staging_dir"
        local staged_bundle="${staging_dir}/${app_name}.app"

        echo "  $app_name is currently running. Update scheduled for when it closes."
        rm -rf "$staged_bundle"
        mv "$new_bundle" "$staged_bundle"

        # Spawn background waiter
        (
            while pgrep -x "$app_name" >/dev/null; do
                # Keep sudo session alive (non-interactive refresh)
                sudo -n -v 2>/dev/null || true
                sleep 60
            done
            finalize_app_install "$staged_bundle" "$app_name"
        ) & disown
    else
        finalize_app_install "$new_bundle" "$app_name"
    fi
}

install_app_from_zip() {
    local url="$1" expected_sha256="$2" app_name="$3"
    local tmp_dir zip_path actual_sha256

    tmp_dir="$(mktemp -d)"
    zip_path="${tmp_dir}/app.zip"

    curl -fsSL "$url" -o "$zip_path"
    actual_sha256=$(shasum -a 256 "$zip_path" | awk '{print $1}')
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        rm -rf "$tmp_dir"
        die "SHA256 mismatch for $app_name: expected $expected_sha256, got $actual_sha256"
    fi

    unzip -q "$zip_path" -d "$tmp_dir"
    local app_bundle
    app_bundle=$(find "$tmp_dir" -name "*.app" -type d | head -1)
    if [[ -z "$app_bundle" ]]; then
        echo "Contents of extracted zip:"
        ls -la "$tmp_dir"
        rm -rf "$tmp_dir"
        die "No .app bundle found in $app_name zip file"
    fi

    install_app_logic "$app_bundle" "$app_name"

    rm -rf "$tmp_dir"
}

install_app_from_dmg() {
    local url="$1" expected_sha256="$2" app_name="$3"
    local tmp_dir dmg_path actual_sha256 mount_point

    tmp_dir="$(mktemp -d)"
    dmg_path="${tmp_dir}/app.dmg"

    curl -fsSL "$url" -o "$dmg_path"
    actual_sha256=$(shasum -a 256 "$dmg_path" | awk '{print $1}')
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        rm -rf "$tmp_dir"
        die "SHA256 mismatch for $app_name: expected $expected_sha256, got $actual_sha256"
    fi

    mount_point=$(hdiutil attach -nobrowse -readonly "$dmg_path" 2>/dev/null | grep -o '/Volumes/.*' | head -1)
    local app_bundle
    app_bundle=$(find "$mount_point" -maxdepth 1 -name "*.app" | head -1)

    # Copy from read-only mount to a writable temp location before handing off to logic
    local writable_bundle="${tmp_dir}/staged_${app_name}.app"
    cp -R "$app_bundle" "$writable_bundle"
    hdiutil detach "$mount_point" -quiet

    install_app_logic "$writable_bundle" "$app_name"

    rm -rf "$tmp_dir"
}

install_clipkitty() {
    local lockfile="./external.lock.json"
    local url sha256
    url=$(jq -r '.clipkitty.url' "$lockfile")
    sha256=$(jq -r '.clipkitty.sha256' "$lockfile")
    echo "  Installing ClipKitty..."
    install_app_from_dmg "$url" "$sha256" "ClipKitty"
}

install_desktop_apps() {
    echo "Installing desktop apps..."
    check_app_updates

    local arch
    arch=$(uname -m)
    [[ "$arch" == "arm64" ]] && arch="aarch64"

    local wezterm_url wezterm_sha256
    wezterm_url=$(jq -r '.wezterm.url' "./external.lock.json")
    wezterm_sha256=$(jq -r '.wezterm.sha256' "./external.lock.json")
    echo "  Installing WezTerm..."
    install_app_from_zip "$wezterm_url" "$wezterm_sha256" "WezTerm"

    local zed_url zed_sha256
    zed_url=$(jq -r ".zed.${arch}.url" "./external.lock.json")
    zed_sha256=$(jq -r ".zed.${arch}.sha256" "./external.lock.json")
    echo "  Installing Zed..."
    install_app_from_dmg "$zed_url" "$zed_sha256" "Zed"

    install_clipkitty
}

build_spotlight_scripts() {
    local script="./macos/raycast_scripts/build_spotlight_apps.sh"
    if [[ -f "$script" ]]; then
        echo "Building Spotlight apps..."
        bash "$script"
    fi
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

configure_os() {
    install_launchdaemon \
        ./macos/capslock_to_backspace.sh /Library/Scripts/capslock_to_backspace.sh \
        ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/com.capslock_to_backspace.plist

    install_launchdaemon \
        ./macos/sleep_on_lid_close.sh /Library/Scripts/sleep_on_lid_close.sh \
        ./macos/com.julsh.sleeponlidclose.plist /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist

    # Set the location to the Downloads folder
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
    echo "Configuring OS settings (requires sudo)..."
    sudo -v
    configure_os
}

main "$@"
