# Source .profile if it exists
if [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile"
fi

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Plugins
source "${HOME}/.zsh-plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "${HOME}/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Initialize starship prompt
eval "$(starship init zsh)"
