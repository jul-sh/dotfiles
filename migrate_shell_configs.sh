#!/usr/bin/env bash
#
# Migration script for existing dotfiles installations
# Migrates from old setup to Nix-based declarative configuration with .shared/.local split
#
# This script:
# 1. Extracts machine-specific config from old shell rc files
# 2. Installs Nix if not present
# 3. Applies Home Manager configuration (generates .shared files)
# 4. Creates local rc files with preserved machine-specific config
# 5. Installs GUI applications and configures OS settings

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

echo "=== Dotfiles Migration to Nix Setup ==="
echo

# Get the directory where this script is located (should be the dotfiles repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "${SCRIPT_DIR}/.git" ]]; then
    error "This script must be run from the dotfiles repository root."
fi

if [[ ! -d "${SCRIPT_DIR}/nix" ]]; then
    error "nix/ directory not found. Please git pull the latest changes first."
fi

# --- Step 1: Extract Machine-Specific Configuration ---
info "Step 1: Extracting machine-specific configuration from existing shell rc files..."

PROFILE_PATH="${HOME}/.profile"
BASHRC_PATH="${HOME}/.bashrc"
ZSHRC_PATH="${HOME}/.zshrc"

PROFILE_BACKUP="${HOME}/.profile.backup.$(date +%s)"
BASHRC_BACKUP="${HOME}/.bashrc.backup.$(date +%s)"
ZSHRC_BACKUP="${HOME}/.zshrc.backup.$(date +%s)"

# Function to extract machine-specific config from old rc files
extract_machine_config() {
    local rc_path="$1"
    local marker_pattern="$2"

    if [[ -f "$rc_path" ]]; then
        # Extract lines after the marker pattern, then filter out common paths
        # that are now in .profile.shared to avoid duplicates
        awk "/${marker_pattern}/{flag=1; next} flag" "$rc_path" | \
        grep -v -E '^\s*export PATH="\$HOME/\.cargo/bin:\$PATH"' | \
        grep -v -E '^\s*export PATH="\$HOME/\.local/bin:\$PATH"' | \
        grep -v -E '^\s*export PATH="\$HOME/go/bin:\$PATH"' | \
        grep -v -E '^\s*export PATH="\$HOME/\.npm-global/bin:\$PATH"' | \
        grep -v -E '^\s*export PATH="/usr/local/bin:\$PATH"' | \
        grep -v -E '^\s*\. "\$HOME/\.cargo/env"' | \
        grep -v -E '^\s*\. "\$HOME/\.atuin/bin/env"' || true
    fi
}

# Extract machine-specific config
PROFILE_MACHINE_CONFIG=""
BASHRC_MACHINE_CONFIG=""
ZSHRC_MACHINE_CONFIG=""

if [[ -L "$PROFILE_PATH" ]]; then
    info "Found symlinked .profile (old setup)"
    cp -L "$PROFILE_PATH" "$PROFILE_BACKUP"
    PROFILE_MACHINE_CONFIG=$(extract_machine_config "$PROFILE_PATH" "atuin/bin/env")
    success "Backed up .profile to ${PROFILE_BACKUP}"
elif [[ -f "$PROFILE_PATH" ]]; then
    if ! grep -q "\.profile\.shared" "$PROFILE_PATH" 2>/dev/null; then
        info "Found regular .profile (old setup)"
        cp "$PROFILE_PATH" "$PROFILE_BACKUP"
        PROFILE_MACHINE_CONFIG=$(extract_machine_config "$PROFILE_PATH" "atuin/bin/env")
        success "Backed up .profile to ${PROFILE_BACKUP}"
    else
        info ".profile already migrated, skipping extraction"
    fi
fi

if [[ -L "$BASHRC_PATH" ]]; then
    info "Found symlinked .bashrc (old setup)"
    cp -L "$BASHRC_PATH" "$BASHRC_BACKUP"
    BASHRC_MACHINE_CONFIG=$(extract_machine_config "$BASHRC_PATH" "atuin init bash")
    success "Backed up .bashrc to ${BASHRC_BACKUP}"
elif [[ -f "$BASHRC_PATH" ]]; then
    if ! grep -q "\.bashrc\.shared" "$BASHRC_PATH" 2>/dev/null; then
        info "Found regular .bashrc (old setup)"
        cp "$BASHRC_PATH" "$BASHRC_BACKUP"
        BASHRC_MACHINE_CONFIG=$(extract_machine_config "$BASHRC_PATH" "atuin init bash")
        success "Backed up .bashrc to ${BASHRC_BACKUP}"
    else
        info ".bashrc already migrated, skipping extraction"
    fi
