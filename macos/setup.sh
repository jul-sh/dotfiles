#!/usr/bin/env bash
# macos/setup.sh - macOS-only setup steps invoked by nix/setup-internal.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

die() { echo "error: $1" >&2; exit 1; }

SCOPE_FILE=".setup_scope"

resolve_setup_scope() {
    local scope
    if [[ -n "${SETUP_SCOPE:-}" ]]; then
        scope="$SETUP_SCOPE"
    elif [[ -f "$SCOPE_FILE" ]]; then
        scope=$(<"$SCOPE_FILE")
    else
        scope=system
    fi

    case "$scope" in
        user|system) ;;
        *) die "SETUP_SCOPE must be 'user' or 'system', got '$scope'" ;;
    esac

    SETUP_SCOPE="$scope"
    if [[ ! -f "$SCOPE_FILE" ]] || [[ "$(<"$SCOPE_FILE")" != "$scope" ]]; then
        printf '%s\n' "$scope" > "$SCOPE_FILE"
    fi
    echo "Setup scope: $SETUP_SCOPE"
}

ensure_homebrew() {
    if command -v brew &>/dev/null; then
        return
    fi
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty
    # Add brew to PATH for the rest of this session
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        die "Homebrew installed but brew not found in expected locations"
    fi
}

install_desktop_apps() {
    echo "Installing desktop apps..."
    ensure_homebrew
    local casks=("wezterm" "zed" "jul-sh/clipkitty/clipkitty" "home-assistant")
    brew install --cask "${casks[@]}" || echo "  warning: one or more apps failed to install"
    brew upgrade --cask "${casks[@]}" || echo "  warning: one or more apps failed to update"
}

configure_default_apps() {
    echo "Configuring default apps..."
    ensure_homebrew
    if ! command -v duti &>/dev/null; then
        brew install duti || { echo "  warning: failed to install duti"; return; }
    fi

    # Set Zed as default for text/code files
    local utis=(
        public.plain-text
        public.source-code
        public.shell-script
        public.json
        public.xml
        public.yaml
        public.python-script
        public.ruby-script
        public.perl-script
        public.php-script
        public.c-source
        public.c-header
        public.c-plus-plus-source
        public.objective-c-source
        public.swift-source
        net.daringfireball.markdown
    )
    for uti in "${utis[@]}"; do
        duti -s dev.zed.Zed "$uti" all 2>/dev/null || true
    done

    # PDF -> Preview
    duti -s com.apple.Preview com.adobe.pdf all 2>/dev/null || true
}

install_screensaver() {
    local saver_dir="$HOME/Library/Screen Savers"
    local saver_path="$saver_dir/Snoopy.saver"
    local expected_hash="96a935e41aa94b503b6bdbda0754691bc18c301b5a7ccdc0b1a38b6258768876"

    if [[ -d "$saver_path" || -d "/Library/Screen Savers/Snoopy.saver" ]]; then
        echo "Snoopy screen saver already installed."
        return
    fi

    echo "Installing Snoopy screen saver..."
    mkdir -p "$saver_dir"
    local tmp_zip
    tmp_zip=$(mktemp)
    local tmp_dir
    tmp_dir=$(mktemp -d)

    local download_url
    download_url=$(curl -sL "https://api.github.com/repos/YaxinCheng/Snoopy/releases/latest" | grep -o '"browser_download_url": "[^"]*Snoopy.saver.zip"' | cut -d'"' -f4)

    if [[ -z "$download_url" ]]; then
        echo "  warning: could not find Snoopy.saver.zip download URL"
        rm -rf "$tmp_zip" "$tmp_dir"
        return
    fi

    curl -sL "$download_url" -o "$tmp_zip" || { echo "  warning: failed to download"; rm -rf "$tmp_zip" "$tmp_dir"; return; }

    # Verify hash before installing
    local actual_hash
    actual_hash=$(shasum -a 256 "$tmp_zip" | cut -d' ' -f1)
    if [[ "$actual_hash" != "$expected_hash" ]]; then
        echo "  warning: hash mismatch! expected $expected_hash, got $actual_hash"
        echo "  skipping installation - update expected_hash in setup.sh if this is a new trusted release"
        rm -rf "$tmp_zip" "$tmp_dir"
        return
    fi

    unzip -q "$tmp_zip" -d "$tmp_dir" || { echo "  warning: failed to unzip"; rm -rf "$tmp_zip" "$tmp_dir"; return; }
    mv "$tmp_dir/Snoopy.saver" "$saver_path"
    rm -rf "$tmp_zip" "$tmp_dir"

    # Remove quarantine flag to avoid Gatekeeper prompt
    xattr -rd com.apple.quarantine "$saver_path" 2>/dev/null || true

    # Set as default screen saver
    defaults -currentHost write com.apple.screensaver moduleDict -dict moduleName -string "Snoopy" path -string "$saver_path" type -int 0
}

