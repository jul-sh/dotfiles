# Source Nix multi-user profile if it exists
if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
  . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi
# Source Nix single-user profile if it exists
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Source shared profile if it exists
if [ -f "$HOME/.profile.shared" ]; then
  source "$HOME/.profile.shared"
fi

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# --------------------------------
# ZSH Other Configuration
# --------------------------------

# Show hidden files in completions
setopt globdots

# Don't error on comments in shell
setopt interactivecomments

# Disable Ctrl+D to close session
setopt ignoreeof

# --------------------------------
# ZSH Plugins (Nix-managed)
# --------------------------------

# Initialize completion system
autoload -Uz compinit
# Avoid recompiling .zcompdump too often, check if it's older than 1 day
if [[ ! -f ~/.zcompdump || -z $(find ~/.zcompdump -mtime -1) ]]; then
  compinit -d ~/.zcompdump # Specify dump file path
else
  compinit -i -d ~/.zcompdump # Use existing dump file without checks
fi

# Load zsh-syntax-highlighting plugin from Nix flake input
source @zsh-syntax-highlighting@/zsh-syntax-highlighting.plugin.zsh

# Load zsh-autocomplete plugin from Nix flake input
source @zsh-autocomplete@/zsh-autocomplete.plugin.zsh
bindkey '^I' menu-select
bindkey -M menuselect '^I' menu-complete
zstyle ':autocomplete:tab:*' widget-style menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
zstyle ':autocomplete:*' min-input 3
# Don't prompt for confirmation if there's many completions to show
zstyle ':completion:*' menu yes select
# Esc to exit autocomplete menu
bindkey -M menuselect '^[' undo
# Restore default history binding, otherwise occupied by zsh autocomplete
bindkey -M emacs \
    "^[p"   .history-search-backward \
    "^[n"   .history-search-forward \
    "^P"    .up-line-or-history \
    "^[OA"  .up-line-or-history \
    "^[[A"  .up-line-or-history \
    "^N"    .down-line-or-history \
    "^[OB"  .down-line-or-history \
    "^[[B"  .down-line-or-history \
    "^R"    .history-incremental-search-backward \
    "^S"    .history-incremental-search-forward \
    #
bindkey -a \
    "^P"    .up-history \
    "^N"    .down-history \
    "k"     .up-line-or-history \
    "^[OA"  .up-line-or-history \
    "^[[A"  .up-line-or-history \
    "j"     .down-line-or-history \
    "^[OB"  .down-line-or-history \
    "^[[B"  .down-line-or-history \
    "/"     .vi-history-search-backward \
    "?"     .vi-history-search-forward \
    #

# Use atuin for history search
eval "$(@atuin@ init zsh)"

# Check for dotfile updates
if [ -f "$HOME/.dotfiles_update.sh" ]; then
  source "$HOME/.dotfiles_update.sh"
fi

if [ -f "$HOME/.utils.sh" ]; then
  source "$HOME/.utils.sh"
fi

# Initialize direnv for zsh
eval "$(@direnv@ hook zsh)"

# Initialize starship prompt
eval "$(@starship@ init zsh)"