fi

if [[ -L "$ZSHRC_PATH" ]]; then
    info "Found symlinked .zshrc (old setup)"
    cp -L "$ZSHRC_PATH" "$ZSHRC_BACKUP"
    ZSHRC_MACHINE_CONFIG=$(extract_machine_config "$ZSHRC_PATH" "starship init zsh")
    success "Backed up .zshrc to ${ZSHRC_BACKUP}"
elif [[ -f "$ZSHRC_PATH" ]]; then
    if ! grep -q "\.zshrc\.shared" "$ZSHRC_PATH" 2>/dev/null; then
        info "Found regular .zshrc (old setup)"
        cp "$ZSHRC_PATH" "$ZSHRC_BACKUP"
        ZSHRC_MACHINE_CONFIG=$(extract_machine_config "$ZSHRC_PATH" "starship init zsh")
        success "Backed up .zshrc to ${ZSHRC_BACKUP}"
    else
        info ".zshrc already migrated, skipping extraction"
    fi
fi

# --- Step 2: Install Prerequisites (Nix) ---
info "Step 2: Installing Nix (if not already installed)..."

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

if ! command -v nix &>/dev/null; then
    info "Nix not found. Attempting multi-user installation..."
    # Try the Determinate Systems installer (multi-user) first.
    if curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate --no-confirm; then
        success "Multi-user Nix installation successful."
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
            success "Single-user Nix installation successful."
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
    success "Nix is already installed."
fi

# --- Step 3: Apply Home Manager Configuration ---
info "Step 3: Applying Nix Home Manager configuration..."

system=$(get_nix_system)
info "Detected Nix system: $system"

# Construct the flake reference dynamically
flake_ref="${SCRIPT_DIR}/nix#${USER}@${system}"
info "Applying flake configuration: $flake_ref"

# Remove old symlinked rc files if they exist (Home Manager will manage .shared files)
if [[ -L "$PROFILE_PATH" ]]; then
    info "Removing old .profile symlink..."
    rm "$PROFILE_PATH"
fi
if [[ -L "$BASHRC_PATH" ]]; then
    info "Removing old .bashrc symlink..."
    rm "$BASHRC_PATH"
fi
if [[ -L "$ZSHRC_PATH" ]]; then
    info "Removing old .zshrc symlink..."
    rm "$ZSHRC_PATH"
fi

# Apply Home Manager configuration
nix run home-manager/master -- switch --flake "$flake_ref" -b backup
success "Home Manager configuration applied"

# --- Step 4: Create Local RC Files ---
info "Step 4: Creating local shell rc files with preserved machine-specific config..."

# Create .profile if it doesn't exist or was removed
if [[ ! -f "$PROFILE_PATH" ]]; then
    info "Creating local .profile..."
    cat > "$PROFILE_PATH" <<'EOF'
# Source shared profile configuration
if [ -f "${HOME}/.profile.shared" ]; then
  . "${HOME}/.profile.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    if [[ -n "$PROFILE_MACHINE_CONFIG" ]]; then
        echo "$PROFILE_MACHINE_CONFIG" >> "$PROFILE_PATH"
        success "Created .profile with preserved machine-specific config"
    else
        success "Created .profile"
    fi
else
    info "Local .profile already exists, skipping creation"
fi

# Create .bashrc if it doesn't exist or was removed
if [[ ! -f "$BASHRC_PATH" ]]; then
    info "Creating local .bashrc..."
    cat > "$BASHRC_PATH" <<'EOF'
# Source shared bash configuration
if [ -f "${HOME}/.bashrc.shared" ]; then
  . "${HOME}/.bashrc.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    if [[ -n "$BASHRC_MACHINE_CONFIG" ]]; then
        echo "$BASHRC_MACHINE_CONFIG" >> "$BASHRC_PATH"
        success "Created .bashrc with preserved machine-specific config"
    else
        success "Created .bashrc"
    fi
else
    info "Local .bashrc already exists, skipping creation"
fi

# Create .zshrc if it doesn't exist or was removed
if [[ ! -f "$ZSHRC_PATH" ]]; then
    info "Creating local .zshrc..."
    cat > "$ZSHRC_PATH" <<'EOF'