configure_spotlight() {
    echo "Configuring Spotlight..."

    # Disable these sources in Spotlight results
    defaults write com.apple.Spotlight EnabledPreferenceRules -array \
        "com.apple.iBooksX" \
        "com.google.drivefs" \
        "com.apple.mail" \
        "com.apple.reminders" \
        "com.apple.Safari" \
        "com.apple.tips" \
        "System.files" \
        "System.folders"

    # Enable clipboard history in Spotlight (7 days)
    defaults write com.apple.Spotlight PasteboardHistoryEnabled -bool true
    defaults write com.apple.Spotlight PasteboardHistoryTimeout -int 604800
}

build_spotlight_scripts() {
    local script="./macos/raycast_scripts/build_spotlight_apps.sh"
    if [[ -f "$script" ]]; then
        echo "Building Spotlight apps..."
        bash "$script"
    fi
}

compile_capslock_remap() {
    local scope="$1" bin_dst="$2" swift_src="./macos/capslock_remap.swift"
    [[ "$swift_src" -nt "$bin_dst" ]] || [[ ! -f "$bin_dst" ]] || return 0
    command -v swiftc &>/dev/null || { echo "  warning: swiftc not found, skipping capslock remap"; return 1; }

    echo "Compiling capslock remap..."
    local tmp_bin
    tmp_bin=$(mktemp)
    if ! swiftc -O "$swift_src" -o "$tmp_bin"; then
        rm -f "$tmp_bin"
        echo "  warning: swiftc compilation failed, skipping capslock remap"
        return 1
    fi

    case "$scope" in
        user)
            if ! install -m 755 "$tmp_bin" "$bin_dst"; then
                rm -f "$tmp_bin"
                echo "  warning: could not install capslock remap"
                return 1
            fi
            ;;
        system)
            if ! sudo install -d /Library/Scripts || ! sudo install -m 755 "$tmp_bin" "$bin_dst"; then
                rm -f "$tmp_bin"
                echo "  warning: could not install capslock remap"
                return 1
            fi
            ;;
    esac
    rm -f "$tmp_bin"
}

install_capslock_remap_user() {
    local bin_dst="$HOME/.local/bin/capslock-remap"
    local plist_dst="$HOME/Library/LaunchAgents/com.julsh.capslock_remap.plist"

    mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
    compile_capslock_remap user "$bin_dst" || return 0

    # Generate plist
    local plist_content
    plist_content=$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.julsh.capslock_remap</string>
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
    local bin_dst="/Library/Scripts/capslock-remap"
    local plist_dst="/Library/LaunchDaemons/com.julsh.capslock_remap.plist"
    compile_capslock_remap system "$bin_dst" || return 0

    # Generate plist
    local plist_content
    plist_content=$(cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.julsh.capslock_remap</string>
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

install_launchd_job() {
    local scope="$1" script_src="$2" plist_src="$3"
    local script_name plist_name script_dst plist_dst plist_content
    script_name=$(basename "$script_src")
    plist_name=$(basename "$plist_src")

    case "$scope" in
        user)
            script_dst="$HOME/.local/bin/$script_name"
            plist_dst="$HOME/Library/LaunchAgents/$plist_name"
            plist_content=$(sed "s|/Library/Scripts|$HOME/.local/bin|g" "$plist_src")
            mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
            if ! cmp -s "$script_src" "$script_dst" || [[ "$plist_content" != "$(cat "$plist_dst" 2>/dev/null)" ]]; then
                echo "Installing $plist_name..."
                launchctl unload "$plist_dst" 2>/dev/null || true
                install -m 755 "$script_src" "$script_dst"
                printf '%s\n' "$plist_content" > "$plist_dst"
            fi
            launchctl load -w "$plist_dst" 2>/dev/null || true
            ;;
        system)
            script_dst="/Library/Scripts/$script_name"
            plist_dst="/Library/LaunchDaemons/$plist_name"
            sudo install -d /Library/Scripts /Library/LaunchDaemons
            if ! cmp -s "$script_src" "$script_dst" || ! cmp -s "$plist_src" "$plist_dst"; then
                echo "Installing $plist_name..."
                sudo launchctl unload "$plist_dst" 2>/dev/null || true
                sudo install -m 755 "$script_src" "$script_dst"
                sudo install -m 644 "$plist_src" "$plist_dst"
            fi
            sudo launchctl load -w "$plist_dst" 2>/dev/null || true
            ;;
    esac
}

