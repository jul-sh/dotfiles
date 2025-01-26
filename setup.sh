#!/bin/bash
set -e

setup_shell() {
    touch "${HOME}/.hushlogin"

    # Copy dotfiles, skipping .DS_Store and . directory
    for filename in dot_files/.*; do
        if [[ -f "${filename}" && "${filename}" != "dot_files/.DS_Store" ]]; then
            cp -v "${filename}" "${HOME}/"
        fi
    done
}

install_packages() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        /opt/homebrew/bin/brew install starship || true
        /opt/homebrew/bin/brew install --cask raycast zed cursor visual-studio-code || true
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -sS https://starship.rs/install.sh | sh
    fi

    sh -c "$(curl -fsSL https://starship.rs/install.sh)"
}

configure_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Capslock remapping
        sudo cp ./macos/capslock_to_backspace.sh /Library/Scripts/
        sudo chmod +x /Library/Scripts/capslock_to_backspace.sh
        sudo cp ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist

        # System preferences
        defaults write com.apple.screencapture location -string "${HOME}/Desktop"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write NSGlobalDomain AppleShowScrollBars -string WhenScrolling
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode{,2} -bool true
        defaults write NSGlobalDomain PMPrintingExpandedStateForPrint{,2} -bool true

        # Dock settings
        defaults write com.apple.dock show-recents -int 0
        defaults write com.apple.dock minimize-to-application -int 1
        defaults write com.apple.dock tilesize -int 34
        defaults write com.apple.dock orientation -string "left"

        # TextEdit preferences
        defaults write com.apple.TextEdit NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

        # Set login window message
        sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
            "—ฅ/ᐠ. <032b> .ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"

        # Restart system UI
        killall Dock
        sudo killall Finder
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux-specific configurations not implemented yet."
    fi
}

install_fonts() {
    echo "Installing fonts..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        font_dir=${HOME}/Library/Fonts
    else
        font_dir=${HOME}/.local/share/fonts
        fc-cache -f -v
    fi
    mkdir -p "$font_dir"
    find manual/fonts -name "*.ttf" -exec cp {} "$font_dir/" \;
}

main() {
    setup_shell
    install_packages
    install_fonts
    configure_os

    echo "Setup complete!"
}

main
