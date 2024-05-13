# Plugins
source "${HOME}/.zsh-plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "${HOME}/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Plugin settings
bindkey "$terminfo[kcbt]" menu-select
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
zstyle ':autocomplete:history-search-backward:*' list-lines 2000
zstyle ':autocomplete:tab:*' widget-style menu-complete
zstyle ':autocomplete:*' min-input 3

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Initialize starship prompt
eval "$(starship init zsh)"
