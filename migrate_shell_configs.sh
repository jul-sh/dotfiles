#!/usr/bin/env bash
#
# Migration script for shell config restructuring
# Run this on existing machines to migrate from old .profile/.bashrc/.zshrc setup to new .profile.shared/.bashrc.shared/.zshrc.shared approach
#
# This script:
# 1. Extracts any machine-specific config from the old shell config symlinks
# 2. Creates new local shell config files (not symlinks)
# 3. Creates symlinks to .profile.shared, .bashrc.shared and .zshrc.shared

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Shell Configuration Migration Script ==="
echo

# Get the directory where this script is located (should be the dotfiles repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    echo -e "${RED}ERROR: dotfiles directory not found at ${DOTFILES_DIR}${NC}"
    echo "Please run this script from your dotfiles repository root."
    exit 1
fi

if [[ ! -f "${DOTFILES_DIR}/.profile.shared" ]] || [[ ! -f "${DOTFILES_DIR}/.bashrc.shared" ]] || [[ ! -f "${DOTFILES_DIR}/.zshrc.shared" ]]; then
    echo -e "${RED}ERROR: .profile.shared, .bashrc.shared or .zshrc.shared not found in ${DOTFILES_DIR}${NC}"
    echo "Please git pull the latest changes first."
    exit 1
fi

PROFILE_PATH="${HOME}/.profile"
PROFILE_SHARED_PATH="${HOME}/.profile.shared"
PROFILE_BACKUP="${HOME}/.profile.backup.$(date +%s)"

BASHRC_PATH="${HOME}/.bashrc"
BASHRC_SHARED_PATH="${HOME}/.bashrc.shared"
BASHRC_BACKUP="${HOME}/.bashrc.backup.$(date +%s)"

ZSHRC_PATH="${HOME}/.zshrc"
ZSHRC_SHARED_PATH="${HOME}/.zshrc.shared"
ZSHRC_BACKUP="${HOME}/.zshrc.backup.$(date +%s)"

# Function to migrate a shell rc file
migrate_rc_file() {
    local rc_name="$1"          # e.g., "bashrc" or "zshrc"
    local rc_path="$2"          # e.g., "${HOME}/.bashrc"
    local rc_shared_path="$3"   # e.g., "${HOME}/.bashrc.shared"
    local rc_backup="$4"        # e.g., "${HOME}/.bashrc.backup.12345"
    local dotfiles_shared="$5"  # e.g., "${DOTFILES_DIR}/.bashrc.shared"
    local marker_pattern="$6"   # e.g., "starship init" or "atuin init bash"
    local source_cmd="$7"       # e.g., "source" or "."
    local shell_type="$8"       # e.g., "zsh" or "bash"

    echo
    echo "=== Migrating ${rc_name} ==="
    echo "Checking current .${rc_name} setup..."

    local machine_specific=""

    if [[ ! -e "$rc_path" ]]; then
        echo -e "${YELLOW}No existing .${rc_name} found. Creating new one...${NC}"
    elif [[ -L "$rc_path" ]]; then
        echo -e "${GREEN}Found symlinked .${rc_name} (old setup)${NC}"

        # Read the current rc file and extract machine-specific lines
        echo "Extracting machine-specific configuration..."

        # Create a backup
        cp -L "$rc_path" "$rc_backup"
        echo -e "${GREEN}Created backup at: ${rc_backup}${NC}"

        # Extract lines after the marker pattern
        machine_specific=$(awk "/${marker_pattern}/{flag=1; next} flag" "$rc_path" || true)

        # Remove the symlink
        echo "Removing old .${rc_name} symlink..."
        rm "$rc_path"
    else
        echo -e "${YELLOW}.${rc_name} already exists as a regular file${NC}"

        # Check if it already sources .${rc_name}.shared
        if grep -q "${source_cmd}.*\.${rc_name}\.shared" "$rc_path" 2>/dev/null; then
            echo -e "${GREEN}Migration already complete! .${rc_name} already sources .${rc_name}.shared${NC}"

            # Just make sure .${rc_name}.shared symlink exists
            if [[ ! -L "$rc_shared_path" ]]; then
                echo "Creating .${rc_name}.shared symlink..."
                ln -sf "$dotfiles_shared" "$rc_shared_path"
                echo -e "${GREEN}✓ Created symlink: ${rc_shared_path} -> ${dotfiles_shared}${NC}"
            fi

            return 0
        fi

        # Regular file but old format - back it up and extract machine-specific parts
        cp "$rc_path" "$rc_backup"
        echo -e "${GREEN}Created backup at: ${rc_backup}${NC}"

        machine_specific=$(awk "/${marker_pattern}/{flag=1; next} flag" "$rc_path" || true)
        rm "$rc_path"
    fi

    # Create new local rc file
    echo "Creating new local .${rc_name}..."

    cat > "$rc_path" <<EOF
# Source shared ${shell_type} configuration
if [ -f "\${HOME}/.${rc_name}.shared" ]; then
  ${source_cmd} "\${HOME}/.${rc_name}.shared"
fi

# Machine-specific configuration below this line
# Software installations will typically add their PATH exports here

EOF

    # Append any machine-specific config that was extracted
    if [[ -n "$machine_specific" ]]; then
        echo "$machine_specific" >> "$rc_path"
        echo -e "${GREEN}✓ Preserved machine-specific configuration${NC}"
    fi

    echo -e "${GREEN}✓ Created new local .${rc_name}${NC}"

    # Create .${rc_name}.shared symlink
    echo "Setting up .${rc_name}.shared symlink..."

    if [[ -L "$rc_shared_path" ]]; then
        # Check if it points to the right place
        local current_target
        current_target=$(readlink "$rc_shared_path")
        if [[ "$current_target" == "$dotfiles_shared" ]]; then
            echo -e "${GREEN}✓ .${rc_name}.shared symlink already correct${NC}"
        else
            echo "Updating .${rc_name}.shared symlink..."
            ln -sf "$dotfiles_shared" "$rc_shared_path"
            echo -e "${GREEN}✓ Updated symlink${NC}"
        fi
    elif [[ -e "$rc_shared_path" ]]; then
        echo -e "${YELLOW}WARNING: .${rc_name}.shared exists but is not a symlink${NC}"
        echo "Please manually check ${rc_shared_path}"
    else
        ln -sf "$dotfiles_shared" "$rc_shared_path"
        echo -e "${GREEN}✓ Created symlink: ${rc_shared_path} -> ${dotfiles_shared}${NC}"
    fi
}

