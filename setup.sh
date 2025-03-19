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
  # Function to install various packages based on OS
  echo "Starting package installation..."

  # --- macOS (Darwin) Specific Installations ---
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected. Installing Homebrew and packages..."

    # Install Homebrew
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "Homebrew installation failed."; return 1; }

    # Install Starship
    echo "Installing Starship..."
    /opt/homebrew/bin/brew install starship || { echo "Starship installation failed."; return 1; }

    # Install other macOS packages
    echo "Installing raycast, zed, cursor, and Visual Studio Code..."
    /opt/homebrew/bin/brew install --cask raycast zed cursor visual-studio-code || { echo "macOS package installation failed."; return 1; }

  # --- Linux Specific Installations ---
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      echo "Installing Starship..."
      curl -sS https://starship.rs/install.sh | sh || { echo "Starship installation failed."; return 1; }
  else
     echo "Unsupported OS: $OSTYPE"
     return 1
  fi

  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain none -y
  rustup toolchain install nightly --allow-downgrade --profile minimal --component clippy


  # --- Install Starship (common for macOS and Linux) ---
  echo "Installing Starship (common)..."
  sh -c "$(curl -fsSL https://starship.rs/install.sh)" || { echo "Starship installation failed."; return 1; }

  # --- Install uv and aider (common for macOS and Linux) ---
  echo "Installing uv and aider..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || { echo "uv installation failed."; return 1; }
  uv tool install --force --python python3.12 aider-chat@latest || { echo "aider installation failed."; return 1; }

  # --- Install Zellij (common for macOS and Linux) ---
  echo "Installing Zellij CLI..."
  install_zellij_cli || { echo "Zellij installation failed."; return 1; }

  # --- Install Shpool using cargo ---
  echo "Installing Shpool with cargo..."
  cargo install shpool || { echo "Shpool installation failed."; return 1; }


  echo "Package installation complete!"
}

install_zellij_cli() {
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"

    local arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        arch="aarch64"
    fi
    
    local sys=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sys="apple-darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sys="unknown-linux-musl"
    else
      echo "Unsupported system: $OSTYPE"
        return 1
    fi

    local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${arch}-${sys}.tar.gz"
    local download_path="$install_dir/zellij-$(date +%Y%m%d-%H%M%S).tar.gz"

    curl --location "$url" -o "$download_path" || { echo "Zellij download failed."; return 1; }

    tar -C "$install_dir" -xzf "$download_path" || { echo "Zellij extraction failed."; return 1; }

    rm "$download_path"

    ln -s "$install_dir/zellij" "$install_dir/zellij" || { echo "Zellij symlink creation failed."; return 1; }

    echo "Zellij installed successfully in $install_dir."
    echo "You can now run 'zellij' from your terminal. Ensure $install_dir is in your PATH environment variable"
    return 0
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