configure_user_defaults() {
    # Bind Shift+Cmd+V to "Paste and Match Style" (paste without formatting) globally.
    # @=Cmd, $=Shift, ~=Option; @$v = Shift+Cmd+V
    # First clear any stale overrides from when Cmd+V was swapped to match-style,
    # which otherwise leave Shift+Cmd+V bound to the wrong action.
    /usr/libexec/PlistBuddy -c "Delete :NSUserKeyEquivalents:Paste" ~/Library/Preferences/.GlobalPreferences.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Delete :NSUserKeyEquivalents:'Paste and Match Formatting'" ~/Library/Preferences/.GlobalPreferences.plist 2>/dev/null || true
    defaults write NSGlobalDomain NSUserKeyEquivalents -dict-add "Paste and Match Style" '@$v'

    defaults write com.apple.screencapture location -string "${HOME}/Downloads"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write NSGlobalDomain AppleAccentColor -int 6
    defaults write NSGlobalDomain AppleHighlightColor -string "1.000000 0.749020 0.823529 Pink"
    defaults write NSGlobalDomain AppleIconAppearanceTintColor -string "Blue"

    # Disable hot corners
    defaults write com.apple.dock wvous-tl-corner -int 1
    defaults write com.apple.dock wvous-tr-corner -int 1
    defaults write com.apple.dock wvous-bl-corner -int 1
    defaults write com.apple.dock wvous-br-corner -int 1
    defaults write com.apple.dock wvous-tl-modifier -int 0
    defaults write com.apple.dock wvous-tr-modifier -int 0
    defaults write com.apple.dock wvous-bl-modifier -int 0
    defaults write com.apple.dock wvous-br-modifier -int 0
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

configure_touch_id_sudo() {
    local sudo_pam="/etc/pam.d/sudo_local"
    local template="/etc/pam.d/sudo_local.template"

    if [[ -f "$sudo_pam" ]] && grep -qE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$sudo_pam"; then
        echo "Touch ID for sudo already configured."
        return
    fi

    echo "Enabling Touch ID for sudo..."
    local tmp_file
    tmp_file=$(mktemp)
    if [[ -f "$sudo_pam" ]]; then
        sed -E 's/^[[:space:]]*#[[:space:]]*(auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so)/\1/' "$sudo_pam" > "$tmp_file"
        if ! grep -qE '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so' "$tmp_file"; then
            echo "auth       sufficient     pam_tid.so" >> "$tmp_file"
        fi
    elif [[ -f "$template" ]]; then
        sed -E 's/^[[:space:]]*#[[:space:]]*(auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so)/\1/' "$template" > "$tmp_file"
    else
        cat > "$tmp_file" <<EOF
# sudo_local: local config file which survives system updates
auth       sufficient     pam_tid.so
EOF
    fi

    if ! sudo install -o root -g wheel -m 444 "$tmp_file" "$sudo_pam" 2>/dev/null; then
        rm -f "$tmp_file"
        echo "Warning: could not write $sudo_pam (Operation not permitted)." >&2
        echo "Grant your terminal Full Disk Access in System Settings > Privacy & Security, then re-run." >&2
        return
    fi
    rm -f "$tmp_file"
}

configure_system_defaults() {
    configure_touch_id_sudo
    install_capslock_remap_system
    install_launchd_job system ./macos/sleep_on_lid_close.sh ./macos/com.julsh.sleeponlidclose.plist

    local agent
    for agent in com.julsh.capslock_remap.plist com.julsh.sleeponlidclose.plist; do
        agent="$HOME/Library/LaunchAgents/$agent"
        launchctl unload "$agent" 2>/dev/null || true
        rm -f "$agent"
    done
    rm -f "$HOME/.local/bin/capslock-remap" "$HOME/.local/bin/sleep_on_lid_close.sh"

    sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
        "—ฅ/ᐠ. ̫.ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"
}

configure_selected_scope() {
    case "$SETUP_SCOPE" in
        user)
            install_capslock_remap_user
            install_launchd_job user ./macos/sleep_on_lid_close.sh ./macos/com.julsh.sleeponlidclose.plist
            echo "Skipping system configuration (SETUP_SCOPE=user)"
            ;;
        system)
            echo "################################################################################"
            echo "System configuration requires sudo."
            echo "To skip, re-run with: SETUP_SCOPE=user curl c.jul.sh | sh"
            echo "################################################################################"
            if sudo -v; then
                configure_system_defaults
            else
                local choice
                printf "Skip system configuration and continue? [y/N]: "
                read -r choice < /dev/tty || choice=""
                case "$choice" in
                    y|Y) echo "Skipping system configuration." ;;
                    *) die "Setup aborted" ;;
                esac
            fi
            ;;
    esac
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
    configure_default_apps
    install_screensaver
    configure_spotlight
    build_spotlight_scripts
    echo "Configuring user defaults..."
    configure_user_defaults
    configure_selected_scope
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