# Migrate all shell configurations
migrate_rc_file "profile" "$PROFILE_PATH" "$PROFILE_SHARED_PATH" "$PROFILE_BACKUP" "${DOTFILES_DIR}/.profile.shared" "atuin/bin/env" "." "shell"
migrate_rc_file "bashrc" "$BASHRC_PATH" "$BASHRC_SHARED_PATH" "$BASHRC_BACKUP" "${DOTFILES_DIR}/.bashrc.shared" "atuin init bash" "." "bash"
migrate_rc_file "zshrc" "$ZSHRC_PATH" "$ZSHRC_SHARED_PATH" "$ZSHRC_BACKUP" "${DOTFILES_DIR}/.zshrc.shared" "starship init zsh" "source" "zsh"

# Summary
echo
echo -e "${GREEN}=== Migration Complete! ===${NC}"
echo
echo "Summary:"
echo "  • ~/.profile is now a regular file (machine-specific config)"
echo "  • ~/.profile.shared is a symlink to dotfiles/.profile.shared"
echo "  • ~/.bashrc is now a regular file (machine-specific config)"
echo "  • ~/.bashrc.shared is a symlink to dotfiles/.bashrc.shared"
echo "  • ~/.zshrc is now a regular file (machine-specific config)"
echo "  • ~/.zshrc.shared is a symlink to dotfiles/.zshrc.shared"
echo "  • Machine-specific PATH exports preserved"
if [[ -f "$PROFILE_BACKUP" ]]; then
    echo "  • Backup saved at: ${PROFILE_BACKUP}"
fi
if [[ -f "$BASHRC_BACKUP" ]]; then
    echo "  • Backup saved at: ${BASHRC_BACKUP}"
fi
if [[ -f "$ZSHRC_BACKUP" ]]; then
    echo "  • Backup saved at: ${ZSHRC_BACKUP}"
fi
echo
echo "Please restart your terminal or run: source ~/.profile && source ~/.bashrc (for bash) or source ~/.zshrc (for zsh)"