# Source shared zsh configuration
if [ -f "${HOME}/.zshrc.shared" ]; then
  source "${HOME}/.zshrc.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF
    if [[ -n "$ZSHRC_MACHINE_CONFIG" ]]; then
        echo "$ZSHRC_MACHINE_CONFIG" >> "$ZSHRC_PATH"
        success "Created .zshrc with preserved machine-specific config"
    else
        success "Created .zshrc"
    fi
else
    info "Local .zshrc already exists, skipping creation"
fi

# --- Step 5: Install GUI Applications (Optional) ---
info "Step 5: Installing GUI applications..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &>/dev/null; then
        info "Installing Raycast and Zed via Homebrew..."
        brew install --cask --force raycast zed || warn "Failed to install some GUI apps"
    else
        warn "Homebrew not found, skipping GUI app installation"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    info "Installing Zed editor..."
    curl -f https://zed.dev/install.sh | sh || warn "Failed to install Zed"
fi

# --- Step 6: OS-Specific Configuration (Optional) ---
info "Step 6: Applying OS-specific configurations..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -d "${SCRIPT_DIR}/macos" ]]; then
        info "Configuring macOS system settings..."

        # Remap Caps Lock to Backspace
        if sudo cp "${SCRIPT_DIR}/macos/capslock_to_backspace.sh" /Library/Scripts/ 2>/dev/null && \
           sudo chmod +x /Library/Scripts/capslock_to_backspace.sh 2>/dev/null && \
           sudo cp "${SCRIPT_DIR}/macos/com.capslock_to_backspace.plist" /Library/LaunchDaemons/ 2>/dev/null; then
            sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist 2>/dev/null || true
        fi

        # Configure sleep on lid close
        if [[ -f "${SCRIPT_DIR}/macos/sleep_on_lid_close.sh" ]] && \
           sudo cp "${SCRIPT_DIR}/macos/sleep_on_lid_close.sh" /Library/Scripts/ 2>/dev/null && \
           sudo chmod +x /Library/Scripts/sleep_on_lid_close.sh 2>/dev/null && \
           sudo cp "${SCRIPT_DIR}/macos/com.julsh.sleeponlidclose.plist" /Library/LaunchDaemons/ 2>/dev/null; then
            sudo launchctl load -w /Library/LaunchDaemons/com.julsh.sleeponlidclose.plist 2>/dev/null || true
        fi

        # Dock & UI settings
        defaults write com.apple.dock show-recents -int 0 2>/dev/null || true
        defaults write com.apple.dock minimize-to-application -int 1 2>/dev/null || true
        defaults write com.apple.dock tilesize -int 34 2>/dev/null || true
        defaults write com.apple.dock orientation -string "left" 2>/dev/null || true
        defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null || true
        killall Dock 2>/dev/null || true

        success "macOS configuration applied"
    fi
fi

# --- Summary ---
echo
echo -e "${GREEN}=== Migration Complete! ===${NC}"
echo
echo "Summary:"
echo "  • Nix installed and configured"
echo "  • Home Manager applied (manages .shared files)"
echo "  • Local rc files created with machine-specific config preserved"
echo "  • ~/.profile, ~/.bashrc, ~/.zshrc are now local (untracked)"
echo "  • ~/.profile.shared, ~/.bashrc.shared, ~/.zshrc.shared are Nix-managed"
echo

if [[ -f "$PROFILE_BACKUP" ]] || [[ -f "$BASHRC_BACKUP" ]] || [[ -f "$ZSHRC_BACKUP" ]]; then
    echo "Backups saved:"
    [[ -f "$PROFILE_BACKUP" ]] && echo "  • ${PROFILE_BACKUP}"
    [[ -f "$BASHRC_BACKUP" ]] && echo "  • ${BASHRC_BACKUP}"
    [[ -f "$ZSHRC_BACKUP" ]] && echo "  • ${ZSHRC_BACKUP}"
    echo
fi

echo "Architecture:"
echo "  Local .zshrc → sources .zshrc.shared (Nix-managed)"
echo "                     → sources .profile.shared (Nix-managed)"
echo
echo "Software installers can now safely modify your local rc files without"
echo "conflicting with Nix or creating git changes."
echo
echo -e "${GREEN}Please restart your terminal or run: source ~/.zshrc${NC}"
