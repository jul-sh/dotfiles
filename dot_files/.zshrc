# Plugins
source "${HOME}/.zsh-plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "${HOME}/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Plugin settings
bindkey                            '^I'         menu-select
bindkey -M menuselect              '^I'         menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete

zstyle ':autocomplete:tab:*' widget-style menu-complete

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Initialize starship prompt
eval "$(starship init zsh)"
