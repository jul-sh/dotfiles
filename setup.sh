#!/bin/bash
set -e

setup_shell() {
    touch "${HOME}/.hushlogin"

    # Ensure the dotfiles directory exists
    if [[ ! -d "dotfiles" ]]; then
        echo "Error: 'dotfiles' directory not found in the current directory."
        return 1
    fi

    # Get the absolute path of the dotfiles directory
    local dotfiles_dir
    dotfiles_dir="$(pwd)/dotfiles"

    for filepath in "${dotfiles_dir}"/.*; do
        local filename
        filename=$(basename "${filepath}")
        # Skip . and .. and .DS_Store
        if [[ "${filename}" == "." || "${filename}" == ".." || "${filename}" == ".DS_Store" ]]; then
            continue
        fi

        # Check if it's a regular file or a directory (handle both)
        if [[ -e "${filepath}" ]]; then
            local target_path="${HOME}/${filename}"
            # Use -sfv to force create symbolic links, verbose output
            # Source must be absolute path for robustness
            ln -sfv "${filepath}" "${target_path}"
        fi
    done
}

install_packages() {
    echo "Starting package installation..."

    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --force || {
        echo "Starship installation failed."
        return 1
    }

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS detected. Installing Homebrew and packages..."

        if ! command -v brew &>/dev/null; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                echo "Homebrew installation failed."
                return 1
            }
        else
            echo "Homebrew already installed."
        fi

        echo "Installing fzf..."
        /opt/homebrew/bin/brew install fzf || {
            echo "fzf installation failed."
            return 1
        }

        echo "Installing raycast, zed, and Visual Studio Code..."
        /opt/homebrew/bin/brew install --cask --force raycast zed visual-studio-code || {
            echo "macOS package installation failed."
            return 1
        }

    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing Wezterm..."
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/wezterm-fury.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo apt update
        sudo apt install wezterm



        echo "Installing fzf..."
        sudo apt install fzf

        echo "Installing zed..."
        curl -f https://zed.dev/install.sh | sh

        (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
       	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
                        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
       	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
       	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
       	&& sudo apt update \
       	&& sudo apt install gh -y
    else
        echo "Unsupported OS: $OSTYPE"
        return 1
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain none -y

    # Source the rustup environment variables so `rustup` is in the path for this shell
    source "$HOME/.cargo/env"

    rustup toolchain install nightly --allow-downgrade --profile minimal --component clippy

    echo "Installing uv and aider..."
    curl -LsSf https://astral.sh/uv/install.sh | sh || {
        echo "uv installation failed."
        return 1
    }
    echo "Installing Zellij CLI..."
    cargo install zellij || {
        echo "Zellij installation failed."
        return 1
    }

    echo "Installing shpool CLI..."
    cargo install shpool || {
        echo "shpool installation failed."
        return 1
    }

    echo "Installing aichat..."
    cargo install aichat || {
        echo "aichat installation failed."
        return 1
    }

    echo "Package installation complete!"
}

configure_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sudo cp ./macos/capslock_to_backspace.sh /Library/Scripts/
        sudo chmod +x /Library/Scripts/capslock_to_backspace.sh
        sudo cp ./macos/com.capslock_to_backspace.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist

        defaults write com.apple.screencapture location -string "${HOME}/Desktop"
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true
        defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
        defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
        defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
        defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

        defaults write com.apple.dock show-recents -int 0
        defaults write com.apple.dock minimize-to-application -int 1
        defaults write com.apple.dock tilesize -int 34
        defaults write com.apple.dock orientation -string "left"

        defaults write com.apple.TextEdit NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

        sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
            "—ฅ/ᐠ. ̫.ᐟ\\\ฅ— if it is lost, pls return this computer to lost@jul.sh"

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
    find fonts -name "*.ttf" -exec cp {} "$font_dir/" \;
}

main() {
    setup_shell
    install_packages
    install_fonts
    configure_os

    echo "Setup complete!"
}

main
